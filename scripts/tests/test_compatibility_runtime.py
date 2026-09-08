"""Exercise provisioning selection without downloading or booting a simulator."""
from contextlib import redirect_stdout
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock

PATH = Path(__file__).resolve().parents[1] / "prepare-compatibility-runtime.py"
SPEC = importlib.util.spec_from_file_location("compatibility_runtime", PATH)
RUNTIME = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNTIME)


def runtime(version, platform="iOS", available=True):
    return {"version": version, "isAvailable": available,
            "identifier": "com.apple.CoreSimulator.SimRuntime." + platform + "-" + version.replace(".", "-")}


DEVICES = [{"name": "iPhone 15", "identifier": "iphone15", "productFamily": "iPhone",
            "minRuntimeVersionString": "17.0", "maxRuntimeVersionString": "65535"}]


class CompatibilityRuntimeTests(unittest.TestCase):
    def runner(self, before, after=None, download_fails=False, failing_runtime=None):
        downloaded = False

        def run(command, timeout=60):
            nonlocal downloaded
            if command[:4] == ["xcrun", "simctl", "list", "runtimes"]:
                return json.dumps({"runtimes": after if downloaded and after is not None else before})
            if command[:4] == ["xcrun", "simctl", "list", "devicetypes"]:
                return json.dumps({"devicetypes": DEVICES})
            if command[:2] == ["xcodebuild", "-downloadPlatform"]:
                downloaded = True
                if download_fails:
                    raise subprocess.CalledProcessError(1, command)
                return "downloaded"
            if command[2] == "create":
                return "failed-device" if command[-1] == failing_runtime else "test-device"
            if command[2] == "boot" and command[-1] == "failed-device":
                raise subprocess.CalledProcessError(1, command)
            return ""
        return Mock(side_effect=run)

    def test_exact_runtime_is_preferred_without_download(self):
        runner = self.runner([runtime("17.4"), runtime("17.5"), runtime("26.5")])
        result = RUNTIME.prepare("iOS", "17.5", runner)
        self.assertEqual(result["status"], "requested")
        self.assertFalse(result["coverageGap"])
        self.assertEqual(result["destination"], "platform=iOS Simulator,id=test-device")
        self.assertFalse(any(call.args[0][0] == "xcodebuild" for call in runner.call_args_list))

    def test_official_download_is_rechecked_before_fallback(self):
        runner = self.runner([runtime("26.5")], after=[runtime("26.5"), runtime("17.5")])
        result = RUNTIME.prepare("iOS", "17.5", runner)
        self.assertEqual(result["selectedVersion"], "17.5")
        self.assertIn(unittest.mock.call(["xcodebuild", "-downloadPlatform", "iOS", "-buildVersion", "17.5"],
                                         timeout=1800), runner.call_args_list)

    def test_failed_download_uses_oldest_available_supported_runtime_and_reports_gap(self):
        runner = self.runner([runtime("26.5"), runtime("18.1"), runtime("16.4"), runtime("17.5", available=False)],
                             download_fails=True)
        result = RUNTIME.prepare("iOS", "17.5", runner)
        self.assertEqual(result["selectedVersion"], "18.1")
        self.assertTrue(result["coverageGap"])
        self.assertEqual(result["status"], "fallback")

    def test_failed_boot_deletes_device_before_trying_fallback(self):
        requested = runtime("17.5")
        runner = self.runner([requested, runtime("18.1")], failing_runtime=requested["identifier"])
        result = RUNTIME.prepare("iOS", "17.5", runner)
        self.assertEqual(result["selectedVersion"], "18.1")
        runner.assert_any_call(["xcrun", "simctl", "delete", "failed-device"])

    def test_absent_runtimes_are_explicitly_unavailable(self):
        result = RUNTIME.prepare("iOS", "17.5", self.runner([], download_fails=True))
        self.assertIsNone(result["deviceID"])
        self.assertEqual(result["status"], "unavailable")
        self.assertTrue(result["coverageGap"])

    def test_missing_provisioning_tools_are_errors_not_coverage_fallbacks(self):
        for operation, installed in [("xcodebuild", []), ("boot", [runtime("17.5")])]:
            with self.subTest(operation=operation):
                base = self.runner(installed)

                def run(command, timeout=60):
                    if command[0] == operation or (len(command) > 2 and command[2] == operation):
                        raise FileNotFoundError("Missing provisioning tool")
                    return base(command, timeout=timeout)

                with self.assertRaises(FileNotFoundError):
                    RUNTIME.prepare("iOS", "17.5", run)

    def test_device_selection_respects_family_and_supported_versions(self):
        devices = DEVICES + [{"name": "iPhone 17", "identifier": "iphone17", "productFamily": "iPhone",
                              "minRuntimeVersionString": "26.0"},
                             {"name": "Watch", "identifier": "watch", "productFamily": "Apple Watch",
                              "minRuntimeVersionString": "10.0"}]
        self.assertEqual([item["identifier"] for item in RUNTIME.compatible_devices(devices, "iOS", "17.5")],
                         ["iphone15"])
        self.assertEqual([item["identifier"] for item in RUNTIME.compatible_devices(devices, "watchOS", "10.5")],
                         ["watch"])

    def test_report_outputs_never_claim_requested_coverage_for_fallback(self):
        report = RUNTIME.prepare("iOS", "17.5", self.runner([runtime("26.5")], download_fails=True))
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            path = Path(directory)
            RUNTIME.publish(report, path / "report.json", path / "output", path / "summary")
            self.assertIn("selected-version=26.5", (path / "output").read_text())
            self.assertIn("coverage-gap=true", (path / "output").read_text())
            self.assertIn("requested runtime was not tested", (path / "summary").read_text())


if __name__ == "__main__":
    unittest.main()
