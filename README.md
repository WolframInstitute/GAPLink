# GAPLink

[![CI](https://github.com/WolframInstitute/GAPLink/actions/workflows/ci.yml/badge.svg)](https://github.com/WolframInstitute/GAPLink/actions/workflows/ci.yml)

GAPLink connects Wolfram Language to [GAP](https://www.gap-system.org/).
PureMath is one possible user, but GAPLink is designed for any Wolfram Language project.

The project currently contains a loadable paclet and CI. It does not call or bundle GAP yet.

## Requirements

- Wolfram Language 15.0 or later
- `wolframscript`, Git, and `make` for development

## Load from source

```wolfram
PacletDirectoryLoad["/path/to/GAPLink/GAPLink"]
Needs["WolframInstitute`GAPLink`"]
```

There are no public functions yet.

## Development

```bash
make check   # metadata, source lint, and source load
make test    # Wolfram Language tests
make build   # build the paclet archive
make verify  # load the built archive
make all     # all of the above
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow and
[docs/architecture.md](docs/architecture.md) for the main design rules.

## License

GAPLink uses the [MIT License](LICENSE). GAP is separate and uses the GPL.
