# Library coverage and PacletPage builds

Status: accepted

GAPLink remains a general bridge. GAPCall can call any available global GAP
function, a function in a record such as MTX.Dimension, or a function returned
as a GAPObject. GAP's named options are passed
in a separate association and restored after each call, including errors.
No list of mathematical function wrappers is maintained in Wolfram Language.

Characters keep their character tables in GAP. Automatic copying is limited to
32 nested levels and 10,000 entries across lists and records. Permutations moving
points above 10,000 also remain in GAP. Call GAP functions on these objects to
reduce them before copying results.

Test core GAP and the bundled group libraries. Use the upstream test files in
addition to tests of conversions, functions, options, errors, and sessions.
Optional packages remain accessible after LoadGAPPackage; they are not downloaded
or added to releases by this change.

Use pinned PacletPage, MarkdownToNotebook, and WolframParser revisions to build
documentation and every paclet archive. Keep Markdown sources under docs/en.
A single project.wls entry point replaces separate command wrappers and manual
archive creation. Retain the runtime builders and platform-aware cloud uploader:
they provide four platform downloads at the existing URLs. Publishing still
requires a release tag and a successful CI build of the same commit.

Build documentation once, then reuse its pages and incremental records for each
platform archive. PacletPage verifies the hashes before reusing them. A single
driver runs the checks; PacletPage's build and load kernels run sequentially
through the entitlement-aware wolframscript launcher in CI. This replaces the
single-kernel archive implementation in decision 0015.
