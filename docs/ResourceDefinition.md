---
Template: Paclet
ResourceType: Paclet
Name: WolframInstitute/GAPLink
Context: WolframInstitute`GAPLink`
Paclet: WolframInstitute/GAPLink
Description: Connect Wolfram Language to GAP for groups and algebra
ContributedBy: Wolfram Institute
Keywords: [GAP, groups, algebra, finite fields, representations]
MainGuide: Documentation/English/Guides/GAPLink.nb
License: GPL-2.0-or-later
WolframVersion: 15.0+
Categories: [Mathematics]
---

## Details & Options

- Platform releases include GAP and its required group libraries.
- Loading GAPLink starts no process and installs nothing.
- Exact simple values are copied; other values remain in their GAP session.
- Call global functions, returned functions, and functions from loaded packages.

## Usage

[StartGAPSession]() opens a session. [GAPCall]() calls GAP functions, and
[GAPEvaluate]() evaluates GAP code. [GAPObject]() retains mathematical objects.

## Basic Examples

Find the order of a symmetric group:

```wl
WithCleanup[
 session = StartGAPSession[],
 GAPCall[session, "Size", GAPCall[session, "SymmetricGroup", 5]],
 DeleteObject[session]
]
```
