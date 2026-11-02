"""Check bundled runtime files, allowing documented packaging exclusions."""

import re
import shutil
import sys
from pathlib import Path, PurePosixPath
from zipfile import ZipFile


TEST_DIRECTORIES = {"Tests", "test", "tests", "tst", "__pycache__", ".pytest_cache"}
WINDOWS_REPOSITORY_LENGTH = 64  # Includes the separator before the installed paclet.


def development_file(name):
    path = PurePosixPath(name)
    parts = path.parts if name.endswith("/") else path.parts[:-1]
    return bool(TEST_DIRECTORIES.intersection(parts)) or path.suffix in {".pyc", ".pyo", ".wlt"}


def stage_runtime(runtime, destination):
    runtime = Path(runtime)
    # Fail before copying if a new upstream suite puts its license in an excluded tree.
    for path in runtime.rglob("*"):
        name = path.relative_to(runtime).as_posix()
        if path.is_file() and development_file(name) and path.name.upper().startswith(
                ("LICENSE", "LICENCE", "COPYING", "COPYRIGHT", "NOTICE")):
            raise ValueError("Keep the license notice before excluding its test suite: " + name)

    def ignore(directory, names):
        return [name for name in names if development_file(
            (Path(directory) / name).relative_to(runtime).as_posix()
            + ("/" if (Path(directory) / name).is_dir() else ""))]

    shutil.copytree(runtime, destination, ignore=ignore)


def verify_release(archive):
    with ZipFile(archive) as paclet:
        entries = paclet.infolist()
        excluded = [entry.filename for entry in entries if development_file(entry.filename)]
        if excluded:
            raise ValueError("Release contains test files or caches: " + ", ".join(excluded[:10]))
        metadata = [entry for entry in entries if entry.filename.count("/") == 1
                    and entry.filename.endswith("/PacletInfo.wl")]
        if len(metadata) != 1:
            raise ValueError("Release must contain one PacletInfo.wl")
        info = paclet.read(metadata[0]).decode("utf-8")
        if re.search(r'\{\s*"Test"\s*,', info):
            raise ValueError("Release declares a Test extension")
        if not re.search(r'"SystemID"\s*->\s*"Windows-x86-64"', info):
            return

        def field(name):
            match = re.search('"' + name + r'"\s*->\s*"([^"]+)"', info)
            if not match:
                raise ValueError("Missing Windows paclet metadata: " + name)
            return match[1]

        installed_root = "-".join((field("Name").replace("/", "__"),
                                   field("Qualifier"), field("Version")))
        for entry in entries:
            relative = entry.filename.split("/", 1)[1].rstrip("/")
            path = installed_root + "/" + relative
            # MAX_PATH counts UTF-16 code units, including the terminating NUL.
            length = WINDOWS_REPOSITORY_LENGTH + len(path.encode("utf-16-le")) // 2
            if length >= 260:
                raise ValueError(f"Windows install path is too long ({length}): {entry.filename}")
            parent = path if entry.is_dir() else path.rsplit("/", 1)[0]
            if WINDOWS_REPOSITORY_LENGTH + len(parent.encode("utf-16-le")) // 2 > 248:
                raise ValueError("Windows install directory is too long: " + entry.filename)


def may_be_omitted(name):
    # Wolfram's builder skips Git metadata and this Cygwin manual-page alias.
    return Path(name).name == ".gitignore" or name == "runtime/usr/share/man/man1/\uf03a.1.gz"


def verify(archive, runtime):
    verify_release(archive)
    runtime = Path(runtime)
    expected = {
        path.relative_to(runtime).as_posix(): path.stat().st_size
        for path in runtime.rglob("*")
        if path.is_file() and not development_file(path.relative_to(runtime).as_posix())
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
    try:
        if len(sys.argv) == 4 and sys.argv[1] == "--stage":
            stage_runtime(*sys.argv[2:])
            print("OK: runtime staged without test suites or caches")
        elif len(sys.argv) == 3 and sys.argv[1] == "--archive":
            verify_release(sys.argv[2])
            print("OK: release contents and Windows install paths")
        elif len(sys.argv) == 3:
            count = verify(*sys.argv[1:])
            print(f"OK: {count} runtime files match the source")
        else:
            sys.exit("Usage: verify-runtime.py ARCHIVE RUNTIME | --archive ARCHIVE | --stage RUNTIME DESTINATION")
    except (OSError, ValueError) as error:
        sys.exit(f"ERROR: {error}")
