# Design

GAPLink connects Wolfram Language to GAP. It can be used by PureMath or any other project.
It does not depend on those projects.

```text
Wolfram Language projects -> GAPLink -> GAP
```

The [private process protocol](protocol.md) defines the messages exchanged with GAP.

## Rules

- Loading GAPLink must not start or install GAP.
- Public functions must not depend on one way of running GAP.
- Convert simple GAP values to Wolfram Language values.
- Keep a reference to GAP objects that cannot be converted.
- Return a clear `Failure` when something goes wrong.
- Report the versions of GAP, GAPLink, and any GAP packages in use.
- Check whether optional GAP packages are installed.
- Record the source and license of outside code and files.

## Accepted choices

- [GAPLink is a separate, general project](decisions/0001-project-scope.md).
- [Release paclets include GAP](decisions/0013-managed-gap-runtime.md).
- [The first version runs GAP as a separate program](decisions/0003-backend.md).
- [The first public API uses explicit GAP sessions](decisions/0004-public-api.md).
- [Values are copied or kept in GAP](decisions/0005-value-conversion.md).
- [Uncertain process state stops the session](decisions/0006-errors-and-time-limits.md).
- [The first release targets recent GAP 4 releases on Linux, macOS, and Windows](decisions/0007-supported-versions-and-systems.md).
- [The process uses private framed messages and keeps GAP output separate](decisions/0008-process-protocol-and-output.md).
- [GAPLink checks and loads packages through GAP](decisions/0009-gap-packages.md).
- [Sessions report loaded package versions](decisions/0010-loaded-packages.md).
- [The Windows install uses its bundled Bash launcher](decisions/0011-windows-launcher.md).
- [Tags publish the paclet already verified by CI](decisions/0012-releases.md).
- [CI builds and reuses checked runtime archives](decisions/0014-runtime-builds.md).
- [CI uses one Wolfram kernel](decisions/0015-ci-license.md).

Record each choice in `docs/decisions/` before writing that part of the project.
