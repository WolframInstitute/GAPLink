# Architecture

GAPLink provides a general Wolfram Language interface to GAP. Other projects may use GAPLink,
but GAPLink must not depend on them.

```text
Wolfram Language projects -> GAPLink -> GAP
```

## Rules

- Loading GAPLink must not start or install GAP.
- The public API must work with any supported backend.
- Convert common values to Wolfram Language. Use handles for other GAP objects.
- Return clear `Failure` objects for backend errors.
- Report GAP, GAPLink, package, backend, and platform versions.
- Detect optional GAP packages instead of assuming they are installed.
- Record the source and license of third-party code and binaries.

## Open decisions

- backend: process, libgap, or both
- GAP discovery and installation
- supported GAP versions, packages, and platforms
- value conversion and object handles
- whether releases bundle GAP

Record these decisions in `docs/decisions/` before implementation.
