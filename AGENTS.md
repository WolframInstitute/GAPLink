# GAPLink repository guidance

These instructions apply to the entire repository.

## Scope

GAPLink is the low-level Wolfram Language integration layer for GAP. It must remain independent
of PureMath and other domain paclets. Domain-specific mathematical APIs belong downstream.

## Required workflow

1. Read `docs/architecture.md` and the accepted records under `docs/decisions/` before changing
   transport, packaging, native code, serialization, or licensing behavior.
2. Keep paclet loading side-effect free.
3. Add or update tests for every behavior change.
4. Run `make all` before handing off a change.
5. Update `CHANGELOG.md` for user-visible changes.

## Guardrails

- Do not vendor or download GAP, libgap, GAP packages, or other binaries without an accepted ADR.
- Do not add a hard dependency on PureMath.
- Do not expose transport-specific implementation details through public symbols.
- Do not introduce a raw-evaluation path without explicit naming, documentation, and security
  tests.
- Keep tests requiring an external GAP runtime distinguishable from foundation tests so the
  paclet can always be checked without GAP installed.
