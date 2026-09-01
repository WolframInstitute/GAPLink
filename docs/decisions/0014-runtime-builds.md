# Decision 0014: Runtime builds

- Status: Accepted
- Date: 2026-09-01
- Owner: GAPLink maintainers

## Why

Building GAP on every push is slow. The Intel macOS build can also spend too long running
GMP's full test suite. The Windows installer contains many packages that GAPLink does not
need.

## Choice

- Unix builds compile the pinned GAP and GMP sources.
- The runtime build skips GMP's full test suite. It checks the downloads, starts GAP, and
  loads a required package instead.
- Windows builds read the path used by the official GAP installer and copy only the
  required packages.
- CI caches each runtime archive by system and build script.
- CI checks each cached archive before uploading it.
- A cache miss builds a new runtime.

The release still uses the platform paclets produced by the tagged commit's CI run.

## Result

The first build does the full runtime work. Later builds reuse the same checked archive
until its build script changes.

## Checks

- Check every download against its pinned SHA-256 value.
- Start the built GAP runtime.
- On Windows, start GAP through the bundled Bash program used by GAPLink.
- Load a required GAP package.
- Run the GAPLink live tests before building platform paclets.
- Reject a cached archive when its checksum does not match.
