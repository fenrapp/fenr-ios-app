#!/usr/bin/env python3
"""Validate XcodeGen's resolved graph and the repository's Swift boundaries."""
import argparse
import fnmatch
import json
from pathlib import Path
import re
import subprocess
import sys


EXCEPTIONS = {
    ("RideNavigationAppleMaps", "RideNavigation"):
        "The Apple Maps adapter implements the feature's map surface and presentation contracts.",
    ("BikeDemo", "BikeEmulator"):
        "The dedicated demo feature injects the emulator through its use-case and mapper layer.",
    ("BikeOnboarding", "StarkProtocol"):
        "Pairing uses StarkPairingIdentity, the required canonical VIN normalization utility.",
}
SERVICES = {"VehicleSession", "RideSession", "ChargeControl"}
SUPPORT = {"AsyncSupport", "RuntimeConfiguration", "TestSupport"}
PRESENTATION = {"DesignSystem", "MeasurementPresentation"}
ALLOWED = {
    "domain": {"domain"},
    "data": {"domain", "sdk", "protocol", "support"},
    "sdk": {"domain", "protocol", "support"},
    "emulator": {"domain", "support"},
    "protocol": set(),
    "service": {"domain", "service", "support"},
    "feature": {"domain", "service", "presentation", "support"},
    "map-adapter": {"domain"},
    "presentation": set(),
    "support": set(),
}
IMPORT = re.compile(
    r"^[ \t]*(?:(?:@\w+(?:\([^\n]*?\))?|public|internal|private|fileprivate|package)[ \t]+)*"
    r"import\s+(?:(?:class|struct|enum|protocol|func|var|let|typealias)\s+)?([A-Za-z_]\w*)",
    re.MULTILINE,
)
LEGACY = re.compile(r"\bObservableObject\b|@(Published|ObservedObject|StateObject|EnvironmentObject)\b"
                    r"|\bimport\s+Combine\b")
UI_INFRASTRUCTURE = {"CoreBluetooth", "SwiftData", "CoreData", "Network", "Security"}
MODULE_TYPES = {"framework", "framework.static", "library.static", "library.dynamic"}


def code_without_comments_or_strings(source):
    """Preserve line offsets while removing comments, Swift strings and their contents."""
    pattern = re.compile(r'//[^\n]*|/\*|\*/|(?:#+)?"""|(?:#+)?"|\\.', re.MULTILINE)
    result = list(source)
    offset = 0
    while offset < len(source):
        match = pattern.search(source, offset)
        if not match:
            break
        start, end = match.span()
        token = match.group()
        if token.startswith("//"):
            pass
        elif token == "/*":
            depth = 1
            while depth and end < len(source):
                marker = re.search(r"/\*|\*/", source[end:])
                if not marker:
                    end = len(source)
                    break
                depth += 1 if marker.group() == "/*" else -1
                end += marker.end()
        elif '"' in token:
            hashes = len(token) - len(token.lstrip("#"))
            quote = '"""' if token.endswith('"""') else '"'
            terminator = quote + "#" * hashes
            while end < len(source):
                closing = source.find(terminator, end)
                if closing < 0:
                    end = len(source)
                    break
                escapes = len(source[:closing]) - len(source[:closing].rstrip("\\"))
                end = closing + len(terminator)
                if hashes or escapes % 2 == 0:
                    break
        else:
            offset = end
            continue
        for index in range(start, end):
            if result[index] != "\n":
                result[index] = " "
        offset = end
    return "".join(result)


def layer(name, target):
    if target.get("type") not in MODULE_TYPES:
        return "composition"
    if name in SERVICES:
        return "service"
    if name in SUPPORT:
        return "support"
    if name in PRESENTATION:
        return "presentation"
    if name == "RideNavigationAppleMaps":
        return "map-adapter"
    if name == "BikeSDK":
        return "sdk"
    if name == "StarkProtocol":
        return "protocol"
    if name == "BikeEmulator":
        return "emulator"
    if name.endswith("Domain"):
        return "domain"
    if name.endswith("Data"):
        return "data"
    if any(source["path"].startswith("Features/") for source in target.get("sources", [])):
        return "feature"
    return "unknown"


def source_files(root, target):
    files = set()
    for source in target.get("sources", []):
        path = root / source["path"]
        candidates = path.rglob("*.swift") if path.is_dir() else [path]
        for file in candidates:
            if not file.is_file() or file.suffix != ".swift":
                continue
            relative = file.relative_to(path if path.is_dir() else path.parent).as_posix()
            excludes = source.get("excludes", [])
            includes = source.get("includes", [])
            if any(fnmatch.fnmatch(relative, rule) or relative.startswith(rule.rstrip("/") + "/")
                   for rule in excludes):
                continue
            if includes and not any(fnmatch.fnmatch(relative, rule) for rule in includes):
                continue
            files.add(file)
    return sorted(files)


