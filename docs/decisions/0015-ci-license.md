# Decision 0015: CI license use

- Status: Accepted
- Date: 2026-09-02
- Owner: GAPLink maintainers

## Why

Starting many Wolfram kernels can exhaust the CI entitlement. The next kernel then fails
before tests begin.

## Choice

- Build GAP and the platform runtimes without a Wolfram kernel.
- Run all Wolfram checks, GAP tests, and paclet builds in one kernel.
- Export documentation in that kernel. The CI entitlement cannot open subkernels.
- Build documentation once. Platform paclets reuse that build and are archived once.
- Use one kernel to publish a release.

## Result

Each CI or publish run starts one Wolfram kernel. GAP builds still run in parallel. The
platform paclets do not rebuild documentation or create a second archive.

## Checks

- Test every supported GAP version.
- Test the GAP included in the Linux paclet.
- Upload platform paclets only after all checks pass.
