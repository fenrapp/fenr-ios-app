#!/usr/bin/env python3
"""Check shipped Mach-O dependencies in an iOS/watchOS app, without launching it.

Each nested app/extension has its own executable context. Run paths are expanded
at the image that declares them, then inherited down the dependency chain.
System libraries may live in dyld's shared cache and need not exist on the host.
"""

import argparse
import json
import plistlib
import re
import struct
import subprocess
from pathlib import Path
from typing import NamedTuple


MACHO_MAGIC = {
    b"\xfe\xed\xfa\xce", b"\xce\xfa\xed\xfe",
    b"\xfe\xed\xfa\xcf", b"\xcf\xfa\xed\xfe",
    b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca",
    b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca",
}
LOAD_COMMANDS = {
    "LC_LOAD_DYLIB", "LC_LOAD_WEAK_DYLIB", "LC_REEXPORT_DYLIB",
    "LC_LOAD_UPWARD_DYLIB", "LC_LAZY_LOAD_DYLIB",
}
SYSTEM_ROOTS = ("/System/Library/", "/usr/lib/")


class Dependency(NamedTuple):
    name: str
    weak: bool


class LoadCommands(NamedTuple):
    dependencies: tuple
    rpaths: tuple


def parse_load_commands(output):
    """Read otool -l command payloads; LC_ID_DYLIB is deliberately not a load."""
    dependencies = []
    rpaths = []
    command = None
    for line in output.splitlines():
        text = line.strip()
        if text.startswith("Load command "):
            command = None
        elif text.startswith("cmd "):
            command = text.split()[1]
        elif command in LOAD_COMMANDS and text.startswith("name "):
            name = re.sub(r"\s+\(offset \d+\)$", "", text[5:])
            dependencies.append(Dependency(name, command == "LC_LOAD_WEAK_DYLIB"))
        elif command == "LC_RPATH" and text.startswith("path "):
            rpaths.append(re.sub(r"\s+\(offset \d+\)$", "", text[5:]))
    return LoadCommands(tuple(dict.fromkeys(dependencies)), tuple(dict.fromkeys(rpaths)))


def read_load_commands(binary):
    result = subprocess.run(
        ["otool", "-l", str(binary)], capture_output=True, text=True, check=False
    )
    if result.returncode or "Load command " not in result.stdout:
        raise ValueError("otool could not inspect Mach-O load commands")
    # Fat binaries have separate load commands per architecture. Combining their
    # run paths could incorrectly let one architecture satisfy another's load.
    sections = re.split(r"^.*\(architecture ([^)]+)\):\s*$", result.stdout, flags=re.MULTILINE)
    if len(sections) > 1:
        return {sections[index]: parse_load_commands(sections[index + 1]) for index in range(1, len(sections), 2)}
    with binary.open("rb") as source:
        header = source.read(12)
    if len(header) < 12:
        raise ValueError("Mach-O header is truncated")
    endian = "<" if header[:4] in (b"\xce\xfa\xed\xfe", b"\xcf\xfa\xed\xfe") else ">"
    cpu, subtype = struct.unpack(endian + "II", header[4:12])
    architecture = {
        7: "i386", 12: "arm", 0x01000007: "x86_64", 0x0100000C: "arm64", 0x0200000C: "arm64_32",
    }.get(cpu, f"cpu-{cpu}")
    if architecture == "arm64" and subtype & 0xFFFFFF == 2:
        architecture = "arm64e"
    elif architecture == "x86_64" and subtype & 0xFFFFFF == 8:
        architecture = "x86_64h"
    elif architecture == "arm":
        architecture = {6: "armv6", 9: "armv7", 11: "armv7s", 12: "armv7k"}.get(subtype & 0xFFFFFF, "arm")
    return {architecture: parse_load_commands(result.stdout)}


def is_macho(path):
    with path.open("rb") as source:
        return source.read(4) in MACHO_MAGIC


def is_system(path):
    return str(path).startswith(SYSTEM_ROOTS)


def is_cached_runpath(path):
    # A /usr/lib/swift fallback must never hide a missing app framework. Only
    # Swift runtime dylibs at that system location can resolve from its cache.
    return path.parent == Path("/usr/lib/swift") and bool(
        re.fullmatch(r"libswift[A-Za-z0-9_]+\.dylib", path.name)
    )


def expand_path(value, owner, executable):
    for token, directory in (
        ("@loader_path", owner.parent), ("@executable_path", executable.parent)
    ):
        if value == token or value.startswith(token + "/"):
            return (directory / value[len(token):].lstrip("/")).resolve()
    if value.startswith("/"):
        return Path(value).resolve()
    return None


def unique(items):
    return tuple(dict.fromkeys(items))


