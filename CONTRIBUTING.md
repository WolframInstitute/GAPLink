# Contributing

Keep changes focused, tested, and easy to review.

## Requirements

- Wolfram Language 15.0 or later
- `wolframscript` on `PATH`
- Git and `make`

No GAP installation is needed for foundation work. Once a transport exists, tests that require
GAP must remain separate from the load and foundation test suite.

## Repository layout

```text
.
├── GAPLink/                 paclet source
│   ├── Kernel/              Structured Package Format source
│   ├── Tests/               Wolfram Language tests
│   └── PacletInfo.wl        metadata and extension declarations
├── Scripts/                 local and CI commands
├── docs/                    architecture and decision records
└── .github/workflows/       continuous integration
```

## Architectural guardrails

- GAPLink is a low-level integration paclet and must not depend on PureMath.
- Loading the paclet must not start or install GAP, load native code, or access the network.
- Public calls must return Wolfram Language values, documented foreign handles, or stable
  `Failure` objects; raw process protocol details must not leak through the API.
- Do not add a GAP binary, GAP package, libgap linkage, or other third-party source before its
  license, provenance, update policy, and supported platforms are recorded in an accepted ADR.
- Transport-specific details must stay behind a transport-neutral internal boundary.
- Raw GAP evaluation, if added, must be explicit and separate from structured calls.

## Check your work

```bash
make check
make test
make all
```

To lint selected Wolfram Language files:

```bash
make lint FILES="GAPLink/Kernel/GAPLink.wl"
```

Build output is written under `build/` and is ignored by Git.

## Style

- Use UTF-8, LF line endings, and four-space indentation in Wolfram Language files.
- Use the Structured Package Format for package files.
- Keep public names transport-neutral and add a usage message, test, documentation, and
  changelog entry for every exported symbol.
- Leave unsupported input unevaluated when the operation does not engage; use `Failure` after a
  recognized operation has begun and cannot complete.
- Give every `VerificationTest` a stable, descriptive `TestID`.

## Git hooks and commits

Enable the optional repository hooks with:

```bash
make hooks
```

Commit subjects follow Conventional Commits:

```text
type(optional-scope): short description
```

Common types are `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `build`, `ci`, `chore`, and
`style`. Do not force-push or delete `main`.

## Continuous integration

CI uses Wolfram Engine 15.0 and runs the same `make` targets available locally. Configure the
repository secret `WOLFRAMSCRIPT_ENTITLEMENTID` with a Wolfram on-demand license entitlement.
Every pull request and push to `main` checks repository hygiene, validates and lints the paclet,
runs tests, builds an archive, verifies the archive in a fresh kernel, and uploads it as a
workflow artifact.

The workflow intentionally does not publish releases or install GAP. Those steps require the
distribution and transport decisions described in `docs/decisions/`.
