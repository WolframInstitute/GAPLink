# Decision 0018: Preserve Windows shortcut files

- Status: Accepted
- Date: 2026-11-01
- Supersedes: [0017](0017-windows-runtime-archives.md)

## Why

GNU tar interprets Cygwin's Windows `.lnk` files as Unix symbolic links. The
resulting links can point outside the runtime when the archive is extracted
on Linux, preventing a complete paclet build. The v0.2.3 paclet kept these
shortcut files unchanged.

## Choice

Create and verify Windows runtime archives with Python's standard `tarfile`
command. It preserves the shortcut files as ordinary files. Use the native
Windows tar command only to extract GAP's required packages. Both tools are
already available on the CI runner; no new downloads are needed.

## Checks

Check the runtime archive and checksum, then compare every bundled runtime
file and its size with the source runtime. Runtime-copy failures stop the build.
Verify the installed paclet in a fresh Wolfram kernel.
