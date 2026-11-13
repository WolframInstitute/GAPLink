# GAPLink

[![CI](https://github.com/WolframInstitute/GAPLink/actions/workflows/ci.yml/badge.svg)](https://github.com/WolframInstitute/GAPLink/actions/workflows/ci.yml)
[![Release](https://github.com/WolframInstitute/GAPLink/actions/workflows/release.yml/badge.svg)](https://github.com/WolframInstitute/GAPLink/actions/workflows/release.yml)

GAPLink connects Wolfram Language to [GAP](https://www.gap-system.org/), a system for
computational discrete algebra. Use GAP's groups, characters, finite fields and packages
from a Wolfram Language session.

## Install

GAPLink needs Wolfram Language 15.0 or later on Linux x86-64, macOS (Intel or Apple
silicon) or Windows x86-64. The release paclets include GAP, so you do not need to
install GAP yourself.

```wolfram
PacletInstall[
    ResourceObject[
        "https://www.wolframcloud.com/obj/wolframinstitute/DeployedResources/Paclet/WolframInstitute/GAPLink"
    ]["PacletFile"],
    ForceVersionInstall -> True,
    "ShowProgress" -> True
];
```

## Quick start

Start GAP, count the permutations of five objects, and close GAP:

```wolfram
Needs["WolframInstitute`GAPLink`"];
session = StartGAPSession[];
group = GAPCall[session, "SymmetricGroup", 5];
GAPCall[session, "Size", group]
```

```wolfram
120
```

```wolfram
DeleteObject[session];
```

## Documentation

- [Documentation site](https://www.wolframcloud.com/obj/wolframinstitute/GAPLink/Documentation):
  the guide and every function, with examples.
- [Paclet page](https://www.wolframcloud.com/obj/wolframinstitute/DeployedResources/Paclet/WolframInstitute/GAPLink/index.html):
  the published resource.
- [Releases](https://github.com/WolframInstitute/GAPLink/releases): the `.paclet` files
  of each version, with checksums and the matching GAP sources.
  [CHANGELOG.md](CHANGELOG.md) lists the changes.
- [Coverage](docs/coverage.md): how much of GAP's library is checked.

## Develop

`make help` lists the commands. `make all` checks the source, runs the tests and builds
the paclet.

| Read | For |
| --- | --- |
| [CONTRIBUTING.md](CONTRIBUTING.md) | requirements, loading a checkout, tests, platform builds and releases |
| [docs/architecture.md](docs/architecture.md) | the design rules and the decisions behind them |
| [docs/coding-guides/README.md](docs/coding-guides/README.md) | the Wolfram Language coding guides and the style check |
| [AGENTS.md](AGENTS.md) | instructions for coding agents |

## License

GAPLink is free software under the [GNU General Public License](LICENSE), version 2 or
any later version, as GAP is. See [COPYRIGHT](COPYRIGHT). Release paclets also contain
GAP, GMP and GAP packages under their own licenses.
