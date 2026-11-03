# GAP library coverage

GAPLink calls the functions provided by the active GAP session. It does not need
one Wolfram Language wrapper per mathematical operation. Use a global name,
a record path such as `"MTX.Dimension"`, or a function returned as a `GAPObject`.
Functions from additional packages become available after `LoadGAPPackage`.

## Checked on GAP 4.16.1

The recorded baseline below used the bundled macOS ARM64 runtime and matching
GAP sources, before the AtlasRep download example was excluded.

| Check | Result |
| --- | --- |
| Documented callable names | 4,315, including 63 functions in records |
| Other documented entries | 21 language constructs, values, or names absent from this GAP build |
| Upstream input blocks evaluated | 22,726 |
| Upstream test files matching their expected output | 334 |
| Files with the same differences in native GAP | 16 |
| Files not applicable to this GAP build | 11 |
| Files excluded from this harness | 9 |
| Differences attributable to GAPLink | 0 |

The availability check resolves names; it does not call every function with every
possible input. The upstream sweep runs GAP's `Test` function through `GAPCall`.
Separate bridge tests check conversion, retained functions, record paths, named
options, characters, fields, matrices, algebras, polynomials, groups, streams,
errors, and session ownership. They also exercise the bundled small, primitive,
transitive, and perfect group libraries.

The 16 differences also occur when the same tests run directly in GAP: 14 need
optional packages, and two print extra syntax warnings in this
harness. The 11 inapplicable files contain no active inputs on this build. The
nine exclusions cover external processes, workspace files, and interactive or
file-system tests; their names are recorded in the report. These are separate
from the bridge's own output, timeout, process-exit, and stream tests.

## Entries that are not callable functions

`Assert`, `Info`, `IsBound`, `TryNextMethod`, and `Unbind` are GAP language
constructs. Use them in `GAPEvaluate`. `NEW_TYPE_NEXT_ID`, `TYPE_BOOL`, and
`TYPE_OPERATION` are values rather than functions.

The following documented names are not bound in the tested GAP runtime:

- `DirectFactorsOfGroupKN`, `FpElmKBRWS`, `RankQGroup`, `ReducedByIsomorphism`, `TzUpdateGeneratorImage`
- `InputTextCustom`, `OutputTextCustom`, `IsInputCustomStream`, `IsInputTextCustomRep`, `IsOutputCustomStream`
- `IsInternallyMutable`, `ListDirectory`, `Print_Value`

Availability depends on the GAP version, build, and installed packages. GAPLink
reports a missing function when the active session does not provide it.

## Reproduce

Run the bridge tests:

```sh
GAPLINK_GAP=/path/to/gap make test-gap
```

Run the upstream sweep on macOS or Linux with a matching GAP source tree:

```sh
GAPLINK_GAP=/path/to/gap GAPLINK_SOURCE=/path/to/gap-source make sweep
```

The offline sweep excludes `example_4.4.18.tst`: it calls `AtlasGenerators`,
which can download data from AtlasRep, an optional package absent from the
bundled runtime. Core MeatAxe tests and GAPLink's tests for calling library
functions in records remain in the sweep and live bridge suite.

The sweep does not download or install packages. Each test file runs in a fresh
session with a 60-second limit. Files with differences are repeated in native
GAP with the same limit. Timeouts and native differences are reported separately
from passes. Timeouts and new bridge differences fail the command.

Reports in `build/coverage/` contain the full function inventory, per-file results,
excluded files, and both outputs for comparisons. CI keeps these reports as an
artifact and checks the bridge against GAP 4.14.0, 4.15.1, and 4.16.1. The full
upstream sweep uses 4.16.1. Other operating systems still require their CI/runtime
checks; the local results above do not establish native Windows or Intel macOS results.

The test format and comparison rules follow [GAP's testing documentation](https://gap-system.github.io/gap/doc/ref/chap7.html).
