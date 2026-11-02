# Release contents

Status: accepted

Date: 2026-11-03

Published paclets contain the library, documentation, and runtime. Keep GAPLink's
tests in the repository and CI, and omit the Test extension from paclet metadata.
Use PacletPage's archive exclusions for the source test directory.

Stage runtimes without test suites (`test`, `tests`, `tst`), Python bytecode,
or test caches. Match whole directory names, with case preserved: runtime APIs
such as GAP's `lib/test.gi`, the shell's `test.exe`, and Perl's `Test` modules
are executable library code and must remain. Leave the original runtime and
matching upstream source archives unchanged. Refuse to discard license notices.

The Windows 0.3.2 archive contained Python package test fixtures whose installed
paths exceeded MAX_PATH. Check every release archive for excluded files, compare
all retained runtime files with the original inventory, and check Windows paths
against the 260-character limit, reserving 64 characters for the repository path
including its final separator. Longer custom repository paths may need Windows
long-path support. Preserve the Cygwin shortcut and manual-page rules from
[0018](0018-windows-shortcut-files.md) and
[0019](0019-runtime-inventory-exclusions.md).

Test the staging and archive checks with fixture paths from the reported failure,
required runtime files, and license notices. Verify the staged runtime on native
Windows, build all four platform paclets in CI, and exercise installed bundles.
