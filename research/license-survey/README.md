# License survey of the Roc ecosystem

Data for the license decision of `roc-talon/talon`. Collected on 2026-10-16.

| Item | Value |
| --- | --- |
| Source list | `lukewilliamboswell/roc-awesome` `README.md` at `46cd1cb` (2026-10-08) |
| Entries | 61 list entries that link a repository (60 repositories: 2 entries of `~jwoudenberg/roc` are 2 packages in 1 repository). Not a sample: all entries. |
| Not in scope | `LEGACY_ROC.md` (the old compiler), links to docs and to files inside `roc-lang/roc` |
| Extra | All 27 repositories of the GitHub organization `roc-lang` (table 4) |
| License source | `license.spdx_id` of `gh api repos/{owner}/{repo}`. For `NOASSERTION` and `none`, the LICENSE file and the README were read. For sr.ht and Codeberg, the LICENSE file. |
| Stars | `stargazers_count` on the date above. A rough measure of use. |

## 1. Summary

| License (SPDX) | Entries | Share | Packages | Platforms | Tools | Apps | Compiler | Notable repositories |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UPL-1.0 | 28 | 46% | 12 | 9 | 4 | 1 | 2 | `roc-lang/roc`, `roc-lang/basic-cli`, `roc-lang/basic-webserver`, `roc-lang/http`, `roc-lang/unicode`, `lukewilliamboswell/roc-parser`, `roc-ray`, `roc-wasm4`, `roc-platform-template-zig` |
| Apache-2.0 | 19 | 31% | 18 | 1 | 0 | 0 | 0 | `niclas-ahden/joy` and 16 `niclas-ahden/*` packages, `jaredramirez/roc-redis`, `mpizenberg/rocsat` |
| MIT | 7 | 11% | 2 | 2 | 3 | 0 | 0 | `faldor20/tree-sitter-roc`, `ivan-demchenko/roc-vscode-unofficial`, `h2000/zed-roc`, `lukewilliamboswell/roc-fuzz` |
| GPL-3.0 | 3 | 5% | 2 | 0 | 1 | 0 | 0 | `~jwoudenberg/roc` (gregorian, rvn), `Hasnep/pre-commit-roc` |
| AGPL-3.0 | 1 | 2% | 0 | 1 | 0 | 0 | 0 | `removewingman/restricted-roc` |
| none | 3 | 5% | 1 | 0 | 1 | 1 | 0 | `lukewilliamboswell/weaver` (fork of `smores56/weaver`, also none), `grayrest/roc-just`, `lukewilliamboswell/aoc` |
| Total | 61 | 100% | 35 | 13 | 9 | 2 | 2 | |

| Measure | UPL-1.0 | Apache-2.0 | MIT | Other |
| --- | --- | --- | --- | --- |
| Share of entries | 46% | 31% | 11% | 12% |
| Share of stars, `roc-lang/roc` included (6,844 stars; the 2 sr.ht entries have no star count) | 97% | 1% | 2% | 0% |
| Share of stars, `roc-lang/roc` not included (726 stars) | 76% | 8% | 15% | 1% |
| Owners that use it (18 owners) | 5 (`roc-lang`, `lukewilliamboswell`, `Hasnep`, `kili-ilo`, `thebrandonlucas`) | 3 (`niclas-ahden`, `jaredramirez`, `mpizenberg`) | 6 (`faldor20`, `grayrest`, `h2000`, `ivan-demchenko`, `obust`, `lukewilliamboswell`) | 3 GPL or AGPL, 2 none |
| Official `roc-lang` entries in the list (10) | 10 | 0 | 0 | 0 |
| Platforms (13) | 9 | 1 | 2 | 1 |

Apache-2.0 is in 17 of 19 cases one owner (`niclas-ahden`). Without that owner, UPL-1.0 is 28 of 44 entries (64%).

## 2. Notes on single repositories

