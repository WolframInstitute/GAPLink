# Repository rules

- Read `docs/architecture.md` before changing how GAP runs or how the paclet is built.
- GAPLink must not depend on projects that use it.
- Loading GAPLink must not start or install GAP.
- Do not add or download GAP, libgap, GAP packages, or other files without an accepted decision.
- Do not expose how GAP is run through public functions.
- Keep GAP tests separate from tests that do not need GAP.
- Use short, plain language in docs, comments, errors, and test names.
- Use technical terms only when needed. Explain new terms.
- Add tests for behavior changes.
- Run `make all` before handing off changes.
- Update `CHANGELOG.md` for user-visible changes.
