# Changelog

Notable changes are listed here.

## [Unreleased]

### Added

- Added the initial paclet, development commands, and CI.
- Added live tests for GAP 4.14.0, 4.15.1, and 4.16.1.
- Added `StartGAPSession` and `GAPSession`.
- Added `GAPCall` for named functions and basic values.
- Added `GAPEvaluate` for GAP code.
- Added package checks and package loading.
- Added loaded package versions to GAP sessions.
- Added command support for the official GAP Windows launcher.
- Added tagged GitHub releases and Wolfram Cloud publishing.
- Added reference pages for every public symbol.
- Added `GAPObject` for values kept in GAP.
- Fixed direct empty-list arguments to `GAPCall`.
- Added a persistent request loop and clean session shutdown.
- Added decisions for project scope, GAP installation, how GAP runs, the first public API,
  value conversion, error handling, supported systems, and the process protocol.

### Changed

- Simplified the project documentation.
- Renamed `Scripts/` to `scripts/` and simplified the development scripts.

### Fixed

- Fixed the GAP startup handshake.
- Removed repeated macOS warnings during startup.

[Unreleased]: https://github.com/WolframInstitute/GAPLink/commits/main