| Repository | Note |
| --- | --- |
| `lukewilliamboswell/roc-pdf` | GitHub shows `NOASSERTION`. The file is UPL-1.0, but the last sentence of the disclaimer is cut (it stops at "OR OTHERWISE."). So GitHub does not match it. The `roc-lang/roc` text matches. |
| `thebrandonlucas/kai` | GitHub shows `NOASSERTION`. The file is UPL-1.0 with an extra line: "Portions (platform/, ...) from roc-blueprint Copyright © 2026 Luke Boswell". An example of how to credit code copied from another UPL-1.0 project. |
| `lukewilliamboswell/weaver` | Fork of `smores56/weaver`. No LICENSE in the fork or the parent. |
| `lukewilliamboswell/embed-roc-in-dotnet` | Fork of `johan0A/embed-roc-in-zig-example` (UPL-1.0). |
| `~jwoudenberg/roc` | One sr.ht repository with many packages. Root `LICENSE` is GPL-3.0. No `LICENSE` in `gregorian/` (HTTP 404). The tree listing is behind a bot check (HTTP 418), so other files in the subdirectories were not checked. |
| `removewingman/restricted-roc` | Codeberg API gives no license. The root `LICENSE` file is AGPL-3.0. |

## 3. All entries

Kind is the section of the list. `compiler` is the top part of the list.

