import subprocess
import sys
import tarfile
import tempfile
import unittest
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
from zipfile import ZipFile

spec = spec_from_file_location("verify_runtime", Path(__file__).parents[1] / "verify-runtime.py")
runtime_check = module_from_spec(spec)
spec.loader.exec_module(runtime_check)


class RuntimeArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.runtime = self.root / "runtime"
        self.runtime.mkdir()
        self.files = {"gap.exe": b"MZ runtime", "sphinx-build.lnk": b"L\0\0\0Cygwin shortcut"}
        for name, contents in self.files.items():
            (self.runtime / name).write_bytes(contents)
        self.archive = self.root / "test.paclet"

    def pack(self, files):
        with ZipFile(self.archive, "w") as archive:
            archive.writestr("GAPLink/PacletInfo.wl", 'PacletObject[<|"Name" -> "WolframInstitute/GAPLink"|>]')
            for name, contents in files.items():
                archive.writestr("GAPLink/Resources/Runtime/" + name, contents)

    def test_complete_runtime(self):
        self.pack(self.files)
        self.assertEqual(runtime_check.verify(self.archive, self.runtime), 2)

    def test_reject_missing_shortcut(self):
        self.pack({"gap.exe": self.files["gap.exe"]})
        with self.assertRaisesRegex(ValueError, "sphinx-build.lnk"):
            runtime_check.verify(self.archive, self.runtime)

    def test_reject_truncated_executable(self):
        self.pack({**self.files, "gap.exe": b"MZ"})
        with self.assertRaisesRegex(ValueError, "gap.exe"):
            runtime_check.verify(self.archive, self.runtime)

    def test_allow_packaging_exclusions(self):
        for name in ["lib/.gitignore", "runtime/usr/share/man/man1/\uf03a.1.gz"]:
            path = self.runtime / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"packaging metadata or manual alias")
        self.pack(self.files)
        self.assertEqual(runtime_check.verify(self.archive, self.runtime), 2)

    def test_check_excluded_file_when_present(self):
        (self.runtime / ".gitignore").write_bytes(b"original")
        self.pack({**self.files, ".gitignore": b"changed size"})
        with self.assertRaisesRegex(ValueError, ".gitignore"):
            runtime_check.verify(self.archive, self.runtime)

    def test_reject_other_missing_hidden_files(self):
        (self.runtime / ".gaprc").write_bytes(b"runtime settings")
        self.pack(self.files)
        with self.assertRaisesRegex(ValueError, ".gaprc"):
            runtime_check.verify(self.archive, self.runtime)

    def test_reject_other_missing_manual_pages(self):
        path = self.runtime / "runtime/usr/share/man/man1/gap.1.gz"
        path.parent.mkdir(parents=True)
        path.write_bytes(b"manual")
        self.pack(self.files)
        with self.assertRaisesRegex(ValueError, "gap.1.gz"):
            runtime_check.verify(self.archive, self.runtime)

    def test_runtime_tar_keeps_shortcut_file(self):
        archive = self.root / "runtime.tar.gz"
        subprocess.run([sys.executable, "-m", "tarfile", "--create", str(archive), "runtime"],
                       cwd=self.root, check=True)
        with tarfile.open(archive) as packed:
            shortcut = packed.getmember("runtime/sphinx-build.lnk")
            self.assertTrue(shortcut.isfile())
            self.assertEqual(packed.extractfile(shortcut).read(), self.files["sphinx-build.lnk"])

    def test_stage_omits_suites_and_caches_without_changing_source(self):
        keep = {
            **self.files, "lib/test.gi": b"GAP Test API", "bin/test.exe": b"shell test",
            "usr/share/perl5/Test/Builder.pm": b"Perl API", "licenses/COPYING": b"license",
            "site-packages/jinja2/tests.py": b"template predicates",
        }
        omit = {
            "pkg/gapdoc/tst/test.tst": b"suite",
            "lib/python3.9/test/test_os.py": b"suite",
            "lib/python3.9/site-packages/pkg_resources/tests/data/"
            "my-test-package_unpacked-egg/my_test_package-1.0-py3.7.egg/EGG-INFO/SOURCES.txt": b"fixture",
            "lib/python3.9/__pycache__/os.cpython-39.pyc": b"cache",
            "module.pyc": b"bytecode", ".pytest_cache/README.md": b"cache",
        }
        for name, contents in (keep | omit).items():
            path = self.runtime / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(contents)
        target = self.root / "staged"
        runtime_check.stage_runtime(self.runtime, target)
        actual = {p.relative_to(target).as_posix(): p.read_bytes()
                  for p in target.rglob("*") if p.is_file()}
        self.assertEqual(actual, keep)
        for name, contents in omit.items():
            self.assertEqual((self.runtime / name).read_bytes(), contents)
        self.pack(actual)
        self.assertEqual(runtime_check.verify(self.archive, self.runtime), len(keep))

    def test_stage_refuses_to_discard_license_notice(self):
        notice = self.runtime / "tests/LICENSE.txt"
        notice.parent.mkdir()
        notice.write_text("license")
        target = self.root / "staged"
        with self.assertRaisesRegex(ValueError, "license notice"):
            runtime_check.stage_runtime(self.runtime, target)
        self.assertFalse(target.exists())

    def test_reject_test_files_and_caches_in_release(self):
        for name in ["Tests/Unit.wlt", "Resources/Runtime/pkg/tst/test.g",
                     "Resources/Runtime/lib/__pycache__/os.pyc"]:
            with self.subTest(name=name):
                self.pack(self.files)
                with ZipFile(self.archive, "a") as archive:
                    archive.writestr("GAPLink/" + name, b"test")
                with self.assertRaisesRegex(ValueError, "test files or caches"):
                    runtime_check.verify(self.archive, self.runtime)

    def test_reject_test_extension_in_release(self):
        with ZipFile(self.archive, "w") as archive:
            archive.writestr("GAPLink/PacletInfo.wl", 'PacletObject[<|"Extensions" -> {{"Test", "Root" -> "Tests"}}|>]')
        with self.assertRaisesRegex(ValueError, "Test extension"):
            runtime_check.verify_release(self.archive)

    def windows_archive(self, name):
        with ZipFile(self.archive, "w") as archive:
            archive.writestr("GAPLink/PacletInfo.wl", '''PacletObject[<|
                "Name" -> "WolframInstitute/GAPLink", "Version" -> "0.3.3",
                "Qualifier" -> "Windows-x86-64", "SystemID" -> "Windows-x86-64"|>]''')
            archive.writestr("GAPLink/Resources/Runtime/" + name, b"runtime")

    def test_windows_path_limit_counts_installed_paclet_name(self):
        for name, valid in [("x" * 130, True), ("x" * 131, False), ("x" * 129 + "\U0001f600", False)]:
            with self.subTest(name=name):
                self.windows_archive(name)
                if valid:
                    runtime_check.verify_release(self.archive)
                else:
                    with self.assertRaisesRegex(ValueError, "Windows install path is too long"):
                        runtime_check.verify_release(self.archive)

    def test_windows_directory_limit(self):
        self.windows_archive("x" * 120 + "/file.txt")
        with self.assertRaisesRegex(ValueError, "Windows install directory is too long"):
            runtime_check.verify_release(self.archive)


if __name__ == "__main__":
    unittest.main()
