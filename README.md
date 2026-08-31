# GAPLink

[![CI](https://github.com/WolframInstitute/GAPLink/actions/workflows/ci.yml/badge.svg)](https://github.com/WolframInstitute/GAPLink/actions/workflows/ci.yml)

GAPLink connects Wolfram Language to [GAP](https://www.gap-system.org/).
PureMath is one possible user, but GAPLink is designed for any Wolfram Language project.

The project can start and stop a GAP session.

## Requirements

- Wolfram Language 15.0 or later
- `wolframscript`, Git, and `make` for development
- GAP 4.14–4.16 to start a session

## Load from source

```wolfram
PacletDirectoryLoad["/path/to/GAPLink/GAPLink"]
Needs["WolframInstitute`GAPLink`"]
```

## Use

```wolfram
session = StartGAPSession[]
session["Version"]
session["Packages"]
DeleteObject[session]
```

To choose the GAP program:

```wolfram
StartGAPSession["Executable" -> "/path/to/gap"]
```

## Live test

Install GAP and put `gap` on `PATH`, then run:

```bash
make test-gap
```

This starts and closes a real GAP session. It does not run GAP calculations yet. To set the
executable path:

```bash
GAPLINK_GAP=/path/to/gap make test-gap
```

## Development

```bash
make check   # metadata, source lint, and source load
make test    # Wolfram Language tests
make test-gap # live session test with installed GAP
make build   # build the paclet archive
make verify  # load the built archive
make all     # full check without GAP
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow and
[docs/architecture.md](docs/architecture.md) for the main design rules.

## License

GAPLink uses the [MIT License](LICENSE). GAP is separate and uses the GPL.