| Kind | Repository | License | Stars | Last push |
| --- | --- | --- | --- | --- |
| compiler | roc-lang/roc | UPL-1.0 | 6118 | 2026-10-16 |
| compiler | roc-lang/nightlies | UPL-1.0 | 5 | 2026-10-15 |
| package | grayrest/roc-regex | MIT | 0 | 2026-09-12 |
| package | Hasnep/roc-ascii | UPL-1.0 | 6 | 2026-09-04 |
| package | jaredramirez/roc-redis | Apache-2.0 | 0 | 2026-09-15 |
| package | ~jwoudenberg/roc (gregorian), git.sr.ht | GPL-3.0 | | |
| package | ~jwoudenberg/roc (rvn), git.sr.ht | GPL-3.0 | | |
| package | kili-ilo/roc-random | UPL-1.0 | 10 | 2026-10-15 |
| package | lukewilliamboswell/roc-ansi | UPL-1.0 | 14 | 2026-10-16 |
| package | lukewilliamboswell/roc-blueprint | UPL-1.0 | 0 | 2026-10-14 |
| package | lukewilliamboswell/roc-graph-layout | UPL-1.0 | 0 | 2026-10-15 |
| package | lukewilliamboswell/roc-parser | UPL-1.0 | 32 | 2026-10-16 |
| package | lukewilliamboswell/roc-pandoc | UPL-1.0 | 2 | 2026-10-15 |
| package | lukewilliamboswell/roc-pdf | UPL-1.0 (GitHub: NOASSERTION) | 1 | 2026-10-16 |
| package | lukewilliamboswell/roc-time | UPL-1.0 | 0 | 2026-10-15 |
| package | lukewilliamboswell/weaver | none | 1 | 2026-10-11 |
| package | mpizenberg/rocsat | Apache-2.0 | 0 | 2026-08-24 |
| package | niclas-ahden/joy-html | Apache-2.0 | 0 | 2026-10-03 |
| package | niclas-ahden/roc-base64 | Apache-2.0 | 0 | 2026-08-20 |
| package | niclas-ahden/roc-crc32 | Apache-2.0 | 1 | 2026-08-17 |
| package | niclas-ahden/roc-database-url | Apache-2.0 | 0 | 2026-09-22 |
| package | niclas-ahden/roc-deflate | Apache-2.0 | 0 | 2026-09-14 |
| package | niclas-ahden/roc-hmac | Apache-2.0 | 0 | 2026-09-14 |
| package | niclas-ahden/roc-human-readable-file-size | Apache-2.0 | 0 | 2026-08-17 |
| package | niclas-ahden/roc-maybe | Apache-2.0 | 0 | 2026-09-22 |
| package | niclas-ahden/roc-non-zero | Apache-2.0 | 0 | 2026-08-17 |
| package | niclas-ahden/roc-playwright | Apache-2.0 | 1 | 2026-10-04 |
| package | niclas-ahden/roc-prng | Apache-2.0 | 0 | 2026-09-17 |
| package | niclas-ahden/roc-spec | Apache-2.0 | 0 | 2026-10-04 |
| package | niclas-ahden/roc-url | Apache-2.0 | 3 | 2026-08-17 |
| package | niclas-ahden/roc-xlsx | Apache-2.0 | 1 | 2026-10-11 |
| package | niclas-ahden/roc-xml | Apache-2.0 | 1 | 2026-10-10 |
| package | niclas-ahden/roc-zip | Apache-2.0 | 0 | 2026-09-14 |
| package | obust/terrocotta | MIT | 7 | 2026-10-13 |
| package | roc-lang/http | UPL-1.0 | 13 | 2026-10-01 |
| package | roc-lang/path | UPL-1.0 | 7 | 2026-10-01 |
| package | roc-lang/unicode | UPL-1.0 | 15 | 2026-10-15 |
| platform | grayrest/roc-tower-platform | MIT | 1 | 2026-08-31 |
| platform | lukewilliamboswell/basic-ssg | UPL-1.0 | 10 | 2026-10-15 |
| platform | lukewilliamboswell/roc-fuzz | MIT | 1 | 2026-10-12 |
| platform | lukewilliamboswell/roc-platform-template-go | UPL-1.0 | 13 | 2026-10-15 |
| platform | lukewilliamboswell/roc-platform-template-rust | UPL-1.0 | 10 | 2026-10-15 |
| platform | lukewilliamboswell/roc-platform-template-zig | UPL-1.0 | 21 | 2026-10-15 |
| platform | lukewilliamboswell/roc-ray | UPL-1.0 | 76 | 2026-10-15 |
| platform | lukewilliamboswell/roc-signals | UPL-1.0 | 4 | 2026-10-11 |
| platform | lukewilliamboswell/roc-wasm4 | UPL-1.0 | 69 | 2026-10-15 |
| platform | niclas-ahden/joy | Apache-2.0 | 48 | 2026-10-07 |
| platform | removewingman/restricted-roc, codeberg.org | AGPL-3.0 | 1 | 2026-10-13 |
| platform | roc-lang/basic-cli | UPL-1.0 | 122 | 2026-10-13 |
| platform | roc-lang/basic-webserver | UPL-1.0 | 108 | 2026-10-15 |
| tool | faldor20/tree-sitter-roc | MIT | 58 | 2026-10-15 |
| tool | grayrest/roc-just | none | 0 | 2026-08-24 |
| tool | h2000/zed-roc | MIT | 14 | 2026-08-23 |
| tool | Hasnep/pre-commit-roc | GPL-3.0 | 3 | 2026-08-10 |
| tool | ivan-demchenko/roc-vscode-unofficial | MIT | 26 | 2026-01-12 |
| tool | lukewilliamboswell/embed-roc-in-dotnet | UPL-1.0 | 0 | 2026-10-08 |
| tool | roc-lang/release-package | UPL-1.0 | 1 | 2026-08-08 |
| tool | roc-lang/roc-overlay | UPL-1.0 | 3 | 2026-10-16 |
| tool | roc-lang/setup-roc | UPL-1.0 | 2 | 2026-07-07 |
| app | lukewilliamboswell/aoc | none | 6 | 2026-07-15 |
| app | thebrandonlucas/kai | UPL-1.0 (GitHub: NOASSERTION) | 9 | 2026-10-15 |

## 4. All repositories of the `roc-lang` organization

