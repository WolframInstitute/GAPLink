# GAPLink

[![CI](https://github.com/WolframInstitute/GAPLink/actions/workflows/ci.yml/badge.svg)](https://github.com/WolframInstitute/GAPLink/actions/workflows/ci.yml)

GAPLink is a Wolfram Language paclet for low-level interoperability with
[GAP](https://www.gap-system.org/), the system for computational discrete algebra.

> [!IMPORTANT]
> This repository currently contains the paclet and continuous-integration foundation only.
> It does not start GAP, evaluate GAP code, bundle GAP, or expose a public API yet.

## Design boundary

GAPLink will own sessions, value conversion, foreign-object lifetime, and transport errors.
Domain paclets such as PureMath will own mathematical names, objects, and semantics.

```text
PureMath and other domain paclets
              |
              v
           GAPLink
              |
              v
       GAP and GAP packages
```

Loading GAPLink must remain side-effect free: it must not install software, start a process,
load a native library, or access the network. External work will begin only after an explicit
API call.

The initial architecture constraints and deferred decisions are recorded in
[docs/architecture.md](docs/architecture.md) and [docs/decisions](docs/decisions).

## Requirements

- Wolfram Language 15.0 or later
- `wolframscript`, Git, and `make` for development

GAP is intentionally not required by the foundation tests. Supported GAP versions and
installation models will be decided before the first transport implementation.

## Load from source

```wolfram
PacletDirectoryLoad["/path/to/GAPLink/GAPLink"]
Needs["WolframInstitute`GAPLink`"]
```

The context currently exports no symbols. A successful load verifies only that the paclet
foundation is intact.

## Development

```bash
make check   # metadata, source lint, and source load
make test    # Wolfram Language tests
make build   # build/GAPLink archive
make verify  # load and inspect the built archive
make all     # all of the above
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for repository conventions and CI setup.

## License

The GAPLink foundation is available under the [MIT License](LICENSE). GAP is a separate
GPL-licensed project and is not included here. Any future vendoring, native linkage, or package
distribution must first receive a recorded licensing decision and update
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
