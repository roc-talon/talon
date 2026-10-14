# Talon

Talon is a package manager and compiler manager for Roc (`tln`). The spec is `DESIGN.md` and the 3 files it lists.

- Before you write Talon code or tests, read `TESTING.md`. Work in slices (`TESTING.md` 7): scope, tests (red), human review, code (green), verify.
- Code shape (`TESTING.md` 2): each decision is a pure function, tested with `roc test`. Command code is direct-style Roc that gets an `Fx` effect record. Tests pass a fake `Fx`. Do not write commands as data.
- A test names the rule ids that it checks (`# H3: ...`). `MISSING=1 scripts/rules.sh <GROUP ...>` lists the rules with no test.
- If the design does not say what to do, do not choose: write a question (TW17) and stop that part.
- The test agent and the code agent are different agents. The code agent does not edit tests (TW18).
- Write in ASD-STE100 Simplified Technical English. Prefer tables and diagrams.
- `cloudflare-workers/` is a submodule with its own `PLAN.md`. TESTING.md does not cover it.
- Prototype code goes in the repo (`research/`), never only in a temp dir. No commit or push unless the user asks.