def validate(spec, root, exceptions=None):
    exceptions = EXCEPTIONS if exceptions is None else exceptions
    targets = spec["targets"]
    graph = {name: {item["target"] for item in target.get("dependencies", []) if "target" in item}
             for name, target in targets.items()}
    issues = []

    def issue(rule, detail, **context):
        issues.append(dict(rule=rule, detail=detail, **context))

    for owner, dependencies in sorted(graph.items()):
        owner_layer = layer(owner, targets[owner])
        if owner_layer == "unknown":
            issue("unknown-layer", "Classify the new framework before introducing dependencies.", target=owner)
        for dependency in sorted(dependencies):
            if dependency not in targets:
                issue("missing-target", "Dependency references an absent target.", target=owner, dependency=dependency)
            elif owner_layer != "composition" and (owner, dependency) not in exceptions:
                if layer(dependency, targets[dependency]) not in ALLOWED.get(owner_layer, set()):
                    issue("layer", "Dependency crosses a forbidden layer boundary.", target=owner, dependency=dependency)
    for edge, reason in sorted(exceptions.items()):
        if not reason.strip() or edge[1] not in graph.get(edge[0], set()):
            issue("stale-exception", "Remove unused exceptions; each exception requires a reason.",
                  target=edge[0], dependency=edge[1])

    visited, active = set(), []

    def visit(name):
        if name in active:
            issue("cycle", " -> ".join(active[active.index(name):] + [name]))
            return
        if name in visited or name not in graph:
            return
        active.append(name)
        for dependency in sorted(graph[name]):
            visit(dependency)
        active.pop()
        visited.add(name)
    for name in sorted(graph):
        visit(name)

    checked_files = set()
    for name, target in sorted(targets.items()):
        if target.get("type", "").startswith("bundle.unit-test"):
            continue
        owner_layer = layer(name, target)
        for file in source_files(root, target):
            relative = file.relative_to(root).as_posix()
            if "Tests" in file.parts:
                continue
            code = code_without_comments_or_strings(file.read_text())
            imports = list(IMPORT.finditer(code))
            if target.get("type") in MODULE_TYPES:
                for match in imports:
                    dependency = match.group(1)
                    if dependency in targets and dependency != name and dependency not in graph[name]:
                        issue("undeclared-import", "Declare the imported project dependency directly.",
                              target=name, dependency=dependency, path=relative,
                              line=code[:match.start()].count("\n") + 1)
            if file in checked_files:
                continue
            checked_files.add(file)
            for match in imports:
                dependency = match.group(1)
                line = code[:match.start()].count("\n") + 1
                if "UI" in file.parts and ((dependency in targets and dependency not in {name, "DesignSystem"})
                                          or dependency in UI_INFRASTRUCTURE):
                    issue("ui-import", "Views consume feature presentation models, not infrastructure.",
                          path=relative, line=line, dependency=dependency)
                if owner_layer in {"domain", "data", "sdk", "protocol", "service", "emulator", "support"}:
                    if dependency in {"SwiftUI", "DesignSystem"}:
                        issue("lower-layer-ui", "Lower layers cannot import SwiftUI or DesignSystem.",
                              path=relative, line=line, dependency=dependency)
            for match in LEGACY.finditer(code):
                issue("legacy-observation", "Owned production Swift uses Observation; legacy wrappers must not return.",
                      path=relative, line=code[:match.start()].count("\n") + 1)
    return {"targetCount": len(targets), "sourceFileCount": len(checked_files), "issues": issues,
            "exceptions": [{"from": edge[0], "to": edge[1], "reason": reason}
                           for edge, reason in sorted(exceptions.items())]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, help="Already resolved XcodeGen parsed-json spec; otherwise run XcodeGen.")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        spec = json.loads(args.spec.read_text() if args.spec else subprocess.check_output(
            ["xcodegen", "dump", "--type", "parsed-json", "--no-env"], cwd=root, text=True
        ))
        report = validate(spec, root)
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        report = {"issues": [{"rule": "validator-error", "detail": str(error)}]}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    for problem in report["issues"]:
        print(json.dumps(problem, sort_keys=True))
    print("Architecture: {} issue(s).".format(len(report["issues"])))
    return bool(report["issues"])


if __name__ == "__main__":
    sys.exit(main())
