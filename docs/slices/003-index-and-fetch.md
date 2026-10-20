# 003 Index and fetch

Phase: P0. Status: verify

Slice 003 makes the decisions and the I/O for the `direct` index (the GitHub release list), the package fetch (download, hash check, extract into `packages/<hash>/`), the download adapter (curl or wget), and the network variables. It also builds the fake HTTP server for L3. No command uses these modules yet: the P0 commands are slice 007. `flowprobe` stands in for them (new flows `releases`, `hint`, `fetch`).

## Rules

| Group | Ids | Design | Where tested |
| --- | --- | --- | --- |
| Index, `direct` | R-DI2 to R-DI6, R-DI8 to R-DI13, R-DI15 | CLI 7.3 | `index.roc`, `github.roc`, L2 `index/di-list-flow`, L3 `index/di1-github-pages` |
| Fetch pipeline | R-FE1 to R-FE5, R-FE7, R-FE8, R-FE10 (the audit form) | CLI 7.1, 7.2 | `fetch.roc`, L2 `fetch/fe-flow`, L3 `fetch/fe1-loopback-fetch` |
| Download adapter | R-DA1 to R-DA7 | CLI 7.5 | `download.roc`, L2 `fetch/fe-flow`, L3 `fx/dl1-real-fx-jobs` |
| Archive tools | R-HF4, R-HF5, R-HF12 (the download and unbundle parts) | Design 6.2 | `download.roc`, `fetch.roc`, L3 `fetch/fe1-loopback-fetch`, `fx/dl1-real-fx-jobs` |
| Registry precedence | R-RG1 to R-RG3 | CLI 1 | `net.roc`, L2 `index/rg3-token-sources` |
| Variables | R-EV2, R-EV3, R-EV12, R-EV14, R-EV15, R-EV19, R-EV20, R-EV23 to R-EV25 | CLI 1 | `net.roc`, L2 `index/*`, L3 `index/di1-github-pages`, `fetch/fe1-loopback-fetch` |
| No lock | R-CC11 (`packages/<hash>/`, `talon/index/`) | CLI 7.4 | L2 and L3 cases above (no `lock` call, no `.lock` dir) |

## Files

| Path | Writer | State |
| --- | --- | --- |
| `cli/lib/Net.roc` (53 lines), `Download.roc` (51), `Fetch.roc` (71), `Index.roc` (72), `Github.roc` (112) | Stubs from the test agent. Bodies from the code agent. | Compile. Bodies are `crash "todo"`. The contract is in the doc comments. |
| `cli/lib/Fx.roc` | Test agent (types, wrappers) | 6 new fields and wrappers: `http_get!`, `programs!`, `spawn_all!`, `rename!`, `make_dirs!`, `random!` |
| `cli/lib/Clock.roc` | Test agent | New stub `format_utc` |
| `cli/lib/main.roc` | Test agent | 5 new names in the exposes list |
| `cli/RealFx.roc` | Test agent. `http_get!`, `programs!`, `rename!`, `make_dirs!`, `random!` are done (no Talon logic). | `spawn_all!` is a stub (the code agent writes it, see Notes) |
| `cli/main.roc`, `cli/fxprobe.roc`, `cli/flowprobe.roc` | Test agent | Package entry `http` (roc-lang/http 1.0.0). `fxprobe`: 6 new calls. `flowprobe`: 3 new flows. |
| `tests/unit/{net,download,fetch,github,index}.roc` | Test agent | 19 `expect`s, red ("todo") |
| `tests/commands/FakeFx.roc`, `tests/commands/main.roc` | Test agent | The fake has the 6 new calls (tables `fx/http/`, `fx/programs`, `fx/jobs`, `fx/rename`, `fx/random`, `fx/mtimes`). New entries `index` and `fetch`. |
| `tests/commands/cases/index/{di-list-flow,rg3-token-sources}/`, `fetch/fe-flow/` | Test agent | 3 L2 cases, red |
| `tests/scenarios/fetch/fe1-loopback-fetch/`, `index/di1-github-pages/`, `fx/dl1-real-fx-jobs/` | Test agent | 3 L3 cases, red |
| `tests/tools/fakehttp.py` (164), `tests/tools/with-http.sh` (35) | Test agent | The fake HTTP server (TESTING.md 3.2). Done, with selftest. |
| `tests/run.sh`, `tests/lib.sh`, `tests/fakes/roc`, `tests/selftest.sh`, `tests/selftest/commands/pass/harness/fake-fx/` | Test agent | The runner starts the server when a case has `given/http/`. `http.log` is compared. `127.0.0.1:<port>` is normalized. The fake `roc` can pass a call to the pinned `roc` (`real` in `roc.tsv`). Selftest has 3 new cases (`runner/http`, `runner/roc-real`, must-fail `http-log`). |
| `tests/fixtures/pkgs/` | Test agent | `make.sh` (the pinned `roc bundle`), `src/{greet,shout}/`, 2 archives, `hashes.txt`. The build is deterministic. |

