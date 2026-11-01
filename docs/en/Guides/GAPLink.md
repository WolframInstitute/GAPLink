---
Template: Guide
Name: GAPLink
Title: Algebra with GAP
Context: WolframInstitute`GAPLink`
Paclet: WolframInstitute/GAPLink
URI: WolframInstitute/GAPLink/guide/GAPLink
Keywords: [GAP, groups, algebra]
---

## Abstract

GAPLink connects Wolfram Language to GAP for groups, representations, finite
fields, polynomials, algebras, and other discrete mathematics. Call GAP's library
functions directly or evaluate GAP code. Release paclets include GAP and its
small, primitive, transitive, and perfect group libraries.

## Functions

- `StartGAPSession` starts GAP.
- `GAPSession` represents a session and reports its version and packages.
- `GAPCall` calls a named function or a function kept in GAP.
- `GAPEvaluate` evaluates GAP source code.
- `GAPObject` keeps a GAP value available for further calculations.
- `GAPPackageAvailableQ` checks whether a package can be loaded.
- `LoadGAPPackage` loads a package already available to GAP.
