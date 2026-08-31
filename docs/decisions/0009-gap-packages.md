# Decision 0009: GAP packages

- Status: Accepted
- Date: 2026-09-01
- Owner: GAPLink maintainers

## Why

GAP features often come from optional packages. GAPLink must check and load them without
assuming that every GAP installation has the same packages.

## Choice

`GAPPackageAvailableQ[session, name]` checks whether GAP can load a package.
`LoadGAPPackage[session, name]` loads it and returns its name and version.

Both functions accept `TimeConstraint` and `"Version"`. The version may be `Automatic` or a
GAP version requirement string. Package names are case insensitive.

GAPLink uses GAP's `TestPackageAvailability`, `LoadPackage`, and
`InstalledPackageVersion` functions. It does not install packages. A package that cannot be
loaded returns `Failure["GAPPackageNotAvailable", ...]`.

## Other options

- Ask users to call GAP's package functions through `GAPCall`.
- Add package installation to GAPLink.
- Add a new private protocol operation for packages.

## Result

Projects can check optional packages, load them, and record the version in use. Package
installation stays with GAP and the user.

## Checks

- Check an available and a missing package.
- Check a package version requirement.
- Load a package and return its version.
- Return a clear failure when a package cannot be loaded.
- Keep the session ready after a package failure.

## Sources

- [GAP package availability](https://docs.gap-system.org/doc/ref/chap76_mj.html#X8580DF257E4D7046)
- [GAP package loading](https://docs.gap-system.org/doc/ref/chap76_mj.html#X79B373A77B29D1F5)