## Public signatures

### Fx (`cli/lib/Fx.roc`)

| Call | Type | Real `Fx` |
| --- | --- | --- |
| `http_get!` | `{ url, headers : List((Str, Str)) } => Try({ status : U16, headers : List((Str, Str)), body : Str }, [Timeout, Failed(Str)])` | `Http.send!` with a 20 s timeout. A status of 400 or more is an answer. Done. |
| `programs!` | `List(Str) => List(Bool)` | `Cmd.check_available!`. Done. |
| `spawn_all!` | `{ jobs : List({ argv, cwd : Try(Str, [Inherit]) }), limit : U64 } => List({ ended : [Exited(I32), Signaled(I32), NotStarted(Str)], stdout : Str, stderr_last : Str })` | Stub. R-DA5, R-CC12. |
| `rename!` | `{ from, to } => Try({}, [NotFound, Exists, Denied, Other(Str)])` | Done. A target that exists, or a dir that is not empty, is `Exists`. |
| `make_dirs!` | `List(Str) => Try({}, [Denied, Other(Str)])` | Done. A dir that exists is `Ok`. |
| `random!` | `() => U64` | Done. |

### Pure decisions and command code

| Module | Functions | Rules |
| --- | --- | --- |
| `Net` | `from_env`, `registry`, `token_from_gh`, `token`, `headers` | R-EV2, R-EV3, R-EV12, R-EV14, R-EV15, R-EV19, R-EV20, R-RG1 to R-RG3, R-DI9 |
| `Download` | `choose`, `command`, `outcome`, `check_url` | R-DA2, R-DA3, R-DA6, R-DA7, R-FE8, R-EV12, R-EV25 |
| `Fetch` | `plan`, `download_failed`, `unbundle_failed`, `offline_missing`, `packages!` (command code) | R-FE1 to R-FE5, R-FE7, R-FE8, R-FE10, R-DA4, R-DA5 |
| `Index` | `candidates`, `in_group`, `new_entry`, `order`, `host_kind`, `fixed_line` | R-DI3 to R-DI6, R-DI9 to R-DI11, R-DI15 |
| `Github` | `list_url`, `hint_url`, `hint`, `repo_dir`, `page_files`, `meta_text`, `parse_meta`, `next_link`, `plan`, `rate_limit`, `rate_limit_failure`, `network_failure`, `status_failure`, `offline_line`, `releases!`, `hint!` (command code) | R-DI2, R-DI8, R-DI12, R-DI13, R-CC11 |
| `Clock` | `format_utc` | R-DI12, R-DI13 |

## Tests

