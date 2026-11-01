# Decision 0019: Account for paclet packaging exclusions

- Status: Accepted
- Date: 2026-11-01
- Refines: [0018](0018-windows-shortcut-files.md)

## Why

Wolfram's archive builder leaves out `.gitignore` files. The Linux build also
omits the Windows filename for Cygwin's `:` manual-page alias. Its contents
only refer to `man1/builtins.1`; GAP does not use it.

## Choice

Allow these specific files to be absent when comparing a paclet with its source
runtime. If they are present, still check their sizes. Check every other file,
including hidden files, executables, libraries, GAP data, licenses, and Cygwin
shortcuts. Missing, extra, or changed files fail the build.

Keep the source runtime archive unchanged.
