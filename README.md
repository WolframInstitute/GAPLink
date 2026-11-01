# GAPLink

[![CI](https://github.com/WolframInstitute/GAPLink/actions/workflows/ci.yml/badge.svg)](https://github.com/WolframInstitute/GAPLink/actions/workflows/ci.yml)
[![Release](https://github.com/WolframInstitute/GAPLink/actions/workflows/release.yml/badge.svg)](https://github.com/WolframInstitute/GAPLink/actions/workflows/release.yml)

GAPLink connects Wolfram Language to [GAP](https://www.gap-system.org/).
It starts GAP, loads packages, calls functions, and runs GAP code. PureMath is one user,
but GAPLink works with any Wolfram Language project.

## Requirements

- Wolfram Language 15.0 or later
- Linux x86-64, macOS on Intel or Apple silicon, or Windows x86-64

Release paclets include a tested GAP runtime and its required packages.

## Install

Install the latest release from Wolfram Cloud:

```wolfram
PacletInstall[
    ResourceObject[
        "https://www.wolframcloud.com/obj/wolframinstitute/GAPLink/" <>
            "WolframInstitute__GAPLink-" <> $SystemID <> ".paclet"
    ]["PacletFile"],
    ForceVersionInstall -> True,
    "ShowProgress" -> True
];
```

`$SystemID` is evaluated on your computer and selects its platform archive.
`ForceVersionInstall -> True` allows reinstalling the same version.
Installing the resource's `"PacletFile"` with `"ShowProgress" -> True` shows download progress.

`ResourceObject` support starts with the `0.2.2` cloud release. For earlier releases,
pass the URL directly to `PacletInstall`.

Stable `.paclet` files and checksums are also on
[GitHub Releases](https://github.com/WolframInstitute/GAPLink/releases).

See the [documentation](https://www.wolframcloud.com/obj/wolframinstitute/GAPLink/Documentation)
and [paclet resource page](https://www.wolframcloud.com/obj/wolframinstitute/DeployedResources/Paclet/WolframInstitute/GAPLink/index.html)
for more examples.

## Load from source

```wolfram
PacletDirectoryLoad["/path/to/GAPLink/GAPLink"];
```

Source checkouts need a separate GAP installation.

## Examples

Load GAPLink and start a session:

```wolfram
Needs["WolframInstitute`GAPLink`"];
session = StartGAPSession[];
```

Count the permutations of five objects:

```wolfram
group = GAPCall[session, "SymmetricGroup", 5];
GAPCall[session, "Size", group]
```

```wolfram
120
```

Find the dimensions of the irreducible representations of that group:

```wolfram
characters = GAPCall[session, "Irr", group];
Sort[GAPCall[session, "DegreeOfCharacter", #] & /@ characters]
```

```wolfram
{1, 1, 4, 4, 5, 5, 6}
```

Count the invertible 2-by-2 matrices over the field with three elements:

```wolfram
matrices = GAPEvaluate[session, "GL(2,3);"];
GAPCall[session, "Size", matrices]
```

```wolfram
48
```

Use a function returned by GAP:

```wolfram
square = GAPEvaluate[session, "x -> x^2;"];
GAPCall[session, "List", {1, 2, 3, 4}, square]
```

```wolfram
{1, 4, 9, 16}
```

Close the session when finished:

```wolfram
DeleteObject[session];
```

## Functions and values

`GAPCall` accepts GAP function names, record paths such as `"MTX.Dimension"`,
and functions held in a `GAPObject`. Use `"GAPOptions" -> <|"name" -> value|>`
for GAP's named options. `GAPEvaluate` accepts complete GAP source code.

Groups, characters, finite fields, and other values that cannot be copied remain
in GAP as `GAPObject` values. Pass them to further calls in the same session.
Use `"ReturnType" -> "Object"` to retain a complete result, and `Normal[object]`
to copy a supported value. Large, cyclic, or sparse containers stay in GAP.

`LoadGAPPackage` makes an installed package's functions available through the
same interface. It does not download packages. The [coverage report](docs/coverage.md)
describes what is checked and what requires a separate package or interactive GAP.

## Use another GAP

An explicit path takes priority over the GAP included in the paclet:

```wolfram
session = StartGAPSession["Executable" -> "/path/to/gap"];
```

## Development

Development needs `wolframscript`, Git, `make`, Python 3, and GAP 4.14–4.16.
`make all` fetches pinned PacletPage tools, checks the source, runs offline tests,
and builds documentation and the archive. GAP is needed for the documentation examples.

```bash
make all
make test-gap
```

Set the GAP path when needed:

```bash
GAPLINK_GAP=/path/to/gap make all test-gap
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
