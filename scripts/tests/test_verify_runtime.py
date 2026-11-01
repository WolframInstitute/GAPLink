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
