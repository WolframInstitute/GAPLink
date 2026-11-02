# GAPLink

[![CI](https://github.com/WolframInstitute/GAPLink/actions/workflows/ci.yml/badge.svg)](https://github.com/WolframInstitute/GAPLink/actions/workflows/ci.yml)
[![Release](https://github.com/WolframInstitute/GAPLink/actions/workflows/release.yml/badge.svg)](https://github.com/WolframInstitute/GAPLink/actions/workflows/release.yml)

GAPLink connects Wolfram Language to [GAP](https://www.gap-system.org/).
Use GAP's groups, characters, finite fields, and packages from a Wolfram Language session.

[Documentation](https://www.wolframcloud.com/obj/wolframinstitute/GAPLink/Documentation)
· [Paclet resource](https://www.wolframcloud.com/obj/wolframinstitute/DeployedResources/Paclet/WolframInstitute/GAPLink/index.html)
· [Releases](https://github.com/WolframInstitute/GAPLink/releases)

## Install

GAPLink requires Wolfram Language 15.0 or later on Linux x86-64, macOS (Intel or
Apple silicon), or Windows x86-64. Release paclets include GAP and its required
packages; a separate GAP installation is not needed.

Install the latest release for your system:

```wolfram
PacletInstall[
    ResourceObject[
        "https://www.wolframcloud.com/obj/wolframinstitute/DeployedResources/Paclet/WolframInstitute/GAPLink"
    ]["PacletFile"],
    ForceVersionInstall -> True,
    "ShowProgress" -> True
];
```

The resource selects your platform automatically. The command shows download progress and
allows reinstalling the same version. Versioned `.paclet` files and checksums are also on
[GitHub Releases](https://github.com/WolframInstitute/GAPLink/releases).

## Quick start

Load GAPLink, start GAP, and count the permutations of five objects:

```wolfram
Needs["WolframInstitute`GAPLink`"];
session = StartGAPSession[];
group = GAPCall[session, "SymmetricGroup", 5];
GAPCall[session, "Size", group]
```

```wolfram
120
```

Keep this session open for the examples below. Loading GAPLink alone does not start GAP.

## Examples

### Characters

Find the dimensions of the irreducible representations of the group above:

```wolfram
characters = GAPCall[session, "Irr", group];
Sort[GAPCall[session, "DegreeOfCharacter", #] & /@ characters]
```

```wolfram
{1, 1, 4, 4, 5, 5, 6}
```

### Matrices over a finite field

Count the invertible 2-by-2 matrices over the field with three elements:

```wolfram
matrices = GAPEvaluate[session, "GL(2,3);"];
GAPCall[session, "Size", matrices]
```

```wolfram
48
```

### GAP functions as values

Use a function returned by GAP:

```wolfram
square = GAPEvaluate[session, "x -> x^2;"];
GAPCall[session, "List", {1, 2, 3, 4}, square]
```

```wolfram
{1, 4, 9, 16}
```

### Close the session

Close GAP when finished:

```wolfram
DeleteObject[session];
```

## Functions and values

| Function | Purpose |
| --- | --- |
| `StartGAPSession` | Start GAP and return a `GAPSession`. |
| `GAPCall` | Call a GAP function with Wolfram Language arguments. |
| `GAPEvaluate` | Evaluate complete GAP source code. |
| `GAPPackageAvailableQ` | Check whether a package is installed. |
| `LoadGAPPackage` | Load an installed package. |

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
Load a source checkout before evaluating the quick start:

```wolfram
PacletDirectoryLoad["/path/to/GAPLink/GAPLink"];
```

Source checkouts need a separate GAP installation. Check the source, run tests,
and build the documentation and paclet with:

```bash
GAPLINK_GAP=/path/to/gap make all test-gap
```

`make all` fetches pinned PacletPage tools and evaluates the documentation examples.
See [CONTRIBUTING.md](CONTRIBUTING.md) for platform builds and releases, and
[docs/architecture.md](docs/architecture.md) for the main design rules.

## License

GAPLink code uses the [MIT License](LICENSE). Release paclets also contain GAP, GMP, and
GAP packages under their own licenses. Their license files are included with the runtime.
Matching GAP source archives are available with each GitHub release.
