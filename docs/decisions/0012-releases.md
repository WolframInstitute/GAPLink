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
- The tag workflow reuses that CI artifact and creates its SHA-256 checksum.
- GitHub Releases stores the paclet and checksum.
- Wolfram Cloud receives the same paclet after the GitHub release succeeds.
- The cloud keeps one versioned archive and one link to the latest release.
- A versioned archive can be retried from the same commit. Another commit cannot replace it.
- Credentials stay in GitHub secrets.

GAPLink publishes only the paclet archive. It does not publish a separate resource page.

## Other options

- Build the paclet again for each release.
- Publish every push to `main`.
- Publish only to GitHub or only to Wolfram Cloud.

## Result

Tags publish one verified file in both places. Normal pushes do not publish.

## Checks

- Reject a tag that does not match the paclet version.
- Reject a tagged commit without successful `main` CI.
- Check the release checksum against the paclet.
- Retry the same release without changing its versioned cloud archive.
