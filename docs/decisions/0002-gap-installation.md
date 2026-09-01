# Decision 0002: GAP installation

- Status: Superseded by [decision 0013](0013-managed-gap-runtime.md)
- Date: 2026-08-27
- Owner: GAPLink maintainers

## Why

GAPLink needs GAP to run. We must decide whether users install GAP or GAPLink includes it.
GAP and its packages may have different licenses.

## Choice

For the first release, users install GAP themselves.

- GAPLink looks for GAP only when a GAP function is used.
- It first checks a path set by the user, then `PATH`, then common install locations.
- It checks GAP and reports the path and version found.
- It returns a clear `Failure` if GAP is missing or unsupported.
- It checks which optional GAP packages are installed.
- GAPLink does not download, install, or bundle GAP or GAP packages.
- We support only the versions and systems we test.

Including or installing GAP later will need a new decision and a license review.

## Other options

- Bundle GAP in the paclet.
- Download GAP on first use.
- Require libgap.

## Result

The paclet stays small. Users must install GAP before using GAPLink.

## Checks

- Test a user-set path, `PATH`, a missing install, and a broken install.
- Test each GAP version and system we support.
- Test finding optional packages.

## Sources

- [Installing GAP](https://www.gap-system.org/install/)
- [GAP copyright information](https://www.gap-system.org/copyright/)
