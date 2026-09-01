# Decision 0008: Process protocol and output

- Status: Accepted
- Date: 2026-08-28
- Owner: GAPLink maintainers

## Why

GAPLink must keep GAP results, printed text, errors, and its own messages separate. The
connection must also work on Linux, macOS, and Windows.

## Choice

GAPLink starts GAP with `StartProcess` and an argument list. It does not use a shell. GAP
runs in quiet, noninteractive mode with line editing disabled. A GAPLink-owned startup file
runs a small request loop. GAPLink does not parse GAP prompts or echoed input.

The first request checks the protocol. It uses a new random session token and returns the GAP
version, build, system, processor, and packages.

The protocol is private and versioned. Each request and response has:

- the protocol version
- the session token
- a request ID
- an exact byte length
- a tagged payload

The payload uses an ASCII-safe format. Strings and raw bytes are encoded explicitly. The
protocol does not use JSON, GAP printed forms, prompts, or line endings as separators.

`GAPCall` sends a function name and encoded arguments. It does not build GAP source code.
`GAPEvaluate` uses GAP's command reader and may run several commands. It returns the last
value, or `Null` if there is no value. The implementation tests the command reader on every
supported GAP release.

GAPLink catches normal GAP errors and returns them in a response. A missing or invalid
response stops the session, as set by Decision 0006.

Normal GAP output comes before a private response marker on standard output. Standard error
has its own end marker. The markers contain the session token and request ID. GAPLink drains
both streams while GAP runs, so large output cannot fill a process pipe and block the call.
Order is kept within each stream. Order between the two streams is not guaranteed.

`GAPCall` and `GAPEvaluate` accept this option:

```wl
"Output" -> "Print"
"Output" -> "Capture"
"Output" -> "Discard"
```

`"Print"` is the default. It writes captured standard output and standard error after the
call finishes, then returns the normal result. It does not add a newline.

`"Capture"` returns:

```wl
<|
    "Result" -> result,
    "StandardOutput" -> output,
    "StandardError" -> errors
|>
```

`"Discard"` drains the output but does not show or return it.

Valid UTF-8 output becomes a `String`. Other bytes become a `ByteArray`. If a call fails,
it still returns a `Failure`. With `"Capture"`, the failure contains `"StandardOutput"` and
`"StandardError"` fields.

Interactive GAP input is not supported because standard input belongs to the protocol.
Programs that keep writing after a GAP call ends are also not supported. `GAPEvaluate` is not
a sandbox: its code can access files, start programs, or stop GAP with the user's permissions.

The Wolfram Language side uses process streams only. It does not need sockets, extra file
descriptors, Unix paths, or Unix-only signals for normal communication.

## Other options

- Parse the normal GAP prompt and printed values.
- Use JSON and require a GAP package.
- Use a socket or another file descriptor for protocol messages.
- Return printed output with every result.
- Always print or always discard GAP output.
- Support interactive GAP input.

## Result

GAPLink can tell values, printed text, errors, and protocol messages apart. Users can print,
capture, or discard GAP output. The same protocol design can be tested on every target system.

## Checks

- Start GAP without a banner, prompt, or echoed input.
- Check the protocol version, token, request ID, and byte length.
- Reject a missing, malformed, or mismatched response.
- Split frames at different byte positions and still read them correctly.
- Keep output that has no final newline.
- Keep protocol-like text in normal GAP output.
- Read large standard output and standard error without blocking.
- Print, capture, and discard output.
- Keep UTF-8 text and raw bytes distinct.
- Run several GAP commands and return the last value.
- Return a GAP error, then use the same session again.
- Stop the session after a broken response, crash, timeout, or abort.
- Run the process tests on Linux, macOS, and Windows.

## Sources

- [GAP command-line options](https://github.com/gap-system/gap/blob/master/lib/system.g)
- [GAP error catching](https://github.com/gap-system/gap/blob/master/src/error.c)
- [GAP streams](https://docs.gap-system.org/doc/ref/chap10_mj.html)
- [GAP JupyterKernel](https://github.com/gap-packages/JupyterKernel)
- [Wolfram Language StartProcess](https://reference.wolfram.com/language/ref/StartProcess.html)
- [Wolfram Language ProcessConnection](https://reference.wolfram.com/language/ref/ProcessConnection.html)
- [Wolfram Language ReadString](https://reference.wolfram.com/language/ref/ReadString.html)