| Group | License | Repositories |
| --- | --- | --- |
| Own code, active | UPL-1.0 (14) | roc, nightlies, basic-cli, basic-webserver, http, path, unicode, release-package, roc-overlay, setup-roc, roc-bootstrap, roc-compiler-fuzz, roc-playground, www.roc-lang.org |
| Own code, archived | UPL-1.0 (2), NOASSERTION (1) | rbt, roc-script; book-of-examples |
| Examples | CC0-1.0 (1) | examples |
| No code | none (4) | design-assets, rfcs, zulip-export, homebrew-roc |
| Forks of other projects | Apache-2.0 (2), MIT (2), GPL-2.0 (1) | inkwell, llvm-package-windows; rustyline, wasm3-rs; zig-kcov |

## 5. Terms of the roc license

From `roc-lang/roc` `LICENSE` and `legal_details`:

| Item | Value |
| --- | --- |
| License | UPL-1.0. Third-party code (for example `vendor/ena`, Apache-2.0) is listed in `legal_details`. |
| Copyright line | `Copyright © 2019 Richard Feldman and subsequent Roc authors <roc-lang.org/authors>` |
| basic-cli line | `Copyright © 2022 Richard Feldman and subsequent basic-cli authors <github.com/roc-lang/basic-cli/graphs/contributors>` |
| Contributor agreement | None. "No copyright assignment is required to contribute." Copyright stays with each contributor. |
| Commit rule | Signed commits (`CONTRIBUTING/README.md`, "Commit signing"). No DCO sign-off. |
| Condition | The copyright notice and the license (or the Larger Works notice) are in all copies or substantial portions. |
| basic-cli binaries | basic-cli has `THIRD_PARTY_LICENSES.md` for the Rust crates of its host. |

## 6. Code in Talon that comes from other projects

Method: each tracked `.zig`, `.roc`, `.js`, `.mjs`, `.sh`, `.c`, `.rs` file of this repository and of the `cloudflare-workers` submodule, compared line by line (lines of 30 characters or more, white space removed) with the roc source at `7d256b9546`, `roc-platform-template-zig` and `workers-zig`. A grep for "license", "copyright", "SPDX", "copied from", "adapted from", "ported from".

| File | Lines equal to the source | Source | Result |
| --- | --- | --- | --- |
| `cloudflare-workers/host/ZigGlue.roc` | 1229 of 1229 | `roc:src/glue/src/ZigGlue.roc` (2643 lines, same file) | Verbatim copy, no notice. UPL-1.0, Roc authors. |
| `cloudflare-workers/host/roc_platform_abi.zig` | 32 of 533 (roc), 484 of 533 (template) | Output of `roc glue` with that `ZigGlue.roc` | Generated. It contains the fixed text of the glue script. |
| `cloudflare-workers/research/api-probe/cbor/Cbor.roc`, `cbor/CborRows.roc`, `modules-check/Cbor.roc` | 11 to 12 of about 300 | Codec interface names of the roc builtins | Interface lines only. Not a copy. |
| `install/install.sh`, `install/install.ps1` | 0 and 3 (PowerShell preamble lines) | `imclerran/rocup` (no license) | The comment says "The structure follows the rocup installer". No code copied. |
| All other files of this repository | fewer than 5 | | No copy found |

## 7. Commands