| Layer | File or case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 (2) | `tests/unit/net.roc` | settings from env (incl. the test hook), registry precedence, `gh` token, headers | R-EV2, R-EV3, R-EV12, R-EV14, R-EV15, R-EV19, R-EV20, R-RG1 to R-RG3 |
| L0 (4) | `tests/unit/download.roc` | `choose`, `command`, `outcome` for curl and wget, `check_url` | R-DA2, R-DA3, R-DA7, R-FE8, R-EV12, R-EV25, R-HF4 |
| L0 (2) | `tests/unit/fetch.roc` | `plan` (temp and item paths, `what`), the four failure texts | R-FE2, R-FE3, R-FE7, R-FE8, R-FE10, R-DA4, R-HF12 |
| L0 (5) | `tests/unit/github.roc` | URLs, meta round trip, `Link`, `plan` (60 s, ETag, offline), `rate_limit`, failure texts, `hint`, `format_utc` for 2000 and 2100 | R-DI2, R-DI8, R-DI12, R-DI13 |
| L0 (6) | `tests/unit/index.roc` | `candidates` (draft, prerelease, asset names, base58 check, 2 assets, size, time), re-release, bad page, `in_group`, `new_entry`, `order`, `host_kind` | R-DI3 to R-DI6, R-DI9 to R-DI11, R-DI15, R-DA6 |
| L2 | `index/di-list-flow` (12 runs) | calls and results of `Github.releases!` and `hint!`: fresh, stale with 304, 2 pages with a token, rate limit on page 1 and on page 2, no answer, timeout, offline, nothing cached, 3 hints | R-DI2, R-DI8, R-DI9, R-DI12, R-DI13, R-EV3, R-EV20, R-RG3, R-CC11 |
| L2 | `index/rg3-token-sources` (3 runs) | `gh auth token` is the third source, `GH_TOKEN`, the test API sends no token | R-RG3, R-EV3, R-EV14, R-EV19, R-DI9 |
| L2 | `fetch/fe-flow` (9 runs) | calls of `Fetch.packages!`: one item, present, 3 URLs in one `spawn_all` with a 404, a hash mismatch and a lost rename, offline, wget, bad downloader, bad scheme, roc not started | R-FE1 to R-FE5, R-FE7, R-FE8, R-FE10, R-DA2, R-DA3, R-DA5, R-DA7, R-EV12, R-EV24, R-HF4, R-HF12 |
| L3 | `fetch/fe1-loopback-fetch` | the real `tln` code path (`flowprobe fetch`) with real curl, real wget, the real `roc unbundle`, and a loopback server: success, present, bad hash (16), 404 with curl and wget (15), scheme (2), offline (15), mixed, no downloader (18) | R-FE2 to R-FE5, R-FE8, R-FE10, R-DA2 to R-DA4, R-DA7, R-HF4, R-HF5, R-HF12, R-EV12, R-EV23, R-EV25, R-CC11 |
| L3 | `index/di1-github-pages` | 2 pages with `Link`, 60 s, 304 renewal, offline, re-release, rate limit, no answer, hint. `http.log` has no `authorization` (R-EV19). | R-DI2 to R-DI5, R-DI8 to R-DI10, R-DI12, R-DI13, R-DI15, R-DA1, R-DA6, R-EV3, R-EV14, R-EV15, R-EV19, R-EV20, R-CC11 |
| L3 | `fx/dl1-real-fx-jobs` | the jobs of the real `Fx` with `fxprobe`: `http_get!`, `programs!`, `make_dirs!`, `rename!`, `random!`, `spawn_all!` (exit, signal, not found, cwd, limit 8 with 10 slow jobs: the server sees 8 at the same time), a lock kept while a child runs | R-HF4, R-DA1, R-DA5, R-DA7, R-CC3, R-CC12, R-FE3, TW4 |

## Output (proposed, R-OUT2, TW24)

