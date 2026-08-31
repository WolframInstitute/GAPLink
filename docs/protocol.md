# Process protocol

This is GAPLink's private process format. It is not a public API.

## Frames

GAPLink and GAP exchange byte frames:

```text
GAPLINK:<token>:<version>:<kind>:<request-id>:<payload-length>:<payload>
```

- `token` is 32 lowercase hexadecimal characters. A new session gets a new token.
- `version` is `1`.
- `kind` is `Q` for a request, `R` for a response, or `E` for the end of standard error.
- `request-id` is a positive integer no larger than `9223372036854775807`.
- `payload-length` is the number of payload bytes.
- `payload` is one encoded value for `Q` and `R`. An `E` frame has no payload.

Fields do not have leading zeros. Frames do not end with a newline. The largest payload is
64 MiB.

For example, this request carries the integer `42`:

```text
GAPLINK:0123456789abcdef0123456789abcdef:1:Q:1:5:i2:42
```

GAP may write normal text before an `R` frame. GAPLink keeps those bytes as standard output.
GAP writes an `E` frame to standard error when that stream is complete for the request.
GAPLink waits for both markers and drains both streams while the request runs.

## Values

Each value has a one-byte tag, a data length, a colon, and its data:

```text
<tag><data-length>:<data>
```

All value data is ASCII. Containers join their child values without a separator. A value may
be nested at most 128 levels.

| Tag | Value | Data |
| --- | --- | --- |
| `i` | integer | signed decimal integer |
| `q` | rational | numerator and denominator integers |
| `t` | `True` | empty |
| `f` | `False` | empty |
| `n` | no GAP return value | empty |
| `x` | GAP `fail` | empty |
| `d` | finite machine real | GAP external mantissa and exponent integers |
| `s` | UTF-8 string | lowercase hexadecimal bytes |
| `b` | raw bytes | lowercase hexadecimal bytes |
| `p` | permutation | integer images |
| `l` | dense list | child values |
| `r` | record | alternating string keys and values |
| `o` | GAP object reference | positive decimal object ID |

Record keys use UTF-8 byte order. A permutation lists the images of `1` through its largest
moved point. The empty list is the identity permutation.

The machine-real pair follows GAP's exact external representation. For nonzero `m`:

```text
value = m * 2^(e - IntegerLength[Abs[m], 2])
```

The mantissa is odd. Zero uses `{0, 0}`.

Examples:

| Value | Encoding |
| --- | --- |
| `42` | `i2:42` |
| `1/3` | `q8:i1:1i1:3` |
| `True` | `t0:` |
| `Missing["GAPFail"]` | `x0:` |
| `"Hi"` | `s4:4869` |
| `ByteArray[{0, 255}]` | `b4:00ff` |
| `{True, 42}` | `l8:t0:i2:42` |
| `<|"A" -> 1|>` | `r9:s2:41i1:1` |

## Requests

A request payload is a record with an `"Operation"` field.

| Operation | Other fields |
| --- | --- |
| `"Hello"` | none |
| `"Call"` | `"Name"`, `"Arguments"`, `"ReturnType"` |
| `"Evaluate"` | `"Code"`, `"ReturnType"` |
| `"Normal"` | `"Object"` |
| `"Release"` | `"Objects"` |
| `"Close"` | none |

`"ReturnType"` is `"Automatic"` or `"Object"`.

## Responses

A response payload is a record with a `"Status"` field. A successful response uses `"OK"`
and has a `"Result"` field. An error status uses the matching GAPLink failure tag and has a
short `"Message"` field.

The `"Hello"` result reports the protocol version, GAP version, build, system, processor,
packages, and whether GAP is an HPC build. No other request is valid before `"Hello"`
succeeds. GAP then reads one request at a time. A `"Close"` response ends the process.

## Live test

`make test-gap` starts a public GAP session and calls GAP functions. It is separate from
`make test`, which does not need GAP.

## Invalid data

GAPLink stops the session when a frame has the wrong version, token, kind, request ID, length,
or value encoding. Incomplete data remains buffered while the process is running. If the
process ends before the frame is complete, the call fails.
