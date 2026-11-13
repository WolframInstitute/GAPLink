# Contributing

## Requirements

- Wolfram Language 15.0 or later
- `wolframscript` on `PATH`
- Git and `make`
- Python 3 for the cloud download checks
- GAP 4.14–4.16 for the live session test

GAP is not needed for `make test`.

## Project rules

- GAPLink must not depend on projects that use it.
- Loading the paclet must not start or install GAP.
- Do not tie public functions to one way of running GAP.
- Review licenses before adding GAP code, packages, or binaries.
- Keep GAP tests separate from tests that do not need GAP.

## Development

```bash
make check
make test
make test-gap
make all
```

`make test-gap` finds `gap` on `PATH`. To set its path:

```bash
GAPLINK_GAP=/path/to/gap make test-gap
```

To run chosen test files:

```bash
make test FILES="GAPLink/Tests/Call.wlt"
```

To use a source checkout in a session, load it before `Needs`:

```wl
PacletDirectoryLoad["/path/to/GAPLink/GAPLink"];
```

The development scripts are one package under `scripts/`. `scripts/project.wls` runs one
command, and `make help` lists the commands.

To build and test a release paclet for the current system:

```bash
make runtime
make bundle
make verify-bundle
```

`make all` fetches pinned PacletPage tools, checks the source, runs offline tests,
and builds the documentation and archive. The examples are evaluated against GAP;
set `GAPLINK_GAP` when it is not on `PATH`. `make check test` remains GAP-free.

Edit documentation in `docs/en/` and `docs/ResourceDefinition.md`. PacletPage
creates the notebooks, builds the archive, checks its pages, and loads it in a
fresh kernel. Generated notebooks and build caches are not committed.

The same builder creates platform archives. Native runtime builders and the
platform cloud uploader remain separate because they manage platform-specific
binaries and the existing download URLs.

Published paclets exclude GAPLink tests, runtime test suites, and caches. Archive
checks enforce these exclusions and the Windows path budget, while checking every
retained runtime file against its source. Tests and matching upstream sources stay
available separately; see [release contents](docs/decisions/0022-release-contents.md).

To run upstream tests with a matching GAP source tree:

```bash
GAPLINK_GAP=/path/to/gap GAPLINK_SOURCE=/path/to/gap-source make sweep
```

Reports are written to `build/coverage/`; see [coverage](docs/coverage.md).
Runtime builds also need a C/C++ compiler, `curl`, and `tar`.

The official Windows `gap.bat` layout is supported. Native Windows still needs the live
session test before it is listed as verified.

## Style

Wolfram Language code follows the [coding guides](docs/coding-guides/README.md). That page
says how GAPLink applies them, how the check works and how a rule is waived.

```bash
make style-fix FILES="GAPLink/Kernel/Call.wl"   # apply the mechanical fixes
make style FILES="GAPLink/Kernel/Call.wl"       # check against the coding guides
make lint FILES="GAPLink/Kernel/Call.wl"        # CodeInspector and the style check
```

Without `FILES`, `make style` checks every file. `make check`, the pre-commit hook and CI
run the same check.

- Use UTF-8, LF line endings, and tabs for Wolfram Language files.
- Add a usage message, test, documentation, and changelog entry for each public symbol.
- Give each test a clear `TestID`.

## Git

Enable the hooks with:

```bash
make hooks
```

Use Conventional Commits:

```text
type(optional-scope): short description
```

## CI

CI runs on pushes to `main` and pull requests into `main`, and by hand with
`gh workflow run ci.yml --ref main`. It does not run for a change only to files it never
reads, such as `CHANGELOG.md` and the decision records; `paths-ignore` in `ci.yml` lists
them. To skip CI for another push, write `[skip ci]` in the body of its last commit, but
not in a release commit: a release needs CI's build of its own commit. CI keeps its build
artifacts for seven days.

CI uses Wolfram Engine 15.0. The Wolfram job takes its license from one of two secrets: a
license line or an entitlement. When both are set, it uses the license line.

### License line

`WOLFRAM_MATHPASS_B64` holds a license line (mathpass) for one machine. With it the kernel
runs offline and spends no Service Credits.

