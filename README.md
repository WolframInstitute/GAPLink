# GAPLink

[![CI](https://github.com/WolframInstitute/GAPLink/actions/workflows/ci.yml/badge.svg)](https://github.com/WolframInstitute/GAPLink/actions/workflows/ci.yml)
[![Publish](https://github.com/WolframInstitute/GAPLink/actions/workflows/publish.yml/badge.svg)](https://github.com/WolframInstitute/GAPLink/actions/workflows/publish.yml)

GAPLink connects Wolfram Language to [GAP](https://www.gap-system.org/).
PureMath is one possible user, but GAPLink is designed for any Wolfram Language project.

The project can start GAP, load packages, call functions, and run GAP code.

## Requirements

- Wolfram Language 15.0 or later
- `wolframscript`, Git, and `make` for development
- GAP 4.14–4.16 to start a session

## Install

Install the latest tagged release:

```wolfram
PacletInstall["https://www.wolframcloud.com/obj/wolframinstitute/GAPLink/WolframInstitute__GAPLink.paclet"];
Needs["WolframInstitute`GAPLink`"];
```

Stable `.paclet` files and checksums are also on
[GitHub Releases](https://github.com/WolframInstitute/GAPLink/releases).

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
GAPPackageAvailableQ[session, "example"]
LoadGAPPackage[session, "example"]
session["LoadedPackages"]
GAPCall[session, "Sum", {1, 2, 3}]
GAPEvaluate[session, "Size(SymmetricGroup(4));"]
DeleteObject[session]
```

`session["Packages"]` lists packages GAP found at startup.
`session["LoadedPackages"]` reports the package versions in use.

To choose the GAP program:

```wolfram
StartGAPSession["Executable" -> "/path/to/gap"]
```

## Test in a notebook

Start a fresh kernel. Run each block in a new cell.

```wolfram
PacletDirectoryLoad["/path/to/GAPLink/GAPLink"];
Needs["WolframInstitute`GAPLink`"];
```

```wolfram
session = StartGAPSession[]
session["Status"]
session["Version"]
```

```wolfram
GAPCall[session, "Sum", Range[10]]
GAPCall[session, "IdFunc", {2/3, True, "hello"}]
```

The results should be `55` and `{2/3, True, "hello"}`.

```wolfram
GAPPackageAvailableQ[session, "example"]
package = LoadGAPPackage[session, "example"]
GAPCall[session, "IsPackageLoaded", "example"]
session["LoadedPackages"]
```

The first and third results should be `True`. `package` contains the requested package
version. `session["LoadedPackages"]` contains all loaded package versions, including
dependencies. GAPLink loads packages already available to GAP. It does not install them.

```wolfram
GAPEvaluate[session, "1 + 2;"]
GAPEvaluate[
  session,
  "GAPLinkNotebookValue := 4;;\nGAPLinkNotebookValue ^ 2;"
]
```

The results should be `3` and `16`. GAP commands must end with `;` or `;;`.
`GAPEvaluate` is not a sandbox. Run code you trust.

```wolfram
group = GAPEvaluate[session, "SymmetricGroup(4);"]
GAPCall[session, "Size", group]

value = GAPCall[
  session,
  "IdFunc",
  42,
  "ReturnType" -> "Object"
]
Normal[value]
DeleteObject[value]
```

The group stays in GAP. The size and copied value should be `24` and `42`.

```wolfram
GAPCall[session, "Print", "hello", "Output" -> "Capture"]
GAPEvaluate[
  session,
  "Unbind(GAPLinkNotebookValue);",
  "Output" -> "Discard"
]
DeleteObject[group]
DeleteObject[session]
session["Status"]
```

The last status should be `"Closed"`.

## Test from a shell

Install GAP and put `gap` on `PATH`, then run:

```bash
make test-gap
```

This tests sessions, calls, packages, and failures. To set the executable path:

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
