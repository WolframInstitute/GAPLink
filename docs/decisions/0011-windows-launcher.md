# Decision 0011: Windows GAP launcher

- Status: Accepted
- Date: 2026-09-01
- Owner: GAPLink maintainers

## Why

The GAP Windows installer provides `gap.bat`. It opens GAP in a separate Cygwin process
and does not pass command arguments through. GAPLink needs direct input and output pipes and
must pass its startup file to GAP.

## Choice

For `gap.bat`, GAPLink uses `runtime/bin/bash.exe` from the same GAP installation. The
private command converts the GAP program and startup file paths with Cygwin's `cygpath`,
then replaces Bash with GAP. It does not load shell profile files.

This is the Windows-only exception to Decision 0008's no-shell rule.

Paths are passed as separate process arguments. They are not inserted into shell text.
GAPLink does not use `cmd.exe`, open a terminal, or run the batch file.

The direct executable path remains unchanged on Linux, macOS, WSL, and native GAP builds.
The public API does not expose the launcher.

If the bundled Bash program or GAP program cannot be found, startup returns a clear
`GAPStartFailed` failure. Native Windows support is not verified until the live process
tests pass on Windows.

## Other options

- Run `gap.bat` through `cmd.exe`.
- Start the Cygwin GAP program directly.
- Require WSL on Windows.
- Keep native Windows unsupported.

## Result

GAPLink can use the layout installed by the official GAP Windows installer while keeping
one connected process. Other systems keep using GAP directly.

## Checks

- Find the batch launcher in standard Windows install locations.
- Find its bundled Bash program and one GAP program.
- Pass paths separately from the fixed shell command.
- Fail when the Windows installation is incomplete or ambiguous.
- Run the full live suite on native Windows before claiming support.

## Sources

- [GAP Windows launcher](https://github.com/gap-system/gap-windows/blob/641bc30aaccd0dd672bcd383105a90b034088d00/gap_resources/gap.bat)
- [GAP Windows build](https://github.com/gap-system/gap-windows/blob/641bc30aaccd0dd672bcd383105a90b034088d00/release_gap.sh)
- [GAP Windows runtime](https://github.com/gap-system/gap-windows/blob/641bc30aaccd0dd672bcd383105a90b034088d00/tools/gap-prep-runtime)
- [Wolfram Language StartProcess](https://reference.wolfram.com/language/ref/StartProcess.html)
