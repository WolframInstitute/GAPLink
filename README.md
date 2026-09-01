# GAPLink

[![CI](https://github.com/WolframInstitute/GAPLink/actions/workflows/ci.yml/badge.svg)](https://github.com/WolframInstitute/GAPLink/actions/workflows/ci.yml)
[![Publish](https://github.com/WolframInstitute/GAPLink/actions/workflows/publish.yml/badge.svg)](https://github.com/WolframInstitute/GAPLink/actions/workflows/publish.yml)

GAPLink connects Wolfram Language to [GAP](https://www.gap-system.org/).
It starts GAP, loads packages, calls functions, and runs GAP code. PureMath is one user,
but GAPLink works with any Wolfram Language project.

## Requirements

- Wolfram Language 15.0 or later
- Linux x86-64, macOS on Intel or Apple silicon, or Windows x86-64

Release paclets include GAP 4.16.1 and its required packages.

## Install

Install the latest release from Wolfram Cloud:

```wolfram
PacletInstall[
    "https://www.wolframcloud.com/obj/wolframinstitute/GAPLink/" <>
        "WolframInstitute__GAPLink-" <> $SystemID <> ".paclet"
];
Needs["WolframInstitute`GAPLink`"];
```

The paclet contains GAP. Starting a session does not download anything.

Stable `.paclet` files and checksums are also on
[GitHub Releases](https://github.com/WolframInstitute/GAPLink/releases).

## Quick test

Start a fresh kernel after installation:

```wolfram
Needs["WolframInstitute`GAPLink`"];

session = StartGAPSession[];

session["Version"]
GAPCall[session, "Sum", Range[10]]
GAPEvaluate[session, "Size(SymmetricGroup(4));"]
GAPPackageAvailableQ[session, "gapdoc"]

DeleteObject[session];
```

The results should be `"4.16.1"`, `55`, `24`, and `True`.

## Packages

```wolfram
session = StartGAPSession[];

LoadGAPPackage[session, "gapdoc"]
session["LoadedPackages"]

DeleteObject[session];
```

`LoadGAPPackage` loads a package from the active GAP runtime. It does not download
packages.

## GAP objects

```wolfram
session = StartGAPSession[];
group = GAPCall[session, "SymmetricGroup", 4];

GAPCall[session, "Size", group]

DeleteObject /@ {group, session};
```

The result is `24`. Values that cannot be copied stay in GAP as `GAPObject` values.

## Use another GAP

An explicit path takes priority over the GAP included in the paclet:

```wolfram
session = StartGAPSession["Executable" -> "/path/to/gap"];
```

## Load from source

Source checkouts need a separate GAP installation:

```wolfram
PacletDirectoryLoad["/path/to/GAPLink/GAPLink"];
Needs["WolframInstitute`GAPLink`"];

session = StartGAPSession["Executable" -> "/path/to/gap"];
```

## Development

Development needs `wolframscript`, Git, `make`, and GAP 4.14–4.16.

```bash
make all
make test-gap
```

Set the GAP path when needed:

```bash
GAPLINK_GAP=/path/to/gap make test-gap
```

Build and test a platform paclet:

```bash
make runtime
make bundle
make verify-bundle
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow and
[docs/architecture.md](docs/architecture.md) for the main design rules.

## License

GAPLink code uses the [MIT License](LICENSE). Release paclets also contain GAP, GMP, and
GAP packages under their own licenses. Their license files are included with the runtime.