| Where | Text |
| --- | --- |
| Rate limit | `tln: error[network]: GitHub API rate limit reached. It resets at <time>. Set GITHUB_TOKEN or GH_TOKEN, or log in with gh (gh auth login).` Without a time: no `It resets at ...`. |
| No answer | `tln: error[network]: cannot reach <url>: <why>. Use --offline to work with the cached index.` `why`: `no answer in 20 s`, or the text of the platform (`client error (Connect)`). |
| Other status | `tln: error[network]: GitHub answered <status> for <url>` |
| Offline | `index: cached at <time>` (stderr, once) |
| Warnings | `warning: <owner>/<repo> <tag>: the release has 2 package assets (<hash>, <hash>). It is not a candidate.` and `warning: ... has the hash <new>, but Talon knows <URL> with the hash <old>. It is not a candidate.` |
| 404 of an archive | `tln: error[network]: download of <what> failed: 404 (<url>). Run tln audit to see why.` With wget: `HTTP error` in place of `404`. |
| Download or roc not started | `tln: error[environment]: cannot run <program>: <text>`. No program: `no download program: curl and wget are not on PATH`. |
| Bad hash | `tln: error[integrity]: roc unbundle rejected <what> (<url>): <last line of roc>` |
| Offline, not cached | `tln: error[network]: <what> is not in the package cache and --offline is set (<url>)` |
| Bad URL, bad downloader | `tln: error[usage]: <url>: a package URL must be https://, or http:// to 127.0.0.1, [::1] or localhost`, `TALON_DOWNLOADER must be curl or wget, not '<text>'`, `<url> is not a package release URL` |
| Cache pages | `<cache>/talon/index/github/<owner>/<repo>/<n>.json` (the body as it came) and `<n>.meta` (`etag <ETag>`, `next <URL>`). Written in one `write_atomic!` after the last page. |
| `flowprobe releases` | `candidate <version> <time> <size> <url>`, `no cached page`, `source: ...`, `pages: [...]` (L2 entry) |
| `flowprobe hint`, `fetch` | `hint <id>`, `no hint`, `fetched <url>`, `present <url>`. The exit code is `Exit.choose`. |
| `fxprobe` | one line for each result: `status`, `header`, `body`, `err`, `<name> yes/no`, `job <i> <ended> stdout=.. stderr_last=..`, `renamed`, `made`, `random ok` |

## Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | The fake HTTP server runs inside the sandbox for each case (the network namespace has only loopback). The case has `given/http/` routes. `$PORT` is replaced in bodies and headers, and normalized in output. | A server outside the sandbox with a unix socket. One server for the whole run (cases would share state and `http.log`). |
| D2 | `http_get!` gives status, headers and body. A 4xx or 5xx is an answer, not an error. | A `Try` on the status. A streaming body. |
| D3 | The download is a child process of `spawn_all!` (curl or wget), with one `limit`. The same call runs `gh auth token` and `roc unbundle`. | A separate `download!` call in `Fx`. It would need its own fake and its own limit. |
| D4 | `rename!` has `Exists` for "target is there or not empty". `Fetch` treats it as `Fetched` (R-FE3). | A lock for `packages/<hash>/`: R-CC11 says no lock. |
| D5 | The cache pages are 2 files for each page (body and meta). The age is the mtime of the meta file. A 304 writes the meta again to renew the age. | One file for each repository. The age in the body. |
| D6 | All pages are written in one `write_atomic!` after the last page. A failure at any page writes nothing. | A write after each page: a failure on page 2 would leave a new page 1 with an old page 2. |
| D7 | The temp dir is `<pkgs>/<hash>.<16hex>.tmp` and holds the archive and the extracted dir. It is deleted at the end, also after a success. | A temp dir outside `packages/` (a rename across file systems can fail: R-DA4). |
| D8 | `Fetch.packages!` makes one `random!` call for all URLs. All downloads of a call go in one `spawn_all!` (no waterfall, R-FE1). | A call for each URL. |
| D9 | The candidate list keeps the page order. `new_entry` takes the newest by `published_at`, the first one wins a tie. `order` compares the `X.Y.Z` as numbers. | The order of the tags. |
| D10 | L3 uses the real `roc unbundle` through the fake `roc` (`real` in `roc.tsv`). The fixture archives are made by the pinned `roc bundle` (`tests/fixtures/pkgs/make.sh`). | A fake archive: it could not show a hash mismatch. |
| D11 | The `.roc-version` hint request has no token (R-DI9, R-EV20). A 404 is `NoHint`. | A token on every request to GitHub. |

## Out of scope

