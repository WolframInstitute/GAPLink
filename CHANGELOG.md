# Changelog

Notable changes are listed here.

## [Unreleased]

## [0.2.0] - 2026-09-01

### Added

- Added pinned GAP runtime builds, checksums, and platform paclet checks.
- Added a cloud page with the platform install command.

### Changed

- Chose one GAPLink release paclet with GAP for each supported system.
- Prefer GAP included in the paclet when starting a session.
- Restore executable permissions removed during paclet installation.
- Made platform runtime builds faster and reusable in CI.

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

[Unreleased]: https://github.com/WolframInstitute/GAPLink/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/WolframInstitute/GAPLink/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/WolframInstitute/GAPLink/releases/tag/v0.1.0
