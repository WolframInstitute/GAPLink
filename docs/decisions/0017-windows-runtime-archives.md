# Decision 0017: Windows runtime archives

- Status: Superseded by [0018](0018-windows-shortcut-files.md)
- Date: 2026-11-01
- Owner: GAPLink maintainers

## Why

The Windows runtime passed its GAP checks, but the system archive command failed
while compressing it in CI without reporting a cause.

## Choice

Use GNU tar and gzip from Git for Windows to create and read runtime archives.
The build requires these existing tools; it does not download another archiver.
Use forward slashes and `--force-local` for Windows paths, as GitHub's
[cache implementation](https://github.com/actions/toolkit/blob/main/packages/cache/src/internal/tar.ts) does.

## Checks

Read the finished archive before recording its checksum. Report command exit codes
when extraction, compression, or verification fails. Platform paclet CI still
extracts the runtime and checks the included files.
