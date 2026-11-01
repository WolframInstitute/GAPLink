---
Template: Symbol
Name: StartGAPSession
Context: WolframInstitute`GAPLink`
Paclet: WolframInstitute/GAPLink
URI: WolframInstitute/GAPLink/ref/StartGAPSession
Keywords: [GAP, Start GAP]
SeeAlso: [GAPSession, GAPCall, GAPEvaluate]
RelatedGuides: [GAPLink]
---

## Usage

`StartGAPSession[]` starts GAP and returns a `GAPSession`.

## Details & Options

- Release paclets include GAP. A source checkout needs a built or installed GAP.
- `"Executable" -> Automatic` uses bundled GAP, then searches `PATH` and common
  installation locations. Set it to a path to select another GAP installation.
- `TimeConstraint -> 30` limits startup in seconds.
- Startup problems return `Failure`. Nothing is downloaded or installed.
- Close a session with `DeleteObject[session]` when finished.

## Basic Examples

Start GAP, calculate an integer factorization, and close the session:

```wl
WithCleanup[
 session = StartGAPSession[],
 GAPCall[session, "FactorsInt", 1234567890],
 DeleteObject[session]
]
```