| Id | Reason |
| --- | --- |
| R-DI1 | A rule about which command lists a group. No command exists yet (slice 007). `Github.releases!` is the only call. |
| R-DI7 | The lazy oracle reads the header of the extracted package (Resolution 5). It is the solver slice. This slice only fetches and extracts. |
| R-FE9 | A conformance test against each new nightly (roc rescans a package with no sidecar). It needs a real `roc check`. It belongs to the nightly checks, not the fast set. |
| R-FE6, R-FE10 (the registry reason) | Mirrors and the release state of a hash are P2. The audit form of R-FE10 is tested. |
| R-RG4 to R-RG6 | P2 (registry). |
| R-DI14 | The registry form of a candidate. `Candidate` has the same fields. |
| R-EV1, R-EV4 to R-EV11, R-EV13, R-EV16 to R-EV18, R-EV21, R-EV22, R-EV26 | Other slices or P1 and later. |

## Questions (stop until answered, TW17)

Each question has a default. The tests use the default. The code agent keeps it until the human answers.

| # | Question | Default (tested) | Other option |
| --- | --- | --- | --- |
| Q1 | The URL of a candidate: from where? | `browser_download_url` of the asset, as the answer gives it | Build `https://github.com/<owner>/<repo>/releases/download/<tag>/<name>` |
| Q2 | An answer that is not 200, 304 or a rate limit (for example 500, 404 of the list) | Exit 15, `GitHub answered <status> for <url>` | Exit 2 for a 404 of the list (the repository does not exist) |
| Q3 | `wget --quiet` gives no status. | The text is `HTTP error`, exit 15 | Run `wget` without `--quiet` and read its text (the output depends on the version) |
| Q4 | `TALON_DOWNLOADER` has another value | Usage failure, exit 2 | Ignore it and use `Auto` |
| Q5 | GitHub needs a `User-Agent` header. The value? | `tln/<Help.version>` | A name with the project URL |
| Q6 | The kind and the exit code of a URL that roc refuses | Usage, exit 2, no request | Network, exit 15 |
| Q7 | The name in a message for a URL that is not from GitHub | The URL form with `{v}` for the version, no scheme, no `/` at the end | The full URL |
| Q8 | A URL with no hash or no single version | Usage, `<url> is not a package release URL` | The same as Q6 |
| Q9 | The text of an offline run for a package that is not cached | `<what> is not in the package cache and --offline is set (<url>)`, exit 15 | Exit 2 |
| Q10 | Temp dir of a successful fetch | Deleted at the end, in one `delete!` for all URLs | Left for GC (R-GC) |

## Design gaps

| # | Gap |
| --- | --- |
| G1 | R-DI4 says the name is base58 of 32 bytes. `PackageUrl.parse` does not check the hash characters. The check is Talon's own (`roc-base58` `Base58.decode`, 32 bytes). The real tree has no `base58` package entry yet. |
| G2 | `JsonDoc.parse` (slice 001) rejects numbers that are not integers. A real GitHub page can have such a number in a field that Talon does not read. The code agent must not fail on an unread field. |
| G3 | The text `client error (Connect)` of a failed request is the text of the pinned basic-cli (0.25.0). A new platform version can change it. |
| G4 | The design gives no cache layout for index pages (R-DI2 says only "cached"). D5 is a proposal. |

## Compiler and syntax limits found

| Limit | Effect |
| --- | --- |
| A top-level value that calls a stub fails at check time | Tests build rows in the `expect` body. |
| A lambda parameter cannot have the name of a method of the same module | `plan` as a parameter inside `Fetch` needs another name. |
| An effectful lambda cannot go in `map` | Use a `for` loop. |
| `{ x }` alone is a block, not a record | Write `{ x: x }` or give a second field. |
| `Str` has no sort | `Text.sorted` |
| `Cmd.Child` has no `is_eq` | Compare with a helper (`is_running`). |
| `roc fmt` on the fixture sources changes the bundle hash | `make.sh` bundles the sources as they are. They are not formatted. |
| `roc unbundle` extracts into `./<hash>/` and leaves a partial dir on failure | `Fetch` runs it in the temp dir and deletes the temp dir. |

