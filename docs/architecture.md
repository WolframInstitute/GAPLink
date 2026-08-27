# Design

GAPLink connects Wolfram Language to GAP. It can be used by PureMath or any other project.
It does not depend on those projects.

```text
Wolfram Language projects -> GAPLink -> GAP
```

## Rules

- Loading GAPLink must not start or install GAP.
- Public functions must not depend on one way of running GAP.
- Convert simple GAP values to Wolfram Language values.
- Keep a reference to GAP objects that cannot be converted.
- Return a clear `Failure` when something goes wrong.
- Report the versions of GAP, GAPLink, and any GAP packages in use.
- Check whether optional GAP packages are installed.
- Record the source and license of outside code and files.

## Accepted choices

- [GAPLink is a separate, general project](decisions/0001-project-scope.md).
- [Users install GAP](decisions/0002-gap-installation.md).
- [The first version runs GAP as a separate program](decisions/0003-backend.md).
- [The first public API uses explicit GAP sessions](decisions/0004-public-api.md).

## Still to decide

- which versions and systems we support
- how GAP and Wolfram Language values are matched
- how errors and time limits work
- whether a future release includes GAP

Record each choice in `docs/decisions/` before writing that part of the project.
