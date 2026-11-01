---
Template: Symbol
Name: GAPCall
Context: WolframInstitute`GAPLink`
Paclet: WolframInstitute/GAPLink
URI: WolframInstitute/GAPLink/ref/GAPCall
Keywords: [GAP, GAP functions]
SeeAlso: [StartGAPSession, GAPEvaluate, GAPObject]
RelatedGuides: [GAPLink]
---

## Usage

`GAPCall[session, name, args]` calls a GAP function by its global name or record path.

`GAPCall[session, function, args]` calls a GAP function held in a `GAPObject`.

## Details & Options

- Record paths such as `"MTX.Dimension"` select a function inside a GAP record.
  Names are looked up as data, never evaluated as GAP code.
- Arguments can include integers, rationals, machine real numbers, booleans,
  strings, byte arrays, permutations, lists, string-keyed associations, and
  `GAPObject` values from the same session. `Missing["GAPFail"]` represents GAP's `fail`.
- Permutations sent as `Cycles` can move points up to 10,000. Create larger
  permutations in GAP with `GAPEvaluate` and pass their `GAPObject` values.
- Values that cannot be copied remain in GAP as `GAPObject` values. This includes
  groups, fields, polynomials, functions, and characters.
- `"GAPOptions" -> <||>` supplies GAP's named options as a string-keyed association.
  Use `True` for a flag. These options apply only during this call.
- `"ReturnType" -> "Automatic"` copies supported results. `"Object"` keeps the
  complete result in GAP, including mutable lists or records.
- `"Output" -> "Print"` forwards printed text. `"Capture"` returns an association
  with `"Result"`, `"StandardOutput"`, and `"StandardError"`. `"Discard"` omits text.
- `TimeConstraint -> Infinity` allows any running time. A positive number limits
  the call in seconds. A timeout closes the session and invalidates its objects.
- A GAP error returns `Failure`; a function with no return value returns `Null`.

## Basic Examples

Find the order of a group and the orders of its generators:

```wl
WithCleanup[
 session = StartGAPSession[],
 group = GAPCall[session, "SymmetricGroup", 5];
 {GAPCall[session, "Size", group],
  GAPCall[session, "Order", #] & /@ GAPCall[session, "GeneratorsOfGroup", group]},
 DeleteObject[session]
]
```

## Scope

Use a GAP function as an argument and as the function to call:

```wl
WithCleanup[
 session = StartGAPSession[],
 square = GAPEvaluate[session, "x -> x^2;"];
 {GAPCall[session, square, 12], GAPCall[session, "List", {1, 2, 3}, square]},
 DeleteObject[session]
]
```

Pass a named GAP option:

```wl
WithCleanup[
 session = StartGAPSession[],
 function = GAPEvaluate[session, "function(x) return x * ValueOption(\"scale\"); end;"];
 GAPCall[session, function, 7, "GAPOptions" -> <|"scale" -> 3|>],
 DeleteObject[session]
]
```

Keep characters in GAP and copy their dimensions:

```wl
WithCleanup[
 session = StartGAPSession[],
 characters = GAPCall[session, "Irr", GAPCall[session, "SymmetricGroup", 4]];
 Sort[GAPCall[session, "DegreeOfCharacter", #] & /@ characters],
 DeleteObject[session]
]
```

Call a matrix-module function stored in GAP's `MTX` record:

```wl
WithCleanup[
 session = StartGAPSession[],
 module = GAPEvaluate[session, "GModuleByMats([IdentityMat(2,GF(3))],GF(3));",
  "ReturnType" -> "Object"];
 GAPCall[session, "MTX.Dimension", module],
 DeleteObject[session]
]
```
