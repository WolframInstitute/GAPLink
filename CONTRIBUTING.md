# Contributing

## Requirements

- Wolfram Language 15.0 or later
- `wolframscript` on `PATH`
- Git and `make`
- GAP 4.14–4.16 for the startup test

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

The Windows `gap.bat` launcher is not supported yet.

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

CI tests startup with GAP 4.14.0, 4.15.1, and 4.16.1. It does not publish releases.
