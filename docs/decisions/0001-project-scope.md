# Decision 0001: Project scope

- Status: Accepted
- Date: 2026-08-27
- Owner: GAPLink maintainers

## Why

We need to decide what belongs in GAPLink. PureMath may use it, but GAPLink should also work
on its own.

We could not review the old GAPLink project because its Stash page is unavailable.
See [the legacy review](../legacy-gaplink.md).

## Choice

- GAPLink connects Wolfram Language to GAP.
- It finds GAP, starts and stops it, sends calls, and returns results or errors.
- It does not depend on PureMath or another project.
- PureMath and other projects can add their own higher-level math functions.
- Loading GAPLink does not find, start, or install GAP.
- Public functions do not expose how GAP is run.
- If we add a way to run GAP text, it must be a clear and direct user action.

The first release will not add high-level group theory functions, install GAP, include GAP,
or run GAP over a network.

## Other options

- Build GAP support directly into PureMath.
- Build one project for GAP and several other math systems.

## Result

GAPLink stays small and can be used by more than one project. Each project can build its own
math functions on top of it.

## Checks

- The paclet loads without GAP installed.
- The repository does not depend on PureMath or another project.
- Every public function belongs in GAPLink.
