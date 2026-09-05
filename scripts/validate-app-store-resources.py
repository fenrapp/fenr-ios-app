#!/usr/bin/env python3
"""Validate the iOS submission resources, optionally inside an Xcode archive."""

import argparse
import json
import math
from pathlib import Path
import plistlib
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
CATEGORY = "NSPrivacyAccessedAPICategoryUserDefaults"
MANIFESTS = {
    "App/Resources/Shared/PrivacyInfo.xcprivacy": ("", {"CA92.1"}),
    "Modules/BikeData/Resources/iOS/PrivacyInfo.xcprivacy":
        ("Frameworks/BikeData.framework", {"CA92.1"}),
    "Modules/SettingsData/Resources/iOS/PrivacyInfo.xcprivacy":
        ("Frameworks/SettingsData.framework", {"CA92.1"}),
    "Modules/RideNavigationData/Resources/PrivacyInfo.xcprivacy":
        ("Frameworks/RideNavigationData.framework", {"CA92.1", "1C8F.1"}),
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_plist(path):
    with path.open("rb") as file:
        return plistlib.load(file)


def validate_manifest(path, reasons):
    manifest = read_plist(path)
    entries = manifest.get("NSPrivacyAccessedAPITypes", [])
    require(len(entries) == 1, f"Unexpected API categories: {path.name}")
    require(entries[0]["NSPrivacyAccessedAPIType"] == CATEGORY, "Wrong API category")
    require(set(entries[0]["NSPrivacyAccessedAPITypeReasons"]) == reasons, "Wrong API reasons")


def validate_coverage():
    coverage = json.loads((ROOT / "docs/app-store/routing-coverage.geojson").read_text())
    require(coverage["type"] == "MultiPolygon", "Coverage must be a MultiPolygon")
    polygons = coverage["coordinates"]
    require(len(polygons) == 1 and len(polygons[0]) == 1, "Expected a world boundary without holes")
    ring = polygons[0][0]
    require(4 <= len(ring) <= 20 and ring[0] == ring[-1], "Invalid closed ring")
    for longitude, latitude in ring:
        require(math.isfinite(longitude) and math.isfinite(latitude), "Non-finite coordinate")
        require(-180 <= longitude <= 180 and -90 <= latitude <= 90, "Coordinate out of range")
        require(abs(longitude) == 180 or abs(latitude) == 90, "Vertex is not on the world boundary")
    for first, second in zip(ring, ring[1:]):
        require(abs(second[0] - first[0]) <= 180, "Edge crosses the antimeridian")
        require(first[0] == second[0] or first[1] == second[1], "Boundary edge must be axis-aligned")
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(ring, ring[1:])) / 2
    require(area == 360 * 180, "Coverage does not enclose the world counterclockwise")
    # Representative locations and both sides of the antimeridian.
    for longitude, latitude in [(-3.7, 40.4), (-74, 40.7), (139.7, 35.7),
                                 (151.2, -33.9), (179.9, -16), (-179.9, -16)]:
        inside = False
        for a, b in zip(ring, ring[1:]):
            if (a[1] > latitude) != (b[1] > latitude):
                intersection = (b[0] - a[0]) * (latitude - a[1]) / (b[1] - a[1]) + a[0]
                if longitude < intersection:
                    inside = not inside
        require(inside, "Representative location is outside coverage")


def validate_schemes():
    for name in ("FENR", "FENRDebug"):
        path = ROOT / "FENR.xcodeproj/xcshareddata/xcschemes" / f"{name}.xcscheme"
        references = ET.parse(path).findall("./LaunchAction/RoutingCoverageFileReference")
        require(len(references) == 1, f"Missing or duplicate routing reference: {name}")
        require(references[0].get("identifier") == "../../docs/app-store/routing-coverage.geojson",
                f"Incorrect routing reference: {name}")


def validate_archive(archive):
    app = archive / "Products/Applications/FENR.app"
    info = read_plist(app / "Info.plist")
    require(info.get("CFBundleIdentifier") == "in.fenr.app", "Archive is not the production iOS app")
    require(info.get("UIDeviceFamily") == [1], "FENR must support iPhone only")
    for key in ("NSBluetoothAlwaysUsageDescription", "NSLocationWhenInUseUsageDescription",
                "NSFaceIDUsageDescription"):
        require(bool(info.get(key)), f"Missing purpose string: {key}")
    require(info.get("MKDirectionsApplicationSupportedModes") == ["MKDirectionsModeCar"],
            "Missing routing registration")
    require(not (app / "Watch").exists(), "The iOS-only archive unexpectedly embeds a Watch app")
    for source, (bundle, reasons) in MANIFESTS.items():
        packaged = app / bundle / "PrivacyInfo.xcprivacy"
        validate_manifest(packaged, reasons)
        require(read_plist(packaged) == read_plist(ROOT / source), f"Stale manifest in {bundle or 'FENR'}")
    for name in ("Open in FENR", "ChargingLiveActivityExtension"):
        extension = app / "PlugIns" / f"{name}.appex/Info.plist"
        require(extension.is_file(), f"Missing extension: {name}")
        require(read_plist(extension).get("UIDeviceFamily") == [1],
                f"{name} must support iPhone only")
    print("Archive resources passed (distribution signing and Apple processing are separate).")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()
    for source, (_, reasons) in MANIFESTS.items():
        validate_manifest(ROOT / source, reasons)
    validate_coverage()
    validate_schemes()
    print("Source manifests, world coverage, and iOS scheme references passed.")
    if args.archive:
        validate_archive(args.archive)
