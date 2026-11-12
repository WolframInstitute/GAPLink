# Decision 0023: Windows user lookups

- Status: Accepted
- Date: 2026-11-12
- Owner: GAPLink maintainers

## Why

The Windows runtime runs GAP on Cygwin, a layer that lets Unix programs run on Windows.
Each time GAP starts, Cygwin asks Windows who the user is and which groups they belong to.

On a computer that belongs to a Windows domain (a group of computers that share one
sign-in server), Windows passes these questions to that server. When the server cannot
be reached, every question waits until it times out.

`StartGAPSession` waits 30 seconds for GAP. A longer wait means GAP does not start, and
projects that fall back to their own code become slow without saying why.

This does not happen for a local account on a computer outside a domain. CI runs that way,
so CI did not show it.

## Choice

The Windows build writes three small files into the runtime's `runtime/etc` folder:

- `nsswitch.conf` tells Cygwin to read users and groups from its own files only
  (`passwd: files` and `group: files`), not from Windows.
- `passwd` and `group` each hold one entry: the "unknown" user and the "unknown" group,
  both with ID 4294967295. Cygwin gives these to anyone it cannot find in its files.

GAP then runs as the unknown user, and Cygwin never asks Windows. The two entries are
needed. Without them Cygwin still asks Windows about ID 4294967295 the first time a
program looks up its own user.

Cygwin can no longer find the home folder this way. The installer's `db_home` setting only
applies to users read from Windows, so the build drops it. GAPLink passes `HOME` itself
when it starts the Windows launcher, using `$HomeDirectory`. A `HOME` that is already set
is kept. `~` in GAP points at the same folder as before.

This changes only the GAP included in the paclet. A GAP installed separately and chosen
with `"Executable"` keeps its own settings.

## Other options

- Keep the installer's settings. GAP can fail to start on domain computers.
- Read users from Windows and only groups from files. The user lookup still waits.
- Write only `nsswitch.conf`. The longest wait goes away, but a wait of about 12 seconds
  remains on each start.
- Create real entries for each user when a session starts. This writes inside the
  installed paclet and needs the lookup we want to avoid.
- Raise the 30 second limit. Starts would still be slow.

## Result

GAP starts in the same time whether or not the domain's server can be reached.

Measured on a test domain with the server unreachable, as a domain user in 21 groups:

| Runtime | Wait before GAP begins to load |
| --- | --- |
| Installer's settings | 126 seconds right after the server drops away, then about 12 seconds |
| `nsswitch.conf` only | about 12 seconds |
| All three files | none |

Windows remembers a failed lookup for a short time (under a minute), so a start soon
after a slow one skips the wait.

Inside the included runtime, Cygwin's own tools (`id`, `whoami`, `ls -l`) show the user
as `Unknown+User`. GAP does not use these names.

## Checks

- Reject a Windows paclet unless `nsswitch.conf` lists only `files` for `passwd` and
  `group`, and `passwd` and `group` each name ID 4294967295.
- Pass the home folder to the Windows launcher. Keep one that is already set.
- In a live session, check that GAP's home folder exists.
- Before changing these files, time a start as a domain user while the domain's server
  cannot be reached. CI cannot do this.

## Sources

- [Cygwin: where users and groups come from](https://cygwin.com/cygwin-ug-net/ntsec.html#ntsec-mapping-nsswitch-pwdgrp)
- [Cygwin FAQ: slow start](https://cygwin.com/faq.html#faq.using.startup-slow)
- [Cygwin asks Windows about the unknown user](https://github.com/cygwin/cygwin/blob/cygwin-3.6.10/winsup/cygwin/passwd.cc#L180)
  and [group](https://github.com/cygwin/cygwin/blob/cygwin-3.6.10/winsup/cygwin/grp.cc#L235)
- [Cygwin asks the domain's server first](https://github.com/cygwin/cygwin/blob/cygwin-3.6.10/winsup/cygwin/uinfo.cc#L1366)
- [GAP installer settings](https://github.com/gap-system/gap-windows/blob/641bc30aaccd0dd672bcd383105a90b034088d00/cygwin_extras/etc/nsswitch.conf)
