# Decision 0024: Coding guides

- Status: Accepted
- Date: 2026-11-13
- Owner: GAPLink maintainers

## Why

GAPLink's Wolfram Language code had no written standard beyond a few lines in
`CONTRIBUTING.md`. Three guides now set one: for code, for plots, and for a `Manipulate`
built around a function. A standard holds only when a program checks it.

## Choice

- Keep the three guides in `docs/coding-guides/`, as received.
  [The page beside them](../coding-guides/README.md) says how GAPLink applies them.
- Check every Wolfram Language file of the kernel, the tests and the scripts with
  `make style`. `make check`, the pre-commit hook and CI run the same check.
  `make style-fix` applies the fixes that a program can decide.
- Convert all existing code. No file is exempt.
- Load the development scripts as one package, so that the same check and the same tests
  cover them.

The guides ask that no call stays unevaluated:

- A call that used to stay unevaluated now gives `Failure["InvalidArguments", ...]` and
  the message `Name::args`. Examples are `GAPCall[]`, `GAPCall[session]`, `GAPEvaluate[]`,
  `LoadGAPPackage[]`, `StartGAPSession[1]` and `session[1]`.
- `GAPPackageAvailableQ` is a predicate, so `GAPPackageAvailableQ[]` gives `False`.

Every call that gave a `Failure` before gives the same `Failure` now, without a message.
Projects that use GAPLink rely on these results, and none of them has to change:

- A first argument that is not a session gives `"GAPInvalidSession"`.
- A function name that is not a string or a `GAPObject` gives `"GAPFunctionNotFound"`.
- Code that is not a string, and a package name that is blank or not a string, give
  `"GAPUnsupportedValue"`.
- A call that matches a form and then fails gives the failure tags of
  [decision 0006](0006-errors-and-time-limits.md).

String names for the options that GAPLink defines also stay
([decision 0004](0004-public-api.md)).

## Other options

- Give `"InvalidArguments"` and a message for every wrong call, as the guides would for
  new code. A project that passes something other than a session, and expects a
  `Failure` without a message, would then see a message and fail its tests.
- Follow the guides in new code only. The old code would stay as the example that new
  code copies.
- Check style by review only.

## Result

One standard covers the kernel, the tests and the scripts, and a program enforces it. A
wrong call always gives a `Failure`. Code that uses GAPLink runs as before.

## Checks

- `make style` reports no issue.
- Each public function has a test of its catch-all and a test of a call that matches a
  form and fails.
- Each earlier failure for a wrong call has a test that expects its tag and no message.
- Before changing how values are encoded or frames are read, compare the results of the
  old and the new code on many values, valid and invalid. On 2026-11-13 the converted
  kernel gave the same results as before in 9,043 such cases without GAP and 44 calls
  with GAP 4.16.1, apart from the calls that used to stay unevaluated.

## Sources

- [Coding guide](../coding-guides/WOLFRAMCODINGGUIDE.md)
- [Visualization guide](../coding-guides/WOLFRAMVISUALIZATION.md)
- [Manipulate guide](../coding-guides/MANIPULATEFUNCTIONCREATION.md)
