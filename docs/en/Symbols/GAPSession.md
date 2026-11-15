---
Template: Symbol
Name: GAPSession
Context: WolframInstitute`GAPLink`
Paclet: WolframInstitute/GAPLink
URI: WolframInstitute/GAPLink/ref/GAPSession
Keywords: [GAP, GAP sessions]
SeeAlso: [StartGAPSession, GAPCall, LoadGAPPackage]
RelatedGuides: [GAPLink]
---

## Usage

`GAPSession[...]` represents an explicit GAP session.

`session["property"]` reads a session property.

## Details & Options

- Create a session with `StartGAPSession`. Loading GAPLink does not start GAP.
- Properties include `"Status"`, `"Executable"`, `"Version"`, `"Packages"`,
  `"LoadedPackages"`, `"Backend"`, and `"Properties"`.
- `"Packages"` lists packages found at startup. `"LoadedPackages"` gives loaded
  package names and versions.
- `DeleteObject[session]` closes GAP and invalidates its objects.
- A name that is not a property gives `Missing["UnknownProperty", name]`. A request that is
  not one name gives `Failure["InvalidArguments", ...]`.

## Basic Examples

Read the GAP version and the packages already loaded:

```wl
WithCleanup[
 session = StartGAPSession[],
 {session["Version"], session["LoadedPackages"]},
 DeleteObject[session]
]
```
