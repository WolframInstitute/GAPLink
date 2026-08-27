# Contributing

## Requirements

- Wolfram Language 15.0 or later
- `wolframscript` on `PATH`
- Git and `make`

GAP is not needed for the current tests.

## Project rules

- GAPLink must not depend on projects that use it.
- Loading the paclet must not start or install GAP.
- Keep backend details out of the public API.
- Review licenses before adding GAP code, packages, or binaries.
- Keep tests that need GAP separate from tests that only load the paclet.

## Development

```bash
make check
make test
make all
```

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

CI runs `make all` with Wolfram Engine 15.0. Add `WOLFRAMSCRIPT_ENTITLEMENTID` as a repository
secret. CI does not install GAP or publish releases.
