# Design

GAPLink connects Wolfram Language to GAP. It can be used by PureMath or any other project.
It does not depend on those projects.

```text
Wolfram Language projects -> GAPLink -> GAP
```

## Rules

- Loading GAPLink must not start or install GAP.
- Public functions must not depend on one way of running GAP.
- Convert simple GAP values to Wolfram Language values.
- Keep a reference to GAP objects that cannot be converted.
- Return a clear `Failure` when something goes wrong.
- Report the versions of GAP, GAPLink, and any GAP packages in use.
- Check whether optional GAP packages are installed.
- Record the source and license of outside code and files.

## Choices to make

- how GAPLink runs GAP
- how GAPLink finds GAP
- which versions and systems we support
- how GAP and Wolfram Language values are matched
- whether a future release includes GAP

Record each choice in `docs/decisions/` before writing that part of the project.
