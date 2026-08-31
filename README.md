# GAPLink

[![CI](https://github.com/WolframInstitute/GAPLink/actions/workflows/ci.yml/badge.svg)](https://github.com/WolframInstitute/GAPLink/actions/workflows/ci.yml)

GAPLink connects Wolfram Language to [GAP](https://www.gap-system.org/).
PureMath is one possible user, but GAPLink is designed for any Wolfram Language project.

The project can start GAP and check the connection.

## Requirements

- Wolfram Language 15.0 or later
- `wolframscript`, Git, and `make` for development
- GAP 4.14–4.16 for the live test

## Load from source

```wolfram
PacletDirectoryLoad["/path/to/GAPLink/GAPLink"]
Needs["WolframInstitute`GAPLink`"]
```

There are no public functions yet.

## Live test

Install GAP and put `gap` on `PATH`, then run:

```bash
make test-gap
```

This starts a real GAP process and checks its version and connection. It does not run GAP
calculations yet. To set the executable path:

```bash
GAPLINK_GAP=/path/to/gap make test-gap
```

## Development

```bash
make check   # metadata, source lint, and source load
make test    # Wolfram Language tests
make test-gap # startup test with installed GAP
make build   # build the paclet archive
make verify  # load the built archive
make all     # full check without GAP
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow and
[docs/architecture.md](docs/architecture.md) for the main design rules.

## License

GAPLink uses the [MIT License](LICENSE). GAP is separate and uses the GPL.