class Validator:
    def __init__(self, app, inspect=read_load_commands):
        self.app = Path(app).resolve()
        self.inspect = inspect
        self.images = {}
        self.executables = {}
        self.findings = []
        self.visited = set()
        self.covered = set()
        self.active = set()

    def display(self, path):
        try:
            return str(path.relative_to(self.app))
        except ValueError:
            # Do not print host-specific developer directories or signing paths.
            return "<outside app>/" + path.name

    def finding(self, owner, dependency, reason, candidates=(), executable=None, architecture=None):
        item = {
            "owner": self.display(owner), "dependency": dependency,
            "reason": reason, "candidates": [self.display(path) for path in candidates],
        }
        if executable is not None:
            item["executable"] = self.display(executable)
        if architecture is not None:
            item["architecture"] = architecture
        if item not in self.findings:
            self.findings.append(item)

    def discover(self):
        if not self.app.is_dir() or self.app.suffix != ".app":
            raise ValueError("--app must name an existing built .app bundle")
        files = sorted(self.app.rglob("*"))
        bundles = [self.app] + [
            path for path in files if path.is_dir() and path.suffix in (".app", ".appex")
        ]
        for bundle in bundles:
            try:
                with (bundle / "Info.plist").open("rb") as source:
                    name = plistlib.load(source)["CFBundleExecutable"]
                if not isinstance(name, str) or Path(name).name != name:
                    raise ValueError("invalid executable name")
                executable = (bundle / name).resolve()
                if not executable.is_relative_to(bundle.resolve()) or not executable.is_file():
                    raise ValueError("missing executable")
                self.executables[bundle.resolve()] = executable
            except (OSError, ValueError, KeyError, plistlib.InvalidFileException):
                self.finding(bundle, "CFBundleExecutable", "Missing or invalid bundle executable")
        for path in files:
            if not path.is_file():
                continue
            try:
                if not is_macho(path):
                    continue
                canonical = path.resolve()
                if not canonical.is_relative_to(self.app):
                    self.finding(path, path.name, "Embedded image resolves outside app")
                elif canonical not in self.images:
                    inspected = self.inspect(canonical)
                    self.images[canonical] = {None: inspected} if isinstance(inspected, LoadCommands) else inspected
            except (OSError, ValueError) as error:
                self.finding(path, "Mach-O", str(error) if isinstance(error, ValueError) else "Cannot read image")
        for executable in self.executables.values():
            if executable not in self.images:
                self.finding(executable, "Mach-O", "Bundle executable is not an inspectable Mach-O image")

    def context(self, image):
        matches = [bundle for bundle in self.executables if image.is_relative_to(bundle)]
        return self.executables[max(matches, key=lambda path: len(path.parts))] if matches else None

    def commands(self, owner, architecture):
        slices = self.images[owner]
        fallback = {"arm64e": "arm64", "x86_64h": "x86_64", "armv7s": "armv7"}.get(architecture)
        return slices.get(architecture, slices.get(fallback, slices.get(None)))

    def runpaths(self, owner, executable, inherited, architecture):
        own = []
        for value in self.commands(owner, architecture).rpaths:
            if value.startswith("@rpath/"):
                own.extend((path / value[7:]).resolve() for path in inherited)
            else:
                expanded = expand_path(value, owner, executable)
                if expanded is not None:
                    own.append(expanded)
        return unique([*own, *inherited])

    def visit(self, owner, executable, inherited=(), architecture=None):
        if owner not in self.images:
            return
        active_key = (owner, executable, architecture)
        if active_key in self.active:
            return
        self.active.add(active_key)
        try:
            self.visit_dependencies(owner, executable, inherited, architecture)
        finally:
            self.active.remove(active_key)

    def visit_dependencies(self, owner, executable, inherited, architecture):
        commands = self.commands(owner, architecture)
        if commands is None:
            self.finding(owner, "Mach-O slice", "Required executable architecture is absent", executable=executable, architecture=architecture)
            return
        runpaths = self.runpaths(owner, executable, inherited, architecture)
        key = (owner, executable, runpaths, architecture)
        if key in self.visited:
            return
        self.visited.add(key)
        self.covered.add((owner, executable, architecture))
        for dependency in commands.dependencies:
            name = dependency.name
            if is_system(name):
                continue
            if name.startswith("@rpath/"):
                candidates = [(path / name[7:]).resolve() for path in runpaths]
            else:
                expanded = expand_path(name, owner, executable)
                candidates = [expanded] if expanded is not None else []
            target = next((path for path in candidates if is_cached_runpath(path) or (
                path in self.images and self.commands(path, architecture) is not None
            )), None)
            if target is None:
                # Keep an incompatible image for an actionable missing-slice
                # diagnostic only after trying every compatible load path.
                target = next((path for path in candidates if path in self.images), None)
            if target is not None:
                if not is_cached_runpath(target):
                    self.visit(target, executable, runpaths, architecture)
            elif not dependency.weak:
                self.finding(
                    owner, name, "Required runtime image is missing from its load paths",
                    candidates, executable, architecture,
                )

    def validate(self):
        self.discover()
        for executable in self.executables.values():
            for architecture in self.images.get(executable, {}):
                self.visit(executable, executable, architecture=architecture)
        # Also inspect shipped plug-ins/debug images not statically reached from main.
        for image in sorted(self.images):
            executable = self.context(image)
            if executable:
                for architecture in self.images.get(executable, {}):
                    if self.commands(image, architecture) is not None and (image, executable, architecture) not in self.covered:
                        inherited = self.runpaths(executable, executable, (), architecture)
                        self.visit(image, executable, inherited, architecture)
        return {
            "app": self.app.name, "image_count": len(self.images),
            "executable_count": len(self.executables),
            "ok": not self.findings, "findings": self.findings,
        }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        report = Validator(args.app).validate()
    except (OSError, ValueError) as error:
        report = {"app": args.app.name, "ok": False, "findings": [
            {"owner": args.app.name, "dependency": "bundle", "reason": str(error), "candidates": []}
        ]}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if report["ok"]:
        print(f"Runtime dependencies OK: {report['app']} ({report['image_count']} Mach-O images)")
    else:
        for finding in report["findings"]:
            print(f"ERROR {finding['owner']} -> {finding['dependency']}: {finding['reason']}")
        print("Embed required frameworks in the executable bundle or correct its LC_RPATH entries.")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
