# Contributing

## Requirements

- Wolfram Language 15.0 or later
- `wolframscript` on `PATH`
- Git and `make`
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

To build and test a release paclet for the current system:

```bash
make runtime
make bundle
make verify-bundle
```

Runtime builds also need a C/C++ compiler, `curl`, and `tar`. Paclet bundles need `zip`.

The official Windows `gap.bat` layout is supported. Native Windows still needs the live
session test before it is listed as verified.

To lint selected Wolfram Language files:

```bash
make lint FILES="GAPLink/Kernel/GAPLink.wl"
```

## Style

- Use UTF-8, LF line endings, and four spaces for Wolfram Language files.
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

CI uses Wolfram Engine 15.0. Create an entitlement that lasts long enough:

```wl
entitlement = CreateLicenseEntitlement[
    <|
        "EntitlementExpiration" -> Quantity[1, "Years"],
        "LicenseExpiration" -> Quantity[1, "Hours"],
        "StandardKernelLimit" -> 1
    |>
];

entitlement["EntitlementID"]
```

CI runs its Wolfram jobs one at a time, so a kernel limit of `1` is enough. This may use
Service Credits. Add the entitlement ID to GitHub:

```bash
gh secret set WOLFRAMSCRIPT_ENTITLEMENTID --repo WolframInstitute/GAPLink
```

Paste the value when asked. GitHub keeps it until the entitlement expires.

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

The existing `WOLFRAMSCRIPT_ENTITLEMENTID` secret is also used to publish.

Before tagging a release:

1. Update the version in `GAPLink/PacletInfo.wl` and `CITATION.cff`.
2. Move the changelog entries into a version section.
3. Review the licenses for every included runtime file.
4. Run `make all`.
5. Push `main` and wait for all platform jobs.
6. Push an annotated `v<version>` tag.

```bash
git tag -a v0.2.0 -m "v0.2.0"
git push origin v0.2.0
```

The tag creates a GitHub release with the platform paclets, checksums, and GAP source
archives. The platform paclets are then uploaded to Wolfram Cloud.
