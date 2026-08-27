# Architecture baseline

## Purpose

GAPLink will provide a small, stable Wolfram Language boundary around GAP. It is infrastructure,
not a second high-level group-theory vocabulary.

```text
downstream mathematical paclets
             |
             v
      public GAPLink API
             |
             v
   transport-neutral internals
       |                |
       v                v
 persistent process   optional native bridge
       |                |
       +--------+-------+
                v
          GAP and packages
```

## Invariants

1. **Side-effect-free loading.** Loading GAPLink performs no discovery, installation, process
   startup, native loading, or network access.
2. **One-way dependency.** GAPLink has no dependency on PureMath. PureMath may optionally call
   GAPLink through an adapter.
3. **Transport-neutral public contract.** Public session, call, conversion, and error behavior
   cannot depend on whether the implementation uses a child process or libgap.
4. **Structured values first.** Supported values cross the boundary through typed conversion.
   Unsupported values use managed opaque handles. Raw text evaluation is an explicit escape
   hatch, not the primary call mechanism.
5. **Failure containment.** Timeouts, cancellation, malformed output, GAP errors, process exits,
   and invalid handles produce stable Wolfram Language failures. A recoverable backend problem
   must not leave a session silently corrupted.
6. **Reproducibility.** A session can report GAP, GAPLink, transport, platform, and loaded-package
   versions.
7. **Capability discovery.** Optional GAP packages are detected and reported; their presence is
   never inferred solely from the GAP core version.
8. **License provenance.** Every bundled or linked third-party component has recorded source,
   license, version, and update policy.

## Deferred decisions

The foundation deliberately does not decide:

- whether the reference transport is a persistent process, libgap, or both;
- how GAP is discovered or installed;
- which GAP and GAP-package versions are supported;
- the precise conversion table and opaque-handle representation;
- supported platforms for a native bridge;
- whether any GAP component is bundled with a release.

Each decision must be captured under `docs/decisions/` before implementation fixes it in the
public contract.
