# Decision 0003: How GAP runs

- Status: Accepted
- Date: 2026-08-27
- Owner: GAPLink maintainers

## Why

GAPLink can start GAP as a separate program or load libgap into the Wolfram kernel. libgap
may be faster, but it is harder to build and a crash could also stop the Wolfram kernel.

## Choice

- The first version starts one local GAP program and keeps it open while it is being used.
- GAPLink can stop or restart it, end a slow call, and recover if GAP stops.
- Public functions do not depend on this choice, so we can add libgap later.
- GAPLink sends named operations and data. Running GAP text, if added, is a separate action.
- We will decide how values move between GAP and Wolfram Language next.
- GAPLink does not start a network service.

We may add libgap later. First, a small test must cover building it, licensing, memory,
errors, and crashes.

## Other options

- Use only libgap.
- Start a new GAP process for every call.
- Connect to GAP over a network.

## Result

Calls may be a little slower, but a GAP crash should not crash the Wolfram kernel. We can add
libgap later without changing user code.

## Checks

- Start GAP and report its version.
- Run many calls without starting GAP again.
- Handle an error, a slow call, a stopped call, and a GAP crash.
- Start GAP again after a crash.
- Test simple values and one complex GAP object.

## Sources

- [Wolfram Language StartProcess](https://reference.wolfram.com/language/ref/StartProcess.html)
- [GAP libgap API](https://github.com/gap-system/gap/blob/master/src/libgap-api.h)
- [Wolfram LibraryLink](https://reference.wolfram.com/language/guide/LibraryLink.html)
