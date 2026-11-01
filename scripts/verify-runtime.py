"""Check bundled runtime files, allowing documented packaging exclusions."""

import sys
from pathlib import Path
from zipfile import ZipFile


def may_be_omitted(name):
    # Wolfram's builder skips Git metadata and this Cygwin manual-page alias.
    return Path(name).name == ".gitignore" or name == "runtime/usr/share/man/man1/\uf03a.1.gz"


def verify(archive, runtime):
    runtime = Path(runtime)
    expected = {
        path.relative_to(runtime).as_posix(): path.stat().st_size
        for path in runtime.rglob("*") if path.is_file()
    }
    if not expected:
        raise ValueError("Source runtime is empty")
    with ZipFile(archive) as paclet:
        actual = {
            entry.filename.split("/Resources/Runtime/", 1)[1]: entry.file_size
            for entry in paclet.infolist()
            if "/Resources/Runtime/" in entry.filename and not entry.is_dir()
        }
    differences = sorted(
        name for name in expected.keys() | actual.keys()
        if expected.get(name) != actual.get(name)
        and not (name not in actual and may_be_omitted(name))
    )
    if differences:
        raise ValueError("Runtime files missing or changed: " + ", ".join(differences[:10]))
    return len(actual)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: verify-runtime.py ARCHIVE RUNTIME")
    try:
        count = verify(*sys.argv[1:])
    except (OSError, ValueError) as error:
        sys.exit(f"ERROR: {error}")
    print(f"OK: {count} runtime files match the source")
