---
Template: Symbol
Name: GAPEvaluate
Context: WolframInstitute`GAPLink`
Paclet: WolframInstitute/GAPLink
URI: WolframInstitute/GAPLink/ref/GAPEvaluate
Keywords: [GAP, GAP source code]
SeeAlso: [StartGAPSession, GAPCall, GAPObject]
RelatedGuides: [GAPLink]
---

## Usage

`GAPEvaluate[session, code]` evaluates GAP source code in a session.

## Details & Options

- End each command with `;` or `;;`. The last command that produces a value
  supplies the result. Definitions remain available in later calls.
- GAP code has the same access to files and external programs as GAP itself.
- `"Output" -> "Print"`, `"ReturnType" -> "Automatic"`, and
  `TimeConstraint -> Infinity` have the same meanings as for `GAPCall`.
- Unsupported results remain in GAP as `GAPObject` values. Errors return `Failure`.

## Basic Examples

Build a matrix group over a finite field, then calculate its order:

```wl
WithCleanup[
 session = StartGAPSession[],
 group = GAPEvaluate[session, "GL(2,3);"];
 GAPCall[session, "Size", group],
 DeleteObject[session]
]
```

Factor a polynomial and keep its factors available for further calculations:

```wl
WithCleanup[
 session = StartGAPSession[],
 factors = GAPEvaluate[session, "Factors(Indeterminate(Rationals)^4-1);"];
 GAPCall[session, "DegreeOfLaurentPolynomial", #] & /@ factors,
 DeleteObject[session]
]
```
