# Decision 0025: License

- Status: Accepted
- Date: 2026-11-13
- Owner: GAPLink maintainers

## Why

GAPLink exists to run GAP, and release paclets include GAP. GAP uses the GNU General
Public License, version 2 or any later version. GAPLink code used the MIT license, so one
paclet came under two sets of terms.

## Choice

GAPLink code uses the GNU General Public License, version 2 or any later version, as GAP
does. The identifier is `GPL-2.0-or-later`.

- `LICENSE` holds the text of version 2. It is the same file as in GAP.
- `COPYRIGHT` names the copyright holder and says that a later version may be used.
- `PacletInfo.wl`, `CITATION.cff` and the resource definition give the identifier.
- The runtime's `licenses/README.txt` says the same in each release paclet.

Versions up to 0.3.3 were released under the MIT license and stay under it.

This replaces the sentence about the license of GAPLink code in
[decision 0013](0013-managed-gap-runtime.md). The rest of that decision stands.

## Other options

- Keep the MIT license for GAPLink code.

## Result

One license covers GAPLink and GAP in a release paclet. Whoever passes GAPLink on, or
work based on it, must follow the GNU General Public License.

## Checks

- `make check` compares the license in `CITATION.cff` with `PacletInfo.wl`.
- `LICENSE` is the same file as `LICENSE` in GAP.
- Review the licenses of every included runtime file before a release, as before.

## Sources

- [GAP license](https://github.com/gap-system/gap/blob/master/LICENSE)
- [GAP copyright](https://github.com/gap-system/gap/blob/master/COPYRIGHT)
- [GNU General Public License, version 2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)
