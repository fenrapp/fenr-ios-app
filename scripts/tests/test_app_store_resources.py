"""Packaging regressions for the iPhone's embedded Watch companion."""

import importlib.util
import plistlib
import tempfile
import unittest
from pathlib import Path


SPEC = importlib.util.spec_from_file_location(
    "app_store_resources", Path(__file__).resolve().parents[1] / "validate-app-store-resources.py"
)
RESOURCES = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RESOURCES)


class CompanionArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.app = Path(self.temporary.name) / "FENR.app"
        self.watch = self.app / "Watch/FENRWatch.app"
        self.watch.mkdir(parents=True)
        self.phone_info = {
            "CFBundleIdentifier": "in.fenr.app",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "6",
        }
        self.info = dict(self.phone_info, CFBundleIdentifier="in.fenr.app.watch",
                         WKCompanionAppBundleIdentifier="in.fenr.app", UIDeviceFamily=[4],
                         WKApplication=True, WKSupportsRunningWithoutiOSApp=False)

    def validate(self):
        (self.watch / "Info.plist").write_bytes(plistlib.dumps(self.info))
        RESOURCES.validate_companion(self.app, self.phone_info)

    def test_matching_companion_is_accepted(self):
        self.validate()

    def test_missing_companion_is_rejected(self):
        self.watch.rmdir()
        with self.assertRaisesRegex(ValueError, "exactly one"):
            RESOURCES.validate_companion(self.app, self.phone_info)

    def test_wrong_identity_or_version_is_rejected(self):
        for key in ("CFBundleIdentifier", "WKCompanionAppBundleIdentifier",
                    "CFBundleShortVersionString", "CFBundleVersion"):
            with self.subTest(key=key):
                previous = self.info[key]
                self.info[key] = "unexpected"
                with self.assertRaises(ValueError):
                    self.validate()
                self.info[key] = previous

    def test_standalone_or_bluetooth_enabled_companion_is_rejected(self):
        self.info["WKSupportsRunningWithoutiOSApp"] = True
        with self.assertRaisesRegex(ValueError, "paired iPhone"):
            self.validate()
        self.info["WKSupportsRunningWithoutiOSApp"] = False
        self.info["NSBluetoothAlwaysUsageDescription"] = "Fixture"
        with self.assertRaisesRegex(ValueError, "Bluetooth"):
            self.validate()

    def test_vehicle_framework_is_rejected(self):
        (self.watch / "Frameworks/BikeSDK.framework").mkdir(parents=True)
        with self.assertRaisesRegex(ValueError, "BikeSDK"):
            self.validate()
