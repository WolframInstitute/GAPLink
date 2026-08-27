# Decision 0005: GAP and Wolfram Language values

- Status: Accepted
- Date: 2026-08-27
- Owner: GAPLink maintainers

## Why

GAPLink needs clear rules for moving values between GAP and Wolfram Language. Exact values
must stay exact. GAP values without a clear match must remain usable.

## Choice

GAPLink converts these values automatically:

| Wolfram Language | GAP |
| --- | --- |
| `Integer` | integer |
| `Rational` | rational |
| `True` and `False` | `true` and `false` |
| `Missing["GAPFail"]` | `fail` |
| finite machine `Real` | built-in 53-bit float |
| `String` | UTF-8 string |
| `ByteArray` | string containing raw bytes |
| `Cycles` | permutation |
| `List` | dense list |
| `Association` with string keys | record |

A GAP function that returns no value gives `Null`. `Null` is not sent to GAP as a value.

GAP `fail` is a normal GAP result. It maps to `Missing["GAPFail"]`, not `Failure`.
`Failure` is used for GAPLink errors.

Lists and records convert recursively. A value inside them that has no direct match becomes
a `GAPObject`. Record keys are sorted when a GAP record becomes an `Association`, so their
order does not depend on the GAP session.

A Wolfram Language string is encoded as UTF-8. A GAP string that contains valid UTF-8
becomes a `String`. Other GAP string bytes become a `ByteArray`.

Automatic conversion makes a copy. It does not keep GAP identity or mutability. These calls
can keep any result in GAP instead:

```wl
GAPCall[session, name, args, "ReturnType" -> "Object"]
GAPEvaluate[session, code, "ReturnType" -> "Object"]
```

`Normal[object]` requests a copy when the object has a supported mapping.

Automatic conversion has a documented size limit. Large containers become `GAPObject`
values. We will set the first limit after measuring the process protocol.

These values stay as `GAPObject` in the first version:

- groups, rings, fields, and homomorphisms
- finite-field elements and cyclotomic numbers
- GAP functions and operations
- GAP characters
- sparse or cyclic lists
- arbitrary-precision and non-finite floats
- large lists and records
- any value without a clear, lossless match

GAPLink does not turn unsupported Wolfram Language expressions into GAP text.

Each `GAPObject` belongs to one session. It cannot be used with another session. Its private
ID is not part of the public form and the object does not survive its GAP session. Deleting
the object releases it. Stopping or losing the session invalidates all its objects.

GAPLink implements this mapping in its own protocol. The GAP JSON package is useful prior
work, but GAPLink does not depend on it.

## Other options

- Return every GAP value as a `GAPObject`.
- Convert only the values supported by JSON.
- Map GAP `fail` to `Null` or `Failure`.
- Convert complex exact GAP values in the first version.
- Convert containers without a size limit.

## Result

Common values work without extra wrappers. Exact numbers stay exact. Complex and large GAP
values remain in their session until a later call needs them.

## Checks

- Round-trip integers, rationals, booleans, finite machine reals, strings, and bytes.
- Keep GAP `fail`, no return value, and GAPLink errors distinct.
- Round-trip the identity and a nontrivial permutation.
- Convert nested dense lists and records.
- Keep unsupported values inside converted containers as `GAPObject`.
- Keep large, sparse, and cyclic containers as `GAPObject`.
- Force a simple result to stay in GAP and copy it later with `Normal`.
- Reject an object from another session.
- Invalidate an object after it or its session is deleted.

## Sources

- [GAP Reference Manual](https://docs.gap-system.org/doc/ref/chap0_mj.html)
- [GAP JSON package](https://github.com/gap-packages/json)
- [Wolfram Language Cycles](https://reference.wolfram.com/language/ref/Cycles.html)
- [Wolfram Language ByteArray](https://reference.wolfram.com/language/ref/ByteArray.html)
