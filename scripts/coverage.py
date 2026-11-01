#!/usr/bin/env python3
"""Prepare GAP's source path and compare upstream failures outside Wolfram kernels."""
from collections import Counter
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile


def launcher(executable, source, target):
    if os.name != "posix":
        sys.exit("The upstream sweep currently needs a POSIX GAP launcher.")
    Path(target).write_text(
        "#!/bin/sh\nexec " + shlex.quote(executable) + " -l "
        + shlex.quote(";" + source) + ' "$@"\n'
    )
    Path(target).chmod(0o755)


def compare(directory):
    directory = Path(directory).resolve()
    rows = json.loads((directory / "tests.json").read_text())
    helper = (directory / "helper.g").read_text()
    executable = str(directory / "gap-coverage")
    for index, row in enumerate(rows, 1):
        if row["Status"] != "Review":
            continue
        case_path = directory / f"case-{index}.json"
        case = json.loads(case_path.read_text())
        with tempfile.TemporaryDirectory(prefix="gaplink-native-") as scratch:
            report = Path(scratch) / "result.txt"
            script = Path(scratch) / "test.g"
            script.write_text(
                helper + "\nFileString(" + json.dumps(str(report))
                + ", GAPLinkCoverageTest(" + json.dumps(case["File"], ensure_ascii=False)
                + ").Differences);\nQUIT;\n"
            )
            try:
                native = subprocess.run(
                    [executable, "-q", "-n", "-A", "-r", "--nointeract", str(script)],
                    cwd=scratch, capture_output=True, text=True, timeout=60,
                )
                actual = report.read_text() if report.exists() else None
                case["Native"] = {"ExitCode": native.returncode, "Differences": actual,
                                  "Output": native.stdout, "Error": native.stderr}
                row["Status"] = (
                    "UpstreamDifference" if native.returncode == 0 and actual is not None
                    and actual == case["Differences"] else "Failed"
                )
            except subprocess.TimeoutExpired:
                case["Native"] = {"TimedOut": True}
                row["Status"] = (
                    "TimedOut" if "GAPTimeConstraintExceeded" in str(case["Bridge"]) else "Failed"
                )
        case_path.write_text(json.dumps(case, indent=2) + "\n")
        print(row["Status"], row["File"], flush=True)
    summary_path = directory / "summary.json"
    summary = json.loads(summary_path.read_text())
    summary["Tests"] = dict(Counter(row["Status"] for row in rows))
    (directory / "tests.json").write_text(json.dumps(rows, indent=2) + "\n")
    summary_path.write_text(json.dumps(summary, indent=2) + "\n")
    print(summary["Tests"])
    return int(any(row["Status"] in {"Failed", "TimedOut"} for row in rows))


if __name__ == "__main__":
    if sys.argv[1] == "--launcher":
        launcher(*sys.argv[2:])
    elif sys.argv[1] == "compare":
        sys.exit(compare(sys.argv[2]))
    else:
        sys.exit("Usage: coverage.py --launcher EXECUTABLE SOURCE TARGET | compare DIRECTORY")
