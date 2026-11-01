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
        for name in ["tst/.gitignore", "runtime/usr/share/man/man1/\uf03a.1.gz"]:
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


if __name__ == "__main__":
    unittest.main()
