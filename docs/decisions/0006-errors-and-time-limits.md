# Decision 0006: Errors and time limits

- Status: Accepted
- Date: 2026-08-27
- Owner: GAPLink maintainers

## Why

A GAP error may be safe to catch, but a timeout, abort, or crash can leave unknown state.
GAPLink needs clear results for each case.

## Choice

`GAPCall` and `GAPEvaluate` accept `TimeConstraint`. Their default is `Infinity`.
`StartGAPSession` also accepts `TimeConstraint` and defaults to 30 seconds. A time
constraint must be a positive number of seconds or `Infinity`.

When a GAP call passes its time constraint, GAPLink stops that GAP process. It does not try
to continue, restart, or run the call again. The session and all its objects become invalid.

Aborting the Wolfram Language evaluation also stops the GAP process and returns `$Aborted`.

GAPLink catches an ordinary GAP error and returns a `Failure`. The session stays open. A
failed GAP call is not a transaction: it may have changed GAP values before the error.

GAPLink uses these failure tags:

| Tag | Use | Session after the failure |
| --- | --- | --- |
| `"GAPStartFailed"` | GAP could not be found, started, or reached in time | no session |
| `"GAPInvalidSession"` | the session is stopped, closed, or from another kernel | unchanged |
| `"GAPInvalidObject"` | the object is deleted, stale, or belongs to another session | ready |
| `"GAPSessionBusy"` | another call is using the session | busy |
| `"GAPUnsupportedValue"` | an argument cannot be converted | ready |
| `"GAPFunctionNotFound"` | the named GAP function is missing or is not a function | ready |
| `"GAPInvalidOption"` | an option value is not valid | unchanged |
| `"GAPError"` | GAP reported an error | ready |
| `"GAPTimeConstraintExceeded"` | a call took too long | stopped |
| `"GAPProcessStopped"` | GAP exited or crashed | stopped |
| `"GAPProtocolError"` | a response was missing or invalid | stopped |

Every failure has `"MessageTemplate"` and `"MessageParameters"`. It may also include short
fields such as `"Function"`, `"GAPMessage"`, `"TimeConstraint"`, or `"ExitCode"`. Failures
do not copy full GAP code or full argument values.

`session["Status"]` returns one of these values:

- `"Ready"`
- `"Busy"`
- `"Stopped"`
- `"Closed"`

Only one call runs in a session at a time. Calls in separate sessions can run independently.

`DeleteObject` is safe when an object or session has already stopped. An object never
becomes valid again in a new GAP process.

The process protocol keeps GAP output separate from its own messages. A later decision will
say how successful GAP `Print` output is returned.

## Other options

- Keep using a GAP process after a timeout or abort.
- Restart GAP and run a failed call again.
- Stop the session after every GAP error.
- Use one fixed time limit for all calls.
- Return `$Failed` instead of named `Failure` values.

## Result

Normal GAP errors do not end a session. Cases with unknown process state end the session and
invalidate its objects. Calls are never repeated without the user asking.

## Checks

- Start GAP with its default and a custom time constraint.
- Reject a nonpositive or nonnumeric time constraint.
- Return a GAP error, then run another call in the same session.
- Stop the session after a call timeout or user abort.
- Detect a GAP crash and a broken protocol response.
- Invalidate every object when its session stops.
- Report `"Ready"`, `"Busy"`, `"Stopped"`, and `"Closed"` correctly.
- Reject a second call while a session is busy.
- Confirm that a failed call is not run again.

## Sources

- [GAP break loops](https://docs.gap-system.org/doc/ref/chap6_mj.html#X8593B49F8705B486)
- [GAP error catching](https://github.com/gap-system/gap/blob/master/src/error.c)
- [TimeConstrained](https://reference.wolfram.com/language/ref/TimeConstrained.html)
- [CheckAbort](https://reference.wolfram.com/language/ref/CheckAbort.html)
- [KillProcess](https://reference.wolfram.com/language/ref/KillProcess.html)
