"""Negative fixtures for the graph and source boundary checks."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

PATH = Path(__file__).resolve().parents[1] / "validate-architecture.py"
SPEC = importlib.util.spec_from_file_location("architecture", PATH)
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


def target(path, dependencies=(), kind="framework"):
    return {"type": kind, "sources": [{"path": path}],
            "dependencies": [{"target": item} for item in dependencies]}


class ArchitectureTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.addCleanup(self.directory.cleanup)

    def write(self, path, code):
        file = self.root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(code)

    def rules(self, targets, exceptions=None):
        report = VALIDATOR.validate({"targets": targets}, self.root, exceptions or {})
        return {item["rule"] for item in report["issues"]}

    def test_missing_target_and_cycle_are_reported(self):
        targets = {"FirstDomain": target("Modules/FirstDomain/Sources", ["SecondDomain", "Absent"]),
                   "SecondDomain": target("Modules/SecondDomain/Sources", ["FirstDomain"])}
        self.assertEqual(self.rules(targets), {"missing-target", "cycle"})

    def test_domain_cannot_depend_on_feature_or_ui(self):
        self.write("Modules/BikeDomain/Sources/Entity.swift", "import SwiftUI\nimport Screen\n")
        targets = {"BikeDomain": target("Modules/BikeDomain/Sources", ["Screen"]),
                   "Screen": target("Features/Screen/Sources")}
        self.assertEqual(self.rules(targets), {"layer", "lower-layer-ui"})

    def test_feature_views_reject_even_declared_domain_imports(self):
        self.write("Features/Screen/Sources/UI/View.swift", "@preconcurrency import BikeDomain\nimport CoreBluetooth\n")
        targets = {"Screen": target("Features/Screen/Sources", ["BikeDomain"]),
                   "BikeDomain": target("Modules/BikeDomain/Sources")}
        self.assertEqual(self.rules(targets), {"ui-import"})

    def test_module_import_requires_direct_dependency(self):
        self.write("Features/Screen/Sources/Model.swift", "import struct BikeDomain.Entity\n")
        targets = {"Screen": target("Features/Screen/Sources"),
                   "BikeDomain": target("Modules/BikeDomain/Sources")}
        self.assertEqual(self.rules(targets), {"undeclared-import"})

    def test_exception_is_exact_and_must_remain_used(self):
        targets = {"BikeDemo": target("Features/BikeDemo/Sources", ["BikeEmulator"]),
                   "BikeEmulator": target("Modules/BikeEmulator/Sources")}
        exception = {("BikeDemo", "BikeEmulator"): "Dedicated demo integration."}
        self.assertFalse(self.rules(targets, exception))
        targets["BikeDemo"]["dependencies"] = []
        self.assertEqual(self.rules(targets, exception), {"stale-exception"})

    def test_comments_strings_and_excluded_sources_do_not_raise_false_positives(self):
        self.write("Features/Screen/Sources/Model.swift", '''// import Combine
/* outer /* nested */ @Published */
let example = "@ObservedObject"
let raw = #"import BikeDomain"#
let multiline = """
import Combine
"""
import Observation
''')
        self.write("Features/Screen/Sources/Excluded/Old.swift", "import Combine\n")
        screen = target("Features/Screen/Sources")
        screen["sources"][0]["excludes"] = ["Excluded"]
        self.assertFalse(self.rules({"Screen": screen}))

    def test_legacy_observation_is_rejected_in_app_and_features(self):
        self.write("App/Sources/Root.swift", "@StateObject var model: Model\n")
        self.write("Features/Screen/Sources/Model.swift", "class Model: ObservableObject { @Published var state = 0 }\n")
        self.assertEqual(self.rules({"App": target("App/Sources", kind="application"),
                                     "Screen": target("Features/Screen/Sources")}), {"legacy-observation"})

    def test_unclassified_framework_is_not_silently_allowed(self):
        self.assertEqual(self.rules({"NewUtility": target("Modules/NewUtility/Sources")}), {"unknown-layer"})

    def test_modules_cannot_reintroduce_environment_object_or_legacy_observation(self):
        self.write("Modules/ChargeControl/Sources/Session.swift", "@EnvironmentObject var session: Session\n")
        self.assertEqual(self.rules({"ChargeControl": target("Modules/ChargeControl/Sources")}),
                         {"legacy-observation"})


if __name__ == "__main__":
    unittest.main()
