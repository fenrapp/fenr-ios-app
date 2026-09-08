#!/usr/bin/env python3
"""Provision an official simulator runtime, reporting any oldest-available fallback explicitly."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


MINIMUM = {"iOS": "17.0", "watchOS": "10.0"}
FAMILY = {"iOS": "iPhone", "watchOS": "Apple Watch"}
PREFERRED_DEVICE = {"iOS": "iPhone 15", "watchOS": "Apple Watch Series 9 (45mm)"}


def version(value):
    parts = tuple(int(part) for part in value.split("."))
    return parts + (0,) * max(0, 3 - len(parts))


def available_runtimes(items, platform):
    prefix = "com.apple.CoreSimulator.SimRuntime." + platform + "-"
    return sorted((item for item in items if item.get("isAvailable")
                   and item["identifier"].startswith(prefix)
                   and version(item["version"]) >= version(MINIMUM[platform])),
                  key=lambda item: (version(item["version"]), item["identifier"]))


def runtime_candidates(items, platform, requested):
    available = available_runtimes(items, platform)
    exact = [item for item in available if version(item["version"]) == version(requested)]
    return exact + [item for item in available if item not in exact]


def compatible_devices(items, platform, runtime_version):
    current = version(runtime_version)
    matching = [item for item in items if item.get("productFamily") == FAMILY[platform]
                and version(item.get("minRuntimeVersionString", "0")) <= current
                <= version(item.get("maxRuntimeVersionString", "65535"))]
    return sorted(matching, key=lambda item: (item["name"] != PREFERRED_DEVICE[platform], item["name"]))


def execute(arguments, timeout=60):
    return subprocess.check_output(arguments, text=True, stderr=subprocess.STDOUT, timeout=timeout).strip()


def prepare(platform, requested, run=execute):
    report = {"platform": platform, "requestedVersion": requested, "status": "unavailable",
              "selectedVersion": None, "coverageGap": True, "attempts": [], "deviceID": None}
    list_command = ["xcrun", "simctl", "list", "runtimes", "--json"]
    runtimes = json.loads(run(list_command))["runtimes"]
    if not any(version(item["version"]) == version(requested) for item in available_runtimes(runtimes, platform)):
        try:
            run(["xcodebuild", "-downloadPlatform", platform, "-buildVersion", requested], timeout=1800)
            report["attempts"].append({"operation": "official-download", "succeeded": True})
        except subprocess.SubprocessError as error:
            report["attempts"].append({"operation": "official-download", "succeeded": False,
                                       "reason": str(error)})
        runtimes = json.loads(run(list_command))["runtimes"]
    devices = json.loads(run(["xcrun", "simctl", "list", "devicetypes", "--json"]))["devicetypes"]
    for runtime in runtime_candidates(runtimes, platform, requested):
        candidates = compatible_devices(devices, platform, runtime["version"])
        if not candidates:
            report["attempts"].append({"runtime": runtime["version"], "reason": "No compatible device type."})
        for device in candidates:
            identifier = None
            try:
                identifier = run(["xcrun", "simctl", "create", "FENR compatibility " + platform,
                                  device["identifier"], runtime["identifier"]])
                run(["xcrun", "simctl", "boot", identifier])
                run(["xcrun", "simctl", "bootstatus", identifier, "-b"], timeout=180)
            except subprocess.SubprocessError as error:
                report["attempts"].append({"runtime": runtime["version"], "device": device["name"],
                                           "reason": str(error)})
                if identifier:
                    try:
                        run(["xcrun", "simctl", "delete", identifier])
                    except (subprocess.SubprocessError, OSError):
                        pass
                continue
            exact = version(runtime["version"]) == version(requested)
            report.update(status="requested" if exact else "fallback", selectedVersion=runtime["version"],
                          runtimeID=runtime["identifier"], deviceID=identifier, deviceName=device["name"],
                          coverageGap=not exact,
                          destination="platform=" + platform + " Simulator,id=" + identifier)
            return report
    return report


def publish(report, report_path, output_path=None, summary_path=None):
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    if output_path:
        with Path(output_path).open("a") as output:
            for key, value in {
                "available": str(report["deviceID"] is not None).lower(),
                "coverage-gap": str(report["coverageGap"]).lower(),
                "selected-version": report.get("selectedVersion") or "unavailable",
                "destination": report.get("destination", ""),
                "device-id": report.get("deviceID") or "",
            }.items():
                output.write(key + "=" + value + "\n")
    selected = report.get("selectedVersion") or "none (no compatible simulator could boot)"
    message = ("{} compatibility: requested {}; selected {}; coverage gap: {}."
               .format(report["platform"], report["requestedVersion"], selected, report["coverageGap"]))
    print(message)
    if report["coverageGap"]:
        print("::warning::" + message)
    if summary_path:
        with Path(summary_path).open("a") as summary:
            summary.write("\n" + message + "\n")
            if report["coverageGap"]:
                summary.write("The requested runtime was not tested; see runtime-preflight.json for provisioning details.\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=MINIMUM, required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    try:
        version(args.version)
        report = prepare(args.platform, args.version)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        # Unexpected preflight/tool failures are errors, not silently reclassified as absent runtimes.
        report = {"platform": args.platform, "requestedVersion": args.version, "status": "error",
                  "selectedVersion": None, "coverageGap": True, "deviceID": None, "error": str(error)}
    publish(report, args.report, os.environ.get("GITHUB_OUTPUT"), os.environ.get("GITHUB_STEP_SUMMARY"))
    return report["status"] == "error"


if __name__ == "__main__":
    sys.exit(main())
