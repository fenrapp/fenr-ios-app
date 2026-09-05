#!/usr/bin/env python3
"""Restore the iOS routing option that XcodeGen does not currently serialize."""

from pathlib import Path
import re
import xml.etree.ElementTree as ET


def configure_scheme(path: Path) -> None:
    content = path.read_text()
    reference = (
        '      <RoutingCoverageFileReference\n'
        '         identifier = "../../docs/app-store/routing-coverage.geojson">\n'
        '      </RoutingCoverageFileReference>\n'
    )
    content = re.sub(
        r"[ \t]*<RoutingCoverageFileReference\b[^>]*(?:/>|>\s*</RoutingCoverageFileReference>)\n?",
        "",
        content,
    )
    if content.count("   </LaunchAction>") != 1:
        raise ValueError(f"Expected one LaunchAction in {path.name}")
    content = content.replace("   </LaunchAction>", reference + "   </LaunchAction>")
    ET.fromstring(content)
    if path.read_text() != content:
        path.write_text(content)


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    for scheme in ("FENR", "FENRDebug"):
        configure_scheme(root / "FENR.xcodeproj/xcshareddata/xcschemes" / f"{scheme}.xcscheme")
