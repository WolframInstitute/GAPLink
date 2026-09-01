# Decision 0007: Supported versions and systems

- Status: Accepted
- Date: 2026-08-28
- Owner: GAPLink maintainers

## Why

GAPLink starts a GAP program installed by the user. GAP versions and operating systems can
change executable paths, process input and output, time limits, and shutdown behavior. We
need a clear test range without blocking systems that may also work.

## Choice

The first release requires Wolfram Language 15.0 or later and targets standard 64-bit GAP.
It supports these GAP release lines:

- GAP 4.14.x
- GAP 4.15.x
- GAP 4.16.x

CI tests one pinned version from each supported release line. Tests do not use a moving
`latest` version.

GAP 4.14 is the minimum. An older version returns `Failure["GAPStartFailed", ...]`. A newer
stable GAP 4 release may start, but GAPLink warns that it has not been tested. GAP 5 needs a
new review before use. Development releases, prereleases, and HPC-GAP are not part of the
first support range.

GAPLink targets:

- Linux x86-64
- macOS on Intel and Apple silicon
- Windows x86-64

WSL counts as Linux. Native Windows is a separate target.

GAPLink does not reject a system based only on its operating system or processor. Other
systems may work, but they are not supported until the integration tests pass there.

Linux x86-64 is the first system tested in CI. macOS and Windows must pass the same process
tests before the first release claims full support for them. The Wolfram Language code must
not rely on shell syntax, Unix paths, or Unix-only process signals.

Tests that need GAP stay separate from tests that do not. GAP tests cover exact supported
versions and pin every download. Optional GAP packages are not required for base support.
The session reports the GAP version, system, processor, and installed packages.

## Other options

- Support Linux only.
- Support only the newest GAP release.
- Claim support for every GAP 4 release.
- Treat WSL as native Windows support.
- Reject any system that is not tested in CI.

## Result

GAPLink stays portable from the start. Users on macOS and Windows are not blocked while
tests are added. Release notes can state which systems and versions have been verified.

## Checks

- Test each supported GAP release line on Linux x86-64.
- Reject a GAP release older than 4.14.
- Warn for a newer stable GAP 4 release that has not been tested.
- Report the GAP version, system, processor, and packages.
- Run startup, calls, errors, time limits, aborts, and shutdown tests on each system.
- Check native macOS and Windows before claiming full support for them.
- Confirm that base tests do not need optional GAP packages.

## Sources

- [Installing GAP](https://www.gap-system.org/install/)
- [GAP on Linux](https://www.gap-system.org/install/linux/)
- [GAP on macOS](https://www.gap-system.org/install/mac/)
- [GAP on Windows](https://www.gap-system.org/install/windows/)
- [GAP releases](https://github.com/gap-system/gap/releases)
- [Setup GAP for GitHub Actions](https://github.com/gap-actions/setup-gap)
- [Wolfram Language StartProcess](https://reference.wolfram.com/language/ref/StartProcess.html)
