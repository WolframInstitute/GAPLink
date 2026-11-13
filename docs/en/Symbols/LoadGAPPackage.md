---
Template: Symbol
Name: LoadGAPPackage
Context: WolframInstitute`GAPLink`
Paclet: WolframInstitute/GAPLink
URI: WolframInstitute/GAPLink/ref/LoadGAPPackage
Keywords: [GAP, GAP packages]
SeeAlso: [GAPPackageAvailableQ, GAPCall, GAPSession]
RelatedGuides: [GAPLink]
---

## Usage

`LoadGAPPackage[session, name]` loads a GAP package and returns its name and version.

## Details & Options

- The package must already be available to GAP. This function does not install it.
- *name* is a nonempty package name string. A blank name gives
  `Failure["GAPUnsupportedValue", ...]`.
- `"Version" -> Automatic` accepts any version. A version string is passed to GAP.
- `TimeConstraint -> Infinity` allows any running time for loading.
- Loading an already loaded package is safe. Dependencies appear in
  `session["LoadedPackages"]`.
- Once loaded, its functions can be called with `GAPCall` or `GAPEvaluate`.

## Basic Examples

Load the small-group library and identify a group:

```wl
WithCleanup[
 session = StartGAPSession[],
 LoadGAPPackage[session, "smallgrp"];
 GAPCall[session, "IdGroup", GAPCall[session, "SmallGroup", 8, 3]],
 DeleteObject[session]
]
```
