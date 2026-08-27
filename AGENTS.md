# Repository rules

- Read `docs/architecture.md` before changing backend or packaging code.
- GAPLink must not depend on projects that use it.
- Loading GAPLink must not start or install GAP.
- Do not vendor or download GAP, libgap, GAP packages, or other binaries without an accepted ADR.
- Keep backend details out of the public API.
- Keep GAP-dependent tests separate from the basic test suite.
- Add tests for behavior changes.
- Run `make all` before handing off changes.
- Update `CHANGELOG.md` for user-visible changes.