```sh
gh api rate_limit --jq '.resources.core'
gh api repos/lukewilliamboswell/roc-awesome/commits/main --jq '.sha[0:7]+" "+.commit.committer.date'
gh api repos/lukewilliamboswell/roc-awesome/contents/README.md -H "Accept: application/vnd.github.raw" > awesome.md

# entries: the first link of each "- " line, with the "## " section as the kind;
# github.io -> github.com/<owner>/<repo>; sr.ht and codeberg kept as they are
python3 -I parse.py awesome.md > entries.txt

grep ' github.com/' entries.txt | while read k r; do
  gh api "repos/${r#github.com/}" --jq '[.full_name, (.license.spdx_id // "none"),
    (.stargazers_count|tostring), (.archived|tostring), .pushed_at[0:10], (.fork|tostring)] | @tsv'
done > gh.tsv

# NOASSERTION and none
gh api repos/lukewilliamboswell/roc-pdf/license -H "Accept: application/vnd.github.raw"
gh api repos/thebrandonlucas/kai/license -H "Accept: application/vnd.github.raw"
gh api repos/lukewilliamboswell/weaver --jq '.parent.full_name + " " + (.parent.license.spdx_id // "none")'
gh api repos/{owner}/{repo}/contents --jq '.[].name'     # weaver, roc-just, aoc, smores56/weaver

# off GitHub
curl -sfL https://git.sr.ht/~jwoudenberg/roc/blob/main/LICENSE
curl -sf  https://codeberg.org/removewingman/restricted-roc/raw/branch/main/LICENSE

# the roc-lang organization
gh api --paginate 'orgs/roc-lang/repos?per_page=100' \
  --jq '.[] | [.name, (.license.spdx_id // "none"), (.archived|tostring), (.fork|tostring), (.stargazers_count|tostring)] | @tsv'

# copied code: line overlap of tracked files with a source tree
python3 -I overlap.py <source tree> . cloudflare-workers
grep -rnIiE '\b(licen[cs]e|copyright|SPDX|adapted from|copied from|ported from)\b' . --exclude-dir=.git
```

The two helper scripts, as they were run:

```python
# parse.py <awesome.md>: print "<kind> <repo id>" for each list entry
import re,sys
kind={'Roc Packages':'package','Roc Platforms':'platform','Tools':'tool','Roc Applications':'app'}
sec='top'; seen=set()
for line in open(sys.argv[1]):
    m=re.match(r'^## (.*)',line)
    if m: sec=kind.get(m.group(1).strip(),m.group(1)); continue
    if not line.startswith('- '): continue
    m=re.search(r'\]\((https?://[^)]+)\)',line)
    if not m: continue
    u=m.group(1)
    g=re.match(r'https?://github\.com/([^/]+)/([^/#?]+)',u)
    if g: rid=f"github.com/{g.group(1)}/{g.group(2)}"
    elif 'github.io' in u:
        o=re.match(r'https?://([^.]+)\.github\.io/([^/]+)',u); rid=f"github.com/{o.group(1)}/{o.group(2)}"
    elif 'git.sr.ht' in u:
        o=re.match(r'https?://git\.sr\.ht/(~[^/]+)/([^/]+)/tree/main/item/([^/]+)',u); rid=f"git.sr.ht/{o.group(1)}/{o.group(2)}#{o.group(3)}"
    elif 'codeberg' in u:
        o=re.match(r'https?://codeberg\.org/([^/]+)/([^/]+)',u); rid=f"codeberg.org/{o.group(1)}/{o.group(2)}"
    else: continue
    k='compiler' if sec=='top' else sec
    if rid in seen: continue
    seen.add(rid); print(k, rid)
```

```python
# overlap.py <source tree> <git repo>...: files with 5 or more lines equal to a line of the source tree
import os,sys,subprocess,collections
roc=sys.argv[1]; repos=sys.argv[2:]
def norm(l): return ' '.join(l.split())
rocset=set()
for dp,dn,fn in os.walk(roc):
    if '.git' in dp: continue
    for f in fn:
        if not f.endswith(('.zig','.roc','.js','.mjs','.sh','.c','.rs')): continue
        try:
            for l in open(os.path.join(dp,f),errors='ignore'):
                n=norm(l)
                if len(n)>=30: rocset.add(n)
        except: pass
for r in repos:
    files=subprocess.run(['git','-C',r,'ls-files'],capture_output=True,text=True).stdout.split()
    for f in files:
        if not f.endswith(('.zig','.roc','.js','.mjs','.sh','.c','.rs')): continue
        p=os.path.join(r,f)
        try: lines=[norm(l) for l in open(p,errors='ignore')]
        except: continue
        lines=[l for l in lines if len(l)>=30]
        if not lines: continue
        hit=sum(1 for l in lines if l in rocset)
        if hit>=5: print(f"{hit:5d}/{len(lines):5d} {r}/{f}")
```