## Red output

The fast set with the stubs (`scripts/test.sh`, 65 s, under the 3 minutes of TW20):

| Step | Result | Reason |
| --- | --- | --- |
| check, fmt, selftest | pass | |
| L0 old files | pass | |
| L0 new files (19 expects) | red | `Roc application crashed ... todo` in each |
| L2 `index/di-list-flow`, `index/rg3-token-sources`, `fetch/fe-flow` | red | `[ROC CRASHED] todo`, no exit file |
| L2 old cases | pass | |
| L3 `index/di1-github-pages`, `fetch/fe1-loopback-fetch` | red | exit 1 and `[ROC CRASHED] todo`, expected output missing |
| L3 `fx/dl1-real-fx-jobs` | red | the lines for `http_get!`, `programs!`, `make_dirs!`, `rename!` and `random!` pass. Only `spawn_all!` (stub) fails: `[ROC CRASHED] todo`. |
| L3 old cases | pass | |

## Check against the design (TW21)

The expected output of each L2 and L3 case was made by a private reference implementation, and then read by eye against the design. The reference is deleted (TW18). The whole fast set was green with it (L0 19 of 19, L2 8 of 8, L3 16 of 16, selftest 24 of 24 on the harness).

Revert and mutation check (TW12), on the reference. Each row is one change of the code. The tests then fail.

| Layer | Changes that the tests catch | Count |
| --- | --- | --- |
| L0 `index` | draft counted, prerelease counted, any base58 length, 2 assets not skipped, re-release by hash or version or group not compared, `Highest` reversed, `new_entry` oldest, `new_entry` one series, host by prefix | 11 of 11 |
| L0 `github` | 60 s is fresh, offline fetches, `retry-after` ignored, any 403 is a limit, first `Link`, no ETag in meta, 404 of hint is a failure | 7 of 7 |
| L0 `net` | test API keeps the token plan, `GH_TOKEN` before `GITHUB_TOKEN`, token with the test API, env before flag | 4 of 4 |
| L0 `download` | wget before curl, no `--proto-redir`, wget exit 8 is not an HTTP error, loopback by prefix | 4 of 4 |
| L0 `fetch` | temp name with no hex, no `audit` hint, unbundle failure is `Network` | 3 of 3 |
| L2 | `limit: 4`, temp dir not deleted, `Exists` is a failure, 304 does not renew the meta, ETag never sent, offline calls the network | 6 of 6 |
| L3 | 304 does not renew the meta (caught in both L2 and L3) | 1 of 1 |

One flake was found and fixed in the harness: the server wrote a Python traceback to the stderr of a case when curl or wget reset a connection (`handle_error` is now silent), and a slow body of 300 ms gave 7 requests at the same time instead of 8 (now 600 ms).

`MISSING=1 scripts/rules.sh R-DI R-FE R-DA R-RG R-EV R-HF R-CC` lists only ids that are in the table "Out of scope" or that belong to other slices.

## Notes for the code agent

| # | Note |
| --- | --- |
| N1 | Add the package entry `base58` (roc-base58 release URL, never a path entry, R-GP) to `cli/lib/main.roc` for R-DI4 (G1). The entry `http` is already in `cli/main.roc`, `fxprobe.roc` and `flowprobe.roc`. |
| N2 | Write `spawn_all!` in `cli/RealFx.roc`. Start jobs up to `limit` and poll. A job that does not start is `NotStarted`. `stderr_last` is the last non-empty line. While a child runs, the poll loop writes the heartbeat of the held locks again (R-CC12, R-CC3 point 3). The L3 case `dl1-real-fx-jobs` checks both. |
| N3 | `rename!` is done: `Exists` for an existing target and for a dir that is not empty. Keep it. |
| N4 | The tests give `now` to `Github.releases!` from `Fx.clock!`. A time in the future is age 0. |
| N5 | A test that needs a new route or a new fake answer changes only the case, not the harness. |

## Review (manager, 2026-10-18)

