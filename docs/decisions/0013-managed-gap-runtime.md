# Decision 0013: Managed GAP runtime

- Status: Accepted
- Date: 2026-09-01
- Owner: GAPLink maintainers

## Why

GAPLink needs GAP to start a session. Requiring a separate GAP install makes setup harder and
can give users different GAP versions.

## Choice

Each GAPLink release will have one paclet for each supported system. Each paclet contains
the Wolfram Language code and a tested GAP runtime.

- The archive name includes its Wolfram System ID.
- The install command selects the archive with `$SystemID`.
- Loading GAPLink does not start GAP or change the system.
- GAPLink does not run Homebrew, APT, Windows installers, or other system package managers.
- A path given with `"Executable"` takes priority over the included runtime.
- Without an explicit path, GAPLink uses the included runtime.
- On macOS and Linux, GAPLink restores runtime execute permissions before first use.
- A GAP install on `PATH` remains a fallback for source checkouts and unsupported systems.

Each release pins one tested GAP version. GAPLink still accepts the system GAP versions
listed in [decision 0007](0007-supported-versions-and-systems.md).

The first runtime contains GAP core and GAP's required packages. Other GAP packages may be
added later. `GAPPackageAvailableQ` and `LoadGAPPackage` report what the active GAP runtime
provides.

Runtime releases must include:

- a fixed GAP version and source URL;
- checksums for every downloaded and released archive;
- the GAP copyright and license files;
- the scripts used to build each runtime; and
- access to the matching source from the same release.

The Windows runtime comes from GAP's official Windows installer. It keeps the launcher and
runtime files needed by GAPLink and removes packages that are not required.

The runtime files must pass a license review before they are published. GAPLink code
remains under the MIT license.

This decision replaces decision 0002 for published releases. External GAP installs remain
supported.

## Other options

- Keep requiring users to install GAP.
- Put every GAP build in one large paclet.
- Download GAP when the first session starts.
- Run a system package manager from GAPLink.

## Result

One `PacletInstall` installs GAPLink and GAP for the current system. Projects can still
select another GAP executable when needed.

## Checks

- Install the correct archive for each supported system.
- Start the included runtime without a system GAP install.
- Prefer an explicit `"Executable"` path.
- Fall back to `PATH` when a source checkout has no included runtime.
- Reject a missing, damaged, or unsupported runtime with a clear `Failure`.
- Verify runtime files and source archives with checksums.
- Review GAP, GMP, GAP package, and Cygwin licenses and source files.
- Run the live GAPLink tests against each runtime build.
- Test install, update, offline install, and uninstall.

## Sources

- [Wolfram Language paclets](https://reference.wolfram.com/language/tutorial/Paclets.html)
- [Wolfram System ID](https://reference.wolfram.com/language/ref/%24SystemID.html)
- [GAP releases](https://github.com/gap-system/gap/releases)
- [GAP copyright information](https://github.com/gap-system/gap/blob/master/COPYRIGHT)
- [GAP Windows build](https://github.com/gap-system/gap-windows/blob/641bc30aaccd0dd672bcd383105a90b034088d00/release_gap.sh)
