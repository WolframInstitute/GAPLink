# Security policy

## Reporting a vulnerability

Do not open a public issue for a suspected security vulnerability. Use the private security
advisory facility in the GitHub repository and include:

- the affected GAPLink version or commit;
- the Wolfram Language, operating-system, GAP, and transport versions;
- a minimal reproducer;
- the expected and observed impact.

## Security boundary

The current foundation does not execute GAP or load native code. Future transports will cross a
process or native-library trust boundary. Their design must address command injection, untrusted
serialization, resource exhaustion, cancellation, process cleanup, foreign-object lifetime, and
the effect of GAP initialization files before release.
