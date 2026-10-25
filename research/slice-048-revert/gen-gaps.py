#!/usr/bin/env python3
"""Slice 048, gap step (TESTING.md 7.1 step 5): makes the files of the L2 case tool/tu2-updatestops (no `expect/`: UPDATE=1 writes it, TW21). It uses the classes of gen-manage.py (the text before its first case) and writes only
under tests/commands/cases/tool/tu2-updatestops/. Run from the repo root: python3 research/slice-048-revert/gen-gaps.py."""
src = open("research/slice-048-revert/gen-manage.py").read().split("# ---------------------------------------------------------------- tm1-manage")[0]
exec(src)

MONTH = "nightly-2026-October-14-38a3029"  # the other tag form of PIN
RULES = """Slice 048, gap tests of `tln tool update` (entry `commands`). One home with the compiler `nightly-2026-10-14-38a3029` only, `TALON_NOW=2026-10-15T12:00:00Z`, the nightly list. `tools.json` has `np` (acme/np 1.0.0; the repo has 1.1.0, an app with no `roc:` pin),
`mo` (acme/mo 1.0.0; the repo has 1.1.0, an app that pins `nightly-2026-October-14-38a3029`, the other tag form of the installed compiler) and `gm` (acme/gm from main). A fake tty (a person).

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool update np` | the new header has no pin: exit 2 (D11, 046 D3) before the platform step (no platform fetch, no build) | R-T24, R-T11 |
| 2 | `tool update gm --offline` | a branch tool needs the commit now: exit 15 before any commit request (no `http_get`) | R-T24, R-DI12 |
| 3 | `tool update mo` (`env:TALON_INTERACTIVE=1`) | the pin is not an installed id by its text, so a download is counted and the offer is read (the nightly list), but the offer is `Present` (the other tag form is installed): no prompt (no `ask`), no download. The build runs and `mo` is updated | R-T25, R-DL1 |
"""
c = Case("tu2-updatestops", RULES)
c.toolchain(PIN)
c.with_nightlies()
c.tools([
    {"key": "np", "name": "acme/np", "source": release("1.0.0", "acme/np", "1.0.0", "np-1.0.0")},
    {"key": "mo", "name": "acme/mo", "source": release("1.0.0", "acme/mo", "1.0.0", "mo-1.0.0")},
    {"key": "gm", "name": "acme/gm", "source": git(OLDC, "main")},
])
for k in ("np", "mo", "gm"):
    c.files(k, data=f"old {k}\n", entry=f"old {k}\n")
c.repo("acme/np", [("1.1.0", "np-1.1.0", "2026-09-01T12:00:00Z", app(pin=None)), ("1.0.0", "np-1.0.0", "2026-08-01T12:00:00Z", app())])
c.repo("acme/mo", [("1.1.0", "mo-1.1.0", "2026-09-01T12:00:00Z", app(pin=MONTH)), ("1.0.0", "mo-1.0.0", "2026-08-01T12:00:00Z", app())])
c.commit("acme/gm", "main", BBBB)
c.platform()
c.tarball([("main.roc", "gm")])
c.write("fx/src/gm.src", app())
c.finish(["tool update np", "tool update gm --offline", "tool update mo env:TALON_INTERACTIVE=1"], [BUILD_OK], tty=True)
print("ok")
