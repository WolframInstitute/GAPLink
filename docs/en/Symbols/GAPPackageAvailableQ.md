---
Template: Symbol
Name: GAPPackageAvailableQ
Context: WolframInstitute`GAPLink`
Paclet: WolframInstitute/GAPLink
URI: WolframInstitute/GAPLink/ref/GAPPackageAvailableQ
Keywords: [GAP, GAP packages]
SeeAlso: [LoadGAPPackage, GAPSession, StartGAPSession]
RelatedGuides: [GAPLink]
---

## Usage

`GAPPackageAvailableQ[session, name]` checks whether GAP can load a package.

## Details & Options

- *name* is a nonempty package name string. The check does not load or install it.
- `"Version" -> Automatic` accepts any version. A version string is passed to GAP.
- `TimeConstraint -> Infinity` allows any running time for the check.

## Basic Examples

Check for the bundled small-group library:

```wl
WithCleanup[
 session = StartGAPSession[],
 GAPPackageAvailableQ[session, "smallgrp"],
 DeleteObject[session]
]
```
