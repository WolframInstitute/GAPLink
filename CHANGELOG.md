# Changelog

Notable changes are listed here.

## [Unreleased]

### Fixed

- Read available GAP output without pausing between chunks of a large reply.

## [0.3.2] - 2026-11-01

### Fixed

- Publish the documentation site without overwriting the platform download directory.

## [0.3.1] - 2026-11-01

### Changed

- Publish the resource and documentation site with PacletPage using CI's verified build.
- Keep existing platform downloads and select the bundled runtime in the generated install commands.

## [0.3.0] - 2026-11-01

### Added

- Call retained GAP functions and functions in records, including the MTX library.
- Pass GAP's named options with `"GAPOptions"`.
- Add library tests and an upstream sweep with function availability and native comparisons.

### Fixed

- Keep characters in GAP so their character tables remain available.
- Preserve Windows runtime shortcut files and verify archives before caching them.
- Check bundled runtime files while allowing the archive builder's metadata and manual-page exclusions.
- Retain large or deeply nested containers and large permutations without expanding them for transfer. Reject oversized Wolfram Language permutations before allocating their dense images.

### Changed

- Build documentation and all paclet archives with pinned PacletPage tools.
- Replace separate command scripts and manual archive creation with `scripts/project.wls`.
- Keep documentation in Markdown and generate notebooks during builds.
- Verify each GAP version separately and check installed bundles in a fresh kernel.

## [0.2.3] - 2026-10-16

### Fixed

- Show download progress in the README and cloud page install commands.

## [0.2.2] - 2026-10-16

### Changed

- Allow reinstalling the same version with the README install command.

### Fixed

- Publish resource descriptions so `ResourceObject` installs select the correct platform archive.

## [0.2.1] - 2026-10-07

### Changed

- Show Wolfram Cloud publishing with the release checks.

### Fixed

- Fixed `GAPObject` display in notebooks.
- Restored public cloud downloads and added anonymous-access checks when publishing.

## [0.2.0] - 2026-09-02

### Added

- Added pinned GAP runtime builds, checksums, and platform paclet checks.
- Added a cloud page with the platform install command.

### Changed

- Chose one GAPLink release paclet with GAP for each supported system.
- Prefer GAP included in the paclet when starting a session.
- Restore executable permissions removed during paclet installation.
- Made platform runtime builds faster and reusable in CI.
- Reduced Wolfram kernel starts in CI and publishing.
- Reused the base build when creating platform paclets.

### Fixed

- Stopped CI documentation builds from opening extra licensed kernels.

## [0.1.0] - 2026-09-01

### Added

- Added the initial paclet, development commands, and CI.
- Added live tests for the supported GAP releases.
- Added `StartGAPSession` and `GAPSession`.
- Added `GAPCall` for named functions and basic values.
- Added `GAPEvaluate` for GAP code.
- Added package checks and package loading.
- Added loaded package versions to GAP sessions.
- Added command support for the official GAP Windows launcher.
- Added tagged GitHub releases and Wolfram Cloud publishing.
- Added reference pages for every public symbol.
- Added `GAPObject` for values kept in GAP.
- Added a persistent request loop and clean session shutdown.
- Added decisions for project scope, GAP installation, how GAP runs, the first public API,
  value conversion, error handling, supported systems, and the process protocol.

### Changed

- Simplified the project documentation.
- Renamed `Scripts/` to `scripts/` and simplified the development scripts.

### Fixed

- Fixed direct empty-list arguments to `GAPCall`.
- Fixed the GAP startup handshake.
- Removed repeated macOS warnings during startup.

[Unreleased]: https://github.com/WolframInstitute/GAPLink/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/WolframInstitute/GAPLink/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/WolframInstitute/GAPLink/compare/v0.2.3...v0.3.0
[0.2.3]: https://github.com/WolframInstitute/GAPLink/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/WolframInstitute/GAPLink/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/WolframInstitute/GAPLink/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/WolframInstitute/GAPLink/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/WolframInstitute/GAPLink/releases/tag/v0.1.0
