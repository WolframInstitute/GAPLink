# Decision 0012: Releases

- Status: Accepted
- Date: 2026-09-01
- Owner: GAPLink maintainers

## Why

A release should use the paclet that passed CI. Rebuilding after a tag could produce a
different file.

## Choice

- A `vMAJOR.MINOR.PATCH` tag must match `PacletInfo.wl`.
- The tagged commit must have a successful `main` CI run.
- The tag workflow reuses the four platform paclets that passed CI.
- GitHub Releases stores the paclets, checksums, and GAP source archives.
- Wolfram Cloud receives the same paclets after the GitHub release succeeds.
- The cloud keeps one latest file for each system.
- The cloud also receives a public page with the system-aware install command.
- GitHub keeps the versioned files. Published versions are not replaced.
- Credentials stay in GitHub secrets.

The page is a static file because GAPLink has one paclet for each system. Its install command
selects the correct file with `$SystemID`.

## Other options

- Build the paclet again for each release.
- Publish every push to `main`.
- Publish only to GitHub or only to Wolfram Cloud.

## Result

Tags publish the verified platform files. Normal pushes do not publish.

## Checks

- Reject a tag that does not match the paclet version.
- Reject a tagged commit without successful `main` CI.
- Check each release checksum.
- Include the source for the bundled GAP files.
- Retry a cloud upload from the same GitHub release.