The manager accepted the tests and the output proposals. The answers below are the manager's proposals. The user did not confirm them yet. The code agent follows them.

| # | Answer |
| --- | --- |
| Q1 | Build the URL with the form of R-DI5 from the owner, the repository, the tag and the asset name. The design gives this form. The fixtures have the same text in `browser_download_url`, so no test changes. |
| Q2 | A 404 of the release list: usage failure, exit 2, `no GitHub repository <owner>/<repo> (a private repository needs a token)`. Add one L0 row for it. Other statuses: the default (exit 15). |
| Q3 to Q10 | The defaults of the slice. |
| G1 | Add the `base58` entry (N1). |
| G2 | `JsonDoc.parse` must accept every valid JSON number. A field that Talon does not read never fails a parse. Add one L0 row with a float. |
| G4 | D5 is accepted as the layout of the index pages. |

## Disputes (from the code agent)

| Test | Change | Design source |
| --- | --- | --- |
| `tests/unit/talonfile.roc`, first `expect` | The inputs `{"a":1.5}` and `{"a":1e3}` moved from `errors` (must be `BadJson`) to `ok` (`Real("1.5")`, `Real("1e3")`). New `ok` rows: a float, an exponent, a number out of the `I64` range. New `errors` rows: `[01]`, `[1.]`, `[.5]`, `[1e]`, `[1e+]`, `[-]`, `[+1]`, `[1.5.5]`. The round trip has a float and an exponent. | Review G2: `JsonDoc.parse` must accept every valid JSON number. The old rows (slice 002) said the reverse. |

## Added by the review (the two L0 rows)

| Row | File | Rule |
| --- | --- | --- |
| A float, an exponent and a big integer in fields that Talon does not read give no `BadPage` | `tests/unit/index.roc`, the bad-page `expect` (row "a float in a field that is not read (G2)") | G2 |
| `Github.missing_repo` gives exit 2 and `no GitHub repository acme/nope (a private repository needs a token)` | `tests/unit/github.roc`, the failures `expect` (6th item) | Q2 |

The 404 of the release list also has one L2 run: `tests/commands/cases/index/di-list-flow/` has the new run `releases acme/nope` (new route `fx/http/api.github.com/repos/acme/nope/`, N5). Its `expect/` files got the lines of that run (exit 2, the failure line, the calls `list_dirs`, `programs gh`, `http_get`).

## Code decisions (not fixed by the slice)

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | `JsonDoc` has a new tag `Real(Str)`: a number that is not an `I64`, kept as its text. `render` prints the text. Public signature change of `JsonDoc`. | A float type (`F64`): the text of the number would change on a round trip (R-TF2). Drop the field: unknown fields must stay. |
| C2 | `Github.missing_repo : { owner, repo } -> Fail` is a new public function for Q2. `status_failure` is unchanged. | A 404 branch inside `status_failure`: it has no owner and no repository. |
| C3 | `cli/lib/main.roc` has the entry `base58` (roc-base58 0.1.0, release URL, N1). `Index` uses `Base58.decode` with 32 bytes (G1). | |
| C4 | `Github.releases!` offline, page n > 1 not cached: it stops and gives the pages that it has (source `Cached`). | A failure: the design does not say, and the pages are valid. |
| C5 | `Github.releases!` reads the token at the first request only (a cached run makes no `programs` call). | Read it first for every call: the L2 case forbids it. |
| C6 | Any 404 of a list page (not only page 1) is the usage failure of Q2. | Only page 1. |
| C7 | The size of an asset that is missing or not a number is 0. | `BadPage`: the design gives no rule. |
| C8 | `RealFx.spawn_all!` polls every 20 ms and writes the heartbeat every 100 polls (2 s). A job with `limit` 0 runs with limit 1. stdin of a child is `Null`. | A longer sleep: slower short jobs. |
| C9 | `Fetch.packages!` always calls `list_dirs!` (also when all URLs fail `plan`). `delete!` also runs after a `make_dirs!` failure. | |
| C10 | A failed `make_dirs!` of the temp dirs fails each pending URL: kind `Environment`, `cannot make the temp dirs in <pkgs>: <err>` (a proposal, R-OUT2). | |

