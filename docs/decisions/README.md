# Architecture decision records

Architecture decision records document choices that are expensive to reverse or affect the
public compatibility contract.

Create records from `0000-template.md`, assign the next four-digit number, and keep accepted
records immutable. If a decision changes, add a new record that supersedes the old one.

The first expected records are:

1. GAP discovery, installation, and distribution policy;
2. reference and optional transports;
3. value conversion and opaque-handle lifetime;
4. error, timeout, cancellation, and recovery semantics;
5. supported GAP versions, packages, and platforms.
