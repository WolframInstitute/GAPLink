# Decision 0004: Public functions and sessions

- Status: Accepted
- Date: 2026-08-27
- Owner: GAPLink maintainers

## Why

GAPLink needs a small public API before we build the GAP connection. A session means one
running copy of GAP.

## Choice

The first public symbols are:

- `StartGAPSession[]` finds GAP and starts a session.
- `GAPSession[...]` represents a session. Users do not create it directly.
- `GAPCall[session, name, arg1, arg2, ...]` calls a named GAP function.
- `GAPEvaluate[session, code]` runs GAP text directly.
- `GAPObject[...]` represents a GAP value that was not converted.

Use `StartGAPSession["Executable" -> path]` to choose a GAP executable. If GAP cannot
start, return a `Failure`.

Every call takes a session. GAPLink does not create a hidden default session.

A session provides these properties:

- `"Status"`
- `"Executable"`
- `"Version"`
- `"Packages"`
- `"Backend"`
- `"Properties"`

`DeleteObject[object]` releases a `GAPObject`. `DeleteObject[session]` stops GAP and
invalidates the objects from that session.

GAPLink will not add `StopGAPSession`, `$GAPExecutable`, `GAPAvailableQ`,
`GAPFunction`, or `GAPSessions` in the first version.

Math functions such as `GroupCenter` belong in projects that use GAPLink.

## Other options

- Use `StartExternalSession["GAP"]` as the main API.
- Keep one hidden GAP session for all calls.
- Add a separate stop function.
- Support only GAP text.

## Result

The API is small and does not expose how GAP runs. Projects can use named GAP calls while
raw GAP text remains a clear user action.

## Checks

- Loading GAPLink does not start GAP.
- Two sessions work without sharing state.
- An explicit executable path is used when given.
- Session properties report the running setup.
- Named calls and GAP text both work.
- Deleted objects and sessions cannot be used.

## Sources

- [Wolfram Language StartExternalSession](https://reference.wolfram.com/language/ref/StartExternalSession.html)
- [Wolfram Language ExternalEvaluate](https://reference.wolfram.com/language/ref/ExternalEvaluate.html)
- [LeanLink](https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/LeanLink/)
