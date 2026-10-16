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
- GitHub and cloud publishing are jobs in the same tag workflow.
- GitHub Releases stores the paclets, checksums, and GAP source archives.
- Wolfram Cloud receives the same paclets after the GitHub release succeeds.
- The cloud keeps one latest file for each system.
- Each archive links to a public `ResourceObject` description of that platform's paclet.
- The cloud also receives a public page with the system-aware install command.
- GitHub keeps the versioned files. Published versions are not replaced.
- Credentials stay in GitHub secrets.

The install command selects the correct file with the user's `$SystemID`. Both direct
downloads and `ResourceObject` installs use the same verified archive. Resource descriptions
have separate identities for each platform and release, so cached downloads do not overlap.

## Other options

- Build the paclet again for each release.
- Publish every push to `main`.
- Publish only to GitHub or only to Wolfram Cloud.

## Result

Tags publish the verified platform files. Both publish jobs appear on the tagged commit.
Normal pushes do not publish.

## Checks

- Reject a tag that does not match the paclet version.
- Reject a tagged commit without successful `main` CI.
- Check each release checksum.
- Check public access to every archive, resource description, and page without signing in.
- Include the source for the bundled GAP files.
- Retry a cloud upload from the same GitHub release.
