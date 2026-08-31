# Decision 0010: Loaded packages

- Status: Accepted
- Date: 2026-09-01
- Owner: GAPLink maintainers

## Why

Loading one GAP package can load other packages. Packages can also be loaded through
`GAPCall` or `GAPEvaluate`. GAPLink needs the versions GAP is actually using.

## Choice

`session["LoadedPackages"]` returns an association from package names to versions.

GAPLink asks the running GAP session each time. It does not cache the result. This includes
completed packages loaded at startup, as dependencies, or through any GAPLink call.

`session["Packages"]` keeps its current meaning: package names found when GAP started.

## Other options

- Cache packages loaded through `LoadGAPPackage`.
- Add another public function.
- Include loaded packages in every response.

## Result

Projects can record every GAP package version in use without depending on how it was loaded.

## Checks

- Return package names and versions from a new session.
- Update after loading a package.
- Include packages loaded through `GAPCall` and `GAPEvaluate`.
- Reject the query when the session is not ready.

## Sources

- [GAP 4.14 package state](https://github.com/gap-system/gap/blob/v4.14.0/lib/package.gd)
- [GAP 4.16 package state](https://github.com/gap-system/gap/blob/v4.16.1/lib/package.gd)
