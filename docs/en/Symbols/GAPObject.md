---
Template: Symbol
Name: GAPObject
Context: WolframInstitute`GAPLink`
Paclet: WolframInstitute/GAPLink
URI: WolframInstitute/GAPLink/ref/GAPObject
Keywords: [GAP, GAP values]
SeeAlso: [GAPCall, GAPEvaluate, GAPSession]
RelatedGuides: [GAPLink]
---

## Usage

`GAPObject[...]` represents a value kept in a GAP session.

## Details & Options

- `GAPCall` and `GAPEvaluate` create these objects. Pass them back only to their
  owning session. Objects may also appear inside lists and associations.
- A function kept as a `GAPObject` can be the target of `GAPCall`.
- `Normal[object]` copies supported values. It returns `Failure` if conversion
  would lose information or exceed the copying limits.
- Characters keep their character table. Sparse or cyclic containers, containers
  with more than 10,000 entries in total or 32 nested levels, and permutations
  moving points above 10,000 stay in GAP. Use GAP operations to extract smaller results.
- Use `"ReturnType" -> "Object"` to preserve a complete result and its identity.
- `DeleteObject[object]` releases the reference. Closing its session invalidates
  every object belonging to it.

## Basic Examples

Work with a finite field without converting its elements:

```wl
WithCleanup[
 session = StartGAPSession[],
 field = GAPCall[session, "GF", 16];
 {GAPCall[session, "Size", field], GAPCall[session, "Characteristic", field]},
 DeleteObject[session]
]
```

Copy a retained list when it is needed in Wolfram Language:

```wl
WithCleanup[
 session = StartGAPSession[],
 values = GAPCall[session, "FactorsInt", 360, "ReturnType" -> "Object"];
 Normal[values],
 DeleteObject[session]
]
```