## Verify results

`scripts/test.sh` (2026-10-18): exit 0.

| Step | Result | Seconds |
| --- | --- | --- |
| check | pass | 1.0 |
| fmt | pass | 0.0 |
| L0 | pass: 25 files, 83 `expect`s (the 19 new ones of this slice green) | 2.6 |
| L2 | pass: 8 cases (3 new) | 17.0 |
| L3 | pass: 16 scenarios (3 new) | 22.0 |
| selftest | pass: 24 checks | 26.6 |
| Total | under the 3 minutes of TW20 | 69 |

Revert check (TW12): `research/slice-003-revert/revert.py` (121 mutations of the code, each in one small way, the table is made by the script, then the file is put back). The script checks the test that fails. A mutation that does not compile is not a catch (7 were first invalid, then written again). After the run `diff -r cli .work/cli-final` shows no difference.

Caught 114 of 121. Groups:

| File | Mutations | Caught | Layers that caught |
| --- | --- | --- | --- |
| `Net.roc` | 17 | 17 | L0 `net` |
| `Download.roc` | 13 | 12 | L0 `download` |
| `Fetch.roc` | 16 | 16 | L0 `fetch`, L2 `fe-flow` |
| `Github.roc` | 32 | 30 | L0 `github`, L2 `di-list-flow`, `rg3-token-sources`, L3 `di1-github-pages` |
| `Index.roc` | 25 | 22 | L0 `index` |
| `Clock.roc` | 2 | 2 | L0 `github` |
| `JsonDoc.roc` | 7 | 7 | L0 `index`, `talonfile` |
| `RealFx.roc` | 9 | 8 | L3 `dl1-real-fx-jobs` |
| Total | 121 | 114 | |

Mutations that no test caught:

| Mutation | Why not caught |
| --- | --- |
| R-FE8: `text.starts_with("${host}:")` to `starts_with(host)` (`Download.is_loopback`) | Equal behavior: the digit check of the port refuses the same texts. Not a test gap. |
| R-DI12: `page.mtime >= now` to `>` (age of a page in the future) | Equal behavior: an equal time gives age 0 by both forms. Not a test gap. |
| R-DI4: the `.tar.zst` suffix check of `is_package_name` removed | A name with no suffix that is a valid base58 hash (for example `<hash>`) is not in any test. Test gap. |
| R-DI6: a tie of `published_at` in `new_entry` goes to the last one (`>=`) | D9 says the first one wins a tie. No row has a tie. Test gap. |
| R-DI9: the order of two candidates with the same version in `order` is reversed | The rule "candidates of one version keep their order" has no row. Test gap. |
| R-DI12: `releases!` gives the newest page time in place of the oldest for `Cached(t)` | The L2 offline case has one cached page. Test gap (two cached pages with different times). |
| R-DA1: the timeout of `http_get!` 20 s to 20 ms | No test has a server that answers slowly (20 s would not fit in the fast set). |

## Questions (TW17) and limits found by the code agent

| # | Text |
| --- | --- |
| K1 | The 5 test gaps above need rows from the test agent (R-DI4 suffix, R-DI6 tie, R-DI9 same version, R-DI12 oldest of two pages, R-DA1 timeout). The code agent did not add them (TW18). |
| K2 | `roc` limit met again: a `var` needs an initial value with a type. `var $x : T = []` is a syntax error, so `RealFx` has the typed values `no_running` and `no_results`. No repro needed (the form is not in the syntax). |

## Review of the code (manager, 2026-10-18)

`scripts/test.sh` passes (66 s). The change of the slice 002 rows in `tests/unit/talonfile.roc` follows review G2 and is accepted. The 5 test gaps of K1 (R-DI4 bare hash name, R-DI6 tie, R-DI9 same version, R-DI12 oldest page time) go to the next test agent (slice 005). The 20 s timeout of R-DA1 stays untested in the fast set.

Status: done (2026-10-18).
