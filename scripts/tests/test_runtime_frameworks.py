"""Portable fixtures for the built-bundle validator; no Xcode invocation needed."""

import importlib.util
import json
import plistlib
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location(
    "runtime_frameworks", Path(__file__).resolve().parents[1] / "validate-runtime-frameworks.py"
)
RUNTIME = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNTIME)


def commands(dependencies=(), rpaths=(), identity=None):
    lines = []
    records = [("LC_RPATH", "path", value) for value in rpaths]
    if identity:
        records.append(("LC_ID_DYLIB", "name", identity))
    records += [
        ("LC_LOAD_WEAK_DYLIB" if weak else "LC_LOAD_DYLIB", "name", name)
        for name, weak in dependencies
    ]
    for index, (command, field, value) in enumerate(records):
        lines += [f"Load command {index}", f" cmd {command}", " cmdsize 64", f" {field} {value} (offset 24)"]
    return RUNTIME.parse_load_commands("\n".join(lines))


class RuntimeFrameworkTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.app = Path(self.temporary.name).resolve() / "Fixture.app"
        self.images = {}
        self.bundle("", "Fixture")

    def bundle(self, relative, executable):
        bundle = self.app / relative
        bundle.mkdir(parents=True, exist_ok=True)
        (bundle / "Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable": executable}))
        return bundle

    def image(self, relative, dependencies=(), rpaths=(), identity=None):
        path = self.app / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"\xcf\xfa\xed\xfe" + b"fixture")
        self.images[path] = commands(dependencies, rpaths, identity)
        return path

    def validate(self):
        return RUNTIME.Validator(self.app, inspect=lambda path: self.images[path]).validate()

    def test_parser_ignores_install_identity_and_keeps_paths_with_spaces(self):
        parsed = commands(
            [("@rpath/Required.framework/Required", False), ("@rpath/Optional.dylib", True)],
            ["@loader_path/Frameworks With Spaces"], identity="@rpath/Self.framework/Self",
        )
        self.assertEqual(parsed.rpaths, ("@loader_path/Frameworks With Spaces",))
        self.assertEqual(parsed.dependencies, (
            RUNTIME.Dependency("@rpath/Required.framework/Required", False),
            RUNTIME.Dependency("@rpath/Optional.dylib", True),
        ))

    def test_parser_checks_reexport_upward_and_lazy_dependencies(self):
        output = "\n".join(
            f"Load command {index}\n cmd {command}\n name @rpath/Dep{index}.dylib (offset 24)"
            for index, command in enumerate(("LC_REEXPORT_DYLIB", "LC_LOAD_UPWARD_DYLIB", "LC_LAZY_LOAD_DYLIB"))
        )
        self.assertEqual(len(RUNTIME.parse_load_commands(output).dependencies), 3)

    def test_missing_transitive_ble_trace_dependency_has_actionable_owner(self):
        self.image("Fixture", [("@rpath/VehicleSession.framework/VehicleSession", False)], ["@executable_path/Frameworks", "/usr/lib/swift"])
        self.image("Frameworks/VehicleSession.framework/VehicleSession", [("@rpath/BLETraceDomain.framework/BLETraceDomain", False)])
        report = self.validate()
        self.assertFalse(report["ok"])
        self.assertEqual(len(report["findings"]), 1)
        missing = report["findings"][0]
        self.assertEqual(missing["owner"], "Frameworks/VehicleSession.framework/VehicleSession")
        self.assertEqual(missing["dependency"], "@rpath/BLETraceDomain.framework/BLETraceDomain")
        self.assertEqual(missing["candidates"], [
            "Frameworks/BLETraceDomain.framework/BLETraceDomain", "<outside app>/BLETraceDomain"
        ])
        self.assertNotIn(self.temporary.name, json.dumps(report))

    def test_present_transitive_dependency_inherits_main_runpaths(self):
        self.image("Fixture", [("@rpath/First.framework/First", False)], ["@executable_path/Frameworks"])
        self.image("Frameworks/First.framework/First", [("@rpath/Second.framework/Second", False)])
        self.image("Frameworks/Second.framework/Second", identity="@rpath/Second.framework/Second")
        self.assertTrue(self.validate()["ok"])

    def test_debug_dylib_and_unlinked_embedded_images_are_inspected(self):
        self.image("Fixture", [("@rpath/Fixture.debug.dylib", False)], ["@executable_path", "@executable_path/Frameworks"])
        self.image("Fixture.debug.dylib", [("@rpath/MissingDebug.framework/MissingDebug", False)])
        self.image("Frameworks/Unused.framework/Unused", [("@rpath/MissingUnused.framework/MissingUnused", False)])
        owners = {finding["owner"] for finding in self.validate()["findings"]}
        self.assertEqual(owners, {"Fixture.debug.dylib", "Frameworks/Unused.framework/Unused"})

    def test_loader_rpath_is_expanded_at_declaring_ancestor(self):
        self.image("Fixture", [("@rpath/First.framework/First", False)], ["@executable_path/Frameworks"])
        self.image("Frameworks/First.framework/First", [("@rpath/Second.framework/Second", False)], ["@loader_path/Private"])
        self.image("Frameworks/First.framework/Private/Second.framework/Second", [("@rpath/Third.framework/Third", False)])
        self.image("Frameworks/First.framework/Private/Third.framework/Third")
        self.assertTrue(self.validate()["ok"])

    def test_nested_app_and_extension_have_independent_executable_contexts(self):
        self.image("Fixture", rpaths=["@executable_path/Frameworks"])
        self.image("Frameworks/Shared.framework/Shared")
        self.bundle("PlugIns/Widget.appex", "Widget")
        self.image("PlugIns/Widget.appex/Widget", [("@rpath/Shared.framework/Shared", False)], ["@executable_path/../../Frameworks"])
        self.bundle("Watch/Companion.app", "Companion")
        self.image("Watch/Companion.app/Companion", [("@rpath/Shared.framework/Shared", False)], ["@executable_path/Frameworks"])
        missing = self.validate()["findings"]
        self.assertEqual(len(missing), 1)
        self.assertEqual(missing[0]["executable"], "Watch/Companion.app/Companion")
        self.image("Watch/Companion.app/Frameworks/Shared.framework/Shared")
        self.assertTrue(self.validate()["ok"])

    def test_nested_bundle_cannot_borrow_host_executable_runpaths(self):
        self.image("Fixture", rpaths=["@executable_path/Frameworks"])
        self.image("Frameworks/Shared.framework/Shared")
        self.bundle("PlugIns/Widget.appex", "Widget")
        self.image("PlugIns/Widget.appex/Widget", [("@rpath/Shared.framework/Shared", False)])
        missing = self.validate()["findings"]
        self.assertEqual(len(missing), 1)
        self.assertEqual(missing[0]["candidates"], [])

    def test_weak_absent_and_system_cache_dependencies_are_exempt(self):
        self.image("Fixture", [
            ("@rpath/Absent.framework/Absent", True),
            ("/System/Library/Frameworks/SwiftUI.framework/SwiftUI", False),
            ("/usr/lib/libSystem.B.dylib", False),
            ("@rpath/libswiftCore.dylib", False),
        ], ["/usr/lib/swift"])
        self.assertTrue(self.validate()["ok"])

    def test_framework_name_alone_does_not_exempt_missing_library(self):
        self.image("Fixture", [("@rpath/libswiftPrivate.dylib", False)], ["@executable_path/Frameworks"])
        self.assertFalse(self.validate()["ok"])

    def test_present_weak_image_still_has_required_transitive_dependencies(self):
        self.image("Fixture", [("@loader_path/Optional.dylib", True)])
        self.image("Optional.dylib", [("@loader_path/Missing.dylib", False)])
        self.assertEqual(self.validate()["findings"][0]["owner"], "Optional.dylib")

    def test_cycle_with_expanding_runpaths_terminates_and_checks_other_dependencies(self):
        self.image("Fixture", [("@loader_path/First.dylib", False)], ["@executable_path"])
        self.image("First.dylib", [("@loader_path/Second.dylib", False)], ["@rpath/Nested"])
        self.image("Second.dylib", [
            ("@loader_path/First.dylib", False), ("@loader_path/Missing.dylib", False),
        ], ["@rpath/Nested"])
        report = self.validate()
        self.assertEqual(len(report["findings"]), 1)
        self.assertEqual(report["findings"][0]["owner"], "Second.dylib")
        self.assertEqual(report["findings"][0]["dependency"], "@loader_path/Missing.dylib")

    def test_fat_load_commands_keep_architecture_runpaths_separate(self):
        image = self.image("Fixture")
        output = "\n".join([
            "Fixture (architecture arm64):", "Load command 0", " cmd LC_RPATH",
            " path @executable_path/ARM (offset 12)",
            "Fixture (architecture x86_64):", "Load command 0", " cmd LC_RPATH",
            " path @executable_path/Intel (offset 12)",
        ])
        with patch.object(RUNTIME.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, output)):
            parsed = RUNTIME.read_load_commands(image)
        self.assertEqual(parsed["arm64"].rpaths, ("@executable_path/ARM",))
        self.assertEqual(parsed["x86_64"].rpaths, ("@executable_path/Intel",))

    def test_one_architecture_cannot_borrow_another_architectures_runpaths(self):
        image = self.image("Fixture")
        dependency = [("@rpath/Shared.dylib", False)]
        self.images[image] = {
            "arm64": commands(dependency, ["@executable_path/ARM"]),
            "x86_64": commands(dependency, ["@executable_path/Intel"]),
        }
        self.image("ARM/Shared.dylib")
        missing = self.validate()["findings"]
        self.assertEqual(len(missing), 1)
        self.assertEqual(missing[0]["architecture"], "x86_64")
        self.assertEqual(missing[0]["candidates"], ["Intel/Shared.dylib"])

    def test_present_image_with_missing_executable_slice_fails(self):
        image = self.image("Fixture")
        self.images[image] = {"arm64": commands([("@loader_path/Wrong.dylib", False)])}
        wrong = self.image("Wrong.dylib")
        self.images[wrong] = {"x86_64": commands()}
        missing = self.validate()["findings"]
        self.assertEqual(len(missing), 1)
        self.assertEqual(missing[0]["owner"], "Wrong.dylib")
        self.assertEqual(missing[0]["architecture"], "arm64")

    def test_incompatible_first_runpath_allows_compatible_later_candidate(self):
        image = self.image("Fixture")
        self.images[image] = {"arm64": commands(
            [("@rpath/Shared.dylib", False)], ["@executable_path/Intel", "@executable_path/ARM"]
        )}
        wrong = self.image("Intel/Shared.dylib")
        self.images[wrong] = {"x86_64": commands()}
        correct = self.image("ARM/Shared.dylib")
        self.images[correct] = {"arm64": commands()}
        self.assertTrue(self.validate()["ok"])

    def test_otool_failure_does_not_silently_pass_as_no_dependencies(self):
        image = self.image("Fixture")
        with patch.object(RUNTIME.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "")):
            with self.assertRaisesRegex(ValueError, "otool"):
                RUNTIME.read_load_commands(image)

    def test_missing_bundle_executable_fails_even_without_images(self):
        report = self.validate()
        self.assertFalse(report["ok"])
        self.assertEqual(report["findings"][0]["dependency"], "CFBundleExecutable")

    def test_cli_writes_json_and_returns_nonzero_for_missing_dependency(self):
        self.image("Fixture", [("@loader_path/Missing.dylib", False)])
        report_path = self.app.parent / "reports/runtime.json"
        with patch.object(RUNTIME.Validator, "validate", return_value=self.validate()):
            self.assertEqual(RUNTIME.main(["--app", str(self.app), "--report", str(report_path)]), 1)
        self.assertFalse(json.loads(report_path.read_text())["ok"])


if __name__ == "__main__":
    unittest.main()