The line has four parts with tabs between them: machine name, MathID, activation key and
password. Keep it in `.mathpass`, which git ignores, and store it base64-encoded, so that
the tabs survive:

```bash
base64 < .mathpass | tr -d '\n' | gh secret set WOLFRAM_MATHPASS_B64 --repo WolframInstitute/GAPLink
```

The kernel knows a machine by its MathID. In a Linux container the MathID comes from the
machine-id and the host name, so CI fixes both. `.github/actions/wolfram-license` sets the
machine-id. The host name is the machine name at the start of the license line: the
`Wolfram license` job reads it with `scripts/license-machine-name.sh`, and the Wolfram job
starts its container under that name. Changing either changes the MathID, and the line then
needs a new password.

To get a license line for a new machine:

1. Leave the secret unset. The container is then named `gaplink-ci`.
2. Start CI with `gh workflow run ci.yml --ref main`. The step *Verify Wolfram Engine
   license* prints the machine name and the MathID of the container, also when no license
   works.
3. Have a password issued for that MathID and your activation key. Write the four parts to
   `.mathpass` and store the secret as above.

The same step prints the license type and its expiry in every run.

### Entitlement

Without a license line the job uses an on-demand entitlement. Create one that allows the
build's regular and parallel kernels:

```wl
entitlement = CreateLicenseEntitlement[
    <|
        "EntitlementExpiration" -> Quantity[1, "Years"],
        "LicenseExpiration" -> Quantity[1, "Hours"],
        "StandardKernelLimit" -> 32,
        "ParallelKernelLimit" -> 32
    |>
];

CopyToClipboard[entitlement["EntitlementID"]]
```

CI runs its Wolfram jobs one at a time, but the driver and its child kernels can
overlap. A one-kernel limit is insufficient for this build. Creating an entitlement
does not spend Service Credits; running kernels does. Add the entitlement ID to GitHub:

```bash
gh secret set WOLFRAMSCRIPT_ENTITLEMENTID --repo WolframInstitute/GAPLink
```

Paste only the entitlement ID when asked. Replace the secret when its entitlement expires.

If a job reports `network license limit reached` or `No valid password found`
before tests start, check the entitlement's validity and available kernel slots.
Changing these instructions does not change an existing entitlement or secret.
After correcting the secret, retry only the failed jobs:

```bash
gh run rerun <run-id> --failed --repo WolframInstitute/GAPLink
```

To use the same entitlement in more repositories:

```bash
gh secret set WOLFRAMSCRIPT_ENTITLEMENTID --org WolframInstitute --repos GAPLink
```

You need organization owner access. If GAPLink already has its own secret, delete it after
the organization secret is ready:

```bash
gh secret delete WOLFRAMSCRIPT_ENTITLEMENTID --repo WolframInstitute/GAPLink
```

CI tests startup with each supported GAP release line.

## Releases

Add the cloud account before the first release:

```bash
gh secret set WOLFRAM_CLOUD_USER --repo WolframInstitute/GAPLink
gh secret set WOLFRAM_CLOUD_PASSWORD --repo WolframInstitute/GAPLink
```

Publishing uses the same license secret as CI.

Before tagging a release:

1. Update the version in `GAPLink/PacletInfo.wl` and `CITATION.cff`.
2. Move the changelog entries into a version section.
3. Review the licenses for every included runtime file.
4. Run `make all`.
5. Push `main` and wait for all platform jobs.
6. Push an annotated `v<version>` tag on that commit.

```bash
git tag -a v0.4.1 -m "v0.4.1"
git push origin v0.4.1
```

The tag creates a GitHub release with the platform paclets, checksums, and GAP source
archives. PacletPage restores CI's verified build and publishes the resource and
documentation site without rebuilding. The platform downloads keep their existing URLs;
the generated install commands select the runtime for the user's system. Publishing checks
the documentation pages and public access to each archive and resource description.

GitHub can list a CI run late, so the release looks for it for about five minutes
(`scripts/find-ci-run.sh`). The cloud renders new pages late, so a failed check of the
site is tried again for up to ten minutes, and the error names each check that still fails.
To retry a failed release, rerun its failed jobs; do not move the tag. CI keeps its build
for seven days; once it has expired, rerun the CI run of the release commit first.
