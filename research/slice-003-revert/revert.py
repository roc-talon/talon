#!/usr/bin/env python3
"""Revert check of slice 003 (TW12): break the code of each rule in one small way, run the tests that should catch it,
put the file back. Usage: research/slice-003-revert/revert.py [id-filter ...]. Writes the table to stdout.
A compile error of a mutation is reported as INVALID (it is not a catch)."""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ.get("ROC", f"{ROOT}/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")

# (rule ids, file under cli/, old text, new text, test)   test: l0:<unit file> | l2:<filter> | l3:<filter>
M = [
    ("R-EV14", "lib/Net.roc", '?? "https://api.github.com"', '?? "https://api.github.org"', "l0:net"),
    ("R-EV15", "lib/Net.roc", '?? "https://raw.githubusercontent.com"', '?? "https://raw.githubusercontent.org"', "l0:net"),
    ("R-EV19 test API keeps the token plan", "lib/Net.roc", 'Ok(_) => Test', 'Ok(_) => AskGh', "l0:net"),
    ("R-EV3 GITHUB_TOKEN first", "lib/Net.roc", 'match var_of("GITHUB_TOKEN") {', 'match var_of("GH_TOKEN") {', "l0:net"),
    ("R-EV3 empty is not set", "lib/Net.roc", 'Ok((_, value)) => if value.is_empty() Err(Unset) else Ok(value)', 'Ok((_, value)) => Ok(value)', "l0:net"),
    ("R-EV12 curl", "lib/Net.roc", 'Ok("curl") => Curl', 'Ok("curl") => Wget', "l0:net"),
    ("R-EV2", "lib/Net.roc", 'registry: var_of("TALON_REGISTRY")', 'registry: Err(Unset)', "l0:net"),
    ("R-RG1 direct", "lib/Net.roc", 'Ok("direct") => Direct', 'Ok("direct") => Url("direct")', "l0:net"),
    ("R-RG2 flag before env", "lib/Net.roc", 'Setting.pick({ flag: layers.flag, env: layers.env,', 'Setting.pick({ flag: layers.env, env: layers.flag,', "l0:net"),
    ("R-RG2 default", "lib/Net.roc", 'Err(Unset) => Direct', 'Err(Unset) => Url("")', "l0:net"),
    ("R-RG3 gh exit code", "lib/Net.roc", 'Exited(0) => {', 'Exited(_) => {', "l0:net"),
    ("R-RG3 gh trim", "lib/Net.roc", 'text = facts.stdout.trim()', 'text = facts.stdout', "l0:net"),
    ("R-RG3 env over gh", "lib/Net.roc", 'Env(t) => Ok(t)\n\t\tAskGh => facts.gh', 'Env(t) => facts.gh\n\t\tAskGh => facts.gh', "l0:net"),
    ("R-RG3 test API no token", "lib/Net.roc", 'Test => Err(None)', 'Test => facts.gh', "l0:net"),
    ("R-DI2 user agent", "lib/Net.roc", 'agent = [("User-Agent", "tln/${Help.version}")]', 'agent = []', "l0:net"),
    ("R-DI2 bearer", "lib/Net.roc", '"Bearer ${t}"', '"${t}"', "l0:net"),
    ("R-DI2 etag header", "lib/Net.roc", '("If-None-Match", e)', '("If-Match", e)', "l0:net"),
    ("R-DA2 curl first", "lib/Download.roc", 'Auto => if facts.curl {', 'Auto => if facts.curl and !facts.wget {', "l0:download"),
    ("R-EV12 no fallback", "lib/Download.roc", 'Curl => if facts.curl Ok(Curl) else Err(missing("curl"))', 'Curl => if facts.curl Ok(Curl) else if facts.wget Ok(Wget) else Err(missing("curl"))', "l0:download"),
    ("R-DA2 none", "lib/Download.roc", 'Err(Fail.new(Environment, "no download program', 'Err(Fail.new(Usage, "no download program', "l0:download"),
    ("R-DA3 proto-redir", "lib/Download.roc", '\t\t\t"--proto-redir",\n\t\t\t"=https",\n', '', "l0:download"),
    ("R-DA3 wget tries", "lib/Download.roc", '"--tries=3"', '"--tries=1"', "l0:download"),
    ("R-DA7 curl 22", "lib/Download.roc", '(Curl, Exited(22))', '(Curl, Exited(8))', "l0:download"),
    ("R-DA7 wget 8", "lib/Download.roc", '(Wget, Exited(8))', '(Wget, Exited(22))', "l0:download"),
    ("R-DA7 status text", "lib/Download.roc", 'line.split_last("error: ")', 'line.split_first("returned")', "l0:download"),
    ("R-FE8 loopback by prefix", "lib/Download.roc", 'text == host or (', 'text.starts_with(host) or (', "l0:download"),
    ("R-FE8 https only", "lib/Download.roc", 'if url.starts_with("https://") {', 'if url.starts_with("http") {', "l0:download"),
    ("R-FE8 user info", "lib/Download.roc", 'text.starts_with("${host}:") and {', 'text.starts_with("${host}") and {', "l0:download"),
    ("R-EV25 port of loopback", "lib/Download.roc", '!port.is_empty() and port.all(|b| b >= 48 and b <= 57)', 'Bool.False', "l0:download"),
    ("R-EV12 bad downloader", "lib/Download.roc", 'Bad(text) => Err(Fail.new(Usage,', 'Bad(text) => Err(Fail.new(Input,', "l0:download"),
    ("R-FE3 temp name", "lib/Fetch.roc", '"${ident.hash}.${facts.hex}.tmp"', '"${ident.hash}.tmp"', "l0:fetch"),
    ("R-DA4 archive in temp", "lib/Fetch.roc", 'archive: "${temp}/${ident.hash}.tar.zst"', 'archive: "${facts.roots.pkgs}/${ident.hash}.tar.zst"', "l0:fetch"),
    ("R-FE10 audit hint", "lib/Fetch.roc", 'failed: ${status.to_str()} (${p.url}). Run tln audit to see why."', 'failed: ${status.to_str()} (${p.url})."', "l0:fetch"),
    ("R-FE2 unbundle kind", "lib/Fetch.roc", 'Fail.new(Integrity, "roc unbundle rejected', 'Fail.new(Network, "roc unbundle rejected', "l0:fetch"),
    ("R-HF12 roc not started", "lib/Fetch.roc", 'NotStarted(text) => Fail.new(Environment, "cannot run roc: ${text}")', 'NotStarted(text) => Fail.new(Network, "cannot run roc: ${text}")', "l0:fetch"),
    ("R-FE7 offline", "lib/Fetch.roc", '} else if offline {', '} else if offline and Bool.False {', "l2:fe-flow"),
    ("R-FE8 URL checked", "lib/Fetch.roc", 'Download.check_url(facts.url)?', '{}', "l0:fetch"),
    ("R-FE1 one limit", "lib/Fetch.roc", 'results = fx.spawn_all!({ jobs, limit: 8 })\n\tnews = plans.map2(', 'results = fx.spawn_all!({ jobs, limit: 4 })\n\tnews = plans.map2(', "l2:fe-flow"),
    ("R-FE3 Exists is fetched", "lib/Fetch.roc", 'Err(Exists) => Fetched', 'Err(Exists) => Failed(Fail.new(Environment, "exists"))', "l2:fe-flow"),
    ("R-FE3 cleanup", "lib/Fetch.roc", '_ = fx.delete!(plans.map(|p| p.temp))', '_ = plans', "l2:fe-flow"),
    ("R-FE7 offline", "lib/Fetch.roc", '} else if offline {', '} else if offline and Bool.False {', "l2:fe-flow"),
    ("R-FE4 present", "lib/Fetch.roc", 'listing.any(|e| e.is_dir and e.name == p.hash)', 'listing.any(|e| e.name == "x")', "l2:fe-flow"),
    ("R-FE5 unbundle only for done", "lib/Fetch.roc", 'Http(status) => Failed(Fetch.download_failed({ plan: p, program, ended: r.ended, outcome: Http(status), last_line: r.stderr_last }))', 'Http(_) => Pending(p)', "l2:fe-flow"),
    ("R-FE1 one random call", "lib/Fetch.roc", 'hex = Temp.hex(fx.random!())', 'hex = Temp.hex(fx.random!() + fx.random!() * 0)', "l2:fe-flow"),
    ("R-FE2 unbundle in temp", "lib/Fetch.roc", 'cwd: Ok(p.temp) })', 'cwd: Err(Inherit) })', "l2:fe-flow"),
    ("R-DA5 limit", "RealFx.roc", 'while $next < total and $running.len() < limit {', 'while $next < total and $running.len() < limit + 5 {', "l3:dl1-real"),
    ("R-CC12 R-CC3 heartbeat in poll", "RealFx.roc", 'if $polls % 100 == 0 {', 'if $polls % 100 == 99999 {', "l3:dl1-real"),
    ("R-HF4 stderr_last", "RealFx.roc", 'stderr_last: lines.last() ?? ""', 'stderr_last: lines.first() ?? ""', "l3:dl1-real"),
    ("R-HF12 not started", "RealFx.roc", 'Err(err) => Err(Str.inspect(err))', 'Err(_) => Err("x")', "l3:dl1-real"),
    ("R-HF4 cwd", "RealFx.roc", 'Ok(dir) => base.cwd(Path.utf8(dir))', 'Ok(_) => base', "l3:dl1-real"),
    ("R-HF4 signal", "RealFx.roc", 'Signaled(code) => Signaled(code)', 'Signaled(code) => Exited(code)', "l3:dl1-real"),
    ("R-HF4 stdout", "RealFx.roc", 'stdout: Str.from_utf8_lossy(out.stdout_bytes)', 'stdout: ""', "l3:dl1-real"),
    ("R-HF4 order of results", "RealFx.roc", 'Ok((_, result)) => result', 'Ok((_, _)) => not_started("x")', "l3:dl1-real"),
    ("R-DA1 http timeout", "RealFx.roc", 'TimeoutMilliseconds(20000)', 'TimeoutMilliseconds(20)', "l3:dl1-real"),
    ("R-DI2 list_url", "lib/Github.roc", '/releases?per_page=100"', '/releases?per_page=30"', "l0:github"),
    ("R-DI8 hint_url", "lib/Github.roc", '${facts.tag}/.roc-version"', '${facts.tag}/.roc_version"', "l0:github"),
    ("R-DI8 hint 404", "lib/Github.roc", '404 => Err(NoHint)', '404 => Err(Failed(404))', "l0:github"),
    ("R-DI8 hint blank lines", "lib/Github.roc", '.find_first(|line| !line.is_empty())', '.find_first(|_| Bool.True)', "l0:github"),
    ("R-DI2 cache dir", "lib/Github.roc", '"github/${facts.owner}/${facts.repo}"', '"gh/${facts.owner}/${facts.repo}"', "l0:github"),
    ("R-DI2 meta etag", "lib/Github.roc", 'Ok(e) => "etag ${e}\\n"', 'Ok(_) => ""', "l0:github"),
    ("R-DI2 Link rel", "lib/Github.roc", 'found.after.contains("rel=\\"next\\"")', 'Bool.True', "l0:github"),
    ("R-DI2 Link case", "lib/Github.roc", 'n.with_ascii_lowercased() == name', 'n == name', "l0:github"),
    ("R-DI12 60 s", "lib/Github.roc", 'facts.offline or age < 60', 'facts.offline or age <= 60', "l0:github"),
    ("R-DI12 offline", "lib/Github.roc", 'facts.offline or age < 60', 'age < 60', "l0:github"),
    ("R-DI12 future", "lib/Github.roc", 'age = if page.mtime >= facts.now 0 else facts.now - page.mtime', 'age = if page.mtime > facts.now 0 else facts.now - page.mtime', "l0:github"),
    ("R-DI12 ETag", "lib/Github.roc", 'Ok(etag) => Revalidate(etag)', 'Ok(_) => Fetch', "l0:github"),
    ("R-DI13 any 403", "lib/Github.roc", '(remaining == Ok("0") or retry != Err(NotFound))', 'Bool.True', "l0:github"),
    ("R-DI13 retry-after", "lib/Github.roc", 'or retry != Err(NotFound))', 'or Bool.False)', "l0:github"),
    ("R-DI13 reset", "lib/Github.roc", 'Ok(Ok(seconds)) => Ok(facts.now + seconds)', 'Ok(Ok(seconds)) => Ok(seconds)', "l0:github"),
    ("R-DI13 text", "lib/Github.roc", 'log in with gh (gh auth login).")', 'log in with gh.")', "l0:github"),
    ("R-DI12 no answer text", "lib/Github.roc", 'Timeout => "no answer in 20 s"', 'Timeout => "timeout"', "l0:github"),
    ("R-DI12 offline line", "lib/Github.roc", '"index: cached at ${Clock.format_utc(time)}"', '"cached at ${Clock.format_utc(time)}"', "l0:github"),
    ("R-DI12 format_utc month", "lib/Clock.roc", 'month = if shifted < 10 shifted + 3 else shifted - 9', 'month = if shifted < 10 shifted + 4 else shifted - 9', "l0:github"),
    ("R-DI12 format_utc leap", "lib/Clock.roc", 'year_of_era + era * 400 + (if month <= 2 1 else 0)', 'year_of_era + era * 400', "l0:github"),
    ("Q2 404 text", "lib/Github.roc", 'Fail.new(Usage, "no GitHub repository', 'Fail.new(Network, "no GitHub repository', "l0:github"),
    ("Q2 404 wired", "lib/Github.roc", '(404, _) => Err(Github.missing_repo', '(4040, _) => Err(Github.missing_repo', "l2:di-list-flow"),
    ("R-DI2 ETag sent", "lib/Github.roc", 'Net.headers({ token, etag })', 'Net.headers({ token, etag: Err(None) })', "l2:di-list-flow"),
    ("R-DI2 304 renews meta", "lib/Github.roc", 'writes = [{ path: files.meta, content: Github.meta_text({ etag: c.etag, next: c.next }) }]', 'writes = []', "l2:di-list-flow"),
    ("R-DI2 304 renews meta L3", "lib/Github.roc", 'writes = [{ path: files.meta, content: Github.meta_text({ etag: c.etag, next: c.next }) }]', 'writes = []', "l3:di1-github"),
    ("R-DI13 write all or nothing", "lib/Github.roc", 'if !state.writes.is_empty() {', 'if state.writes.is_empty() {', "l2:di-list-flow"),
    ("R-DI2 token asked once", "lib/Github.roc", '(token, Resolved(token))', '(token, Unresolved)', "l2:di-list-flow"),
    ("R-DI9 hint no token", "lib/Github.roc", 'Net.headers({ token: Err(None), etag: Err(None) })', 'Net.headers({ token: match facts.net.token {\n\t\t\tEnv(t) => Ok(t)\n\t\t\t_ => Err(None)\n\t\t}, etag: Err(None) })', "l2:di-list-flow"),
    ("R-DI13 rate limit wired", "lib/Github.roc", 'Ok({ reset }) => Err(Github.rate_limit_failure({ reset: reset }))', 'Ok({ reset: _ }) => Err(Github.status_failure({ url, status: 403 }))', "l2:di-list-flow"),
    ("R-DI12 offline no request", "lib/Github.roc", '(Missing, _) => Ok(state)', '(Missing, _) => pages_from!(fx, { ..run, offline: Bool.False }, state, n, url)', "l2:di-list-flow"),
    ("R-DI12 oldest page", "lib/Github.roc", 'Ok(t) => if t < c.mtime t else c.mtime', 'Ok(t) => if t < c.mtime c.mtime else t', "l2:di-list-flow"),
    ("R-DI2 next page", "lib/Github.roc", 'Ok(url) => pages_from!(fx, run, state, n + 1, url)', 'Ok(url) => pages_from!(fx, run, state, n, url)', "l2:di-list-flow"),
    ("R-RG3 gh asked", "lib/Github.roc", '[Bool.True] => match fx.spawn_all!', '[Bool.False] => match fx.spawn_all!', "l2:rg3-token"),
    ("R-DI3 draft", "lib/Index.roc", 'is_true(pairs, "draft") or is_true(pairs, "prerelease")', 'is_true(pairs, "prerelease")', "l0:index"),
    ("R-DI3 prerelease", "lib/Index.roc", 'is_true(pairs, "draft") or is_true(pairs, "prerelease")', 'is_true(pairs, "draft")', "l0:index"),
    ("R-DI4 base58 length", "lib/Index.roc", 'name.ends_with(".tar.zst") and Base58.decode(name.drop_suffix(".tar.zst")).map_ok(|bytes| bytes.len()) == Ok(32)', 'name.ends_with(".tar.zst") and Base58.decode(name.drop_suffix(".tar.zst")).map_ok(|bytes| bytes.len()) != Err(InvalidChar(0))', "l0:index"),
    ("R-DI4 base58 alphabet", "lib/Index.roc", '|bytes| bytes.len()) == Ok(32)', '|bytes| bytes.len()) != Err(TooLong(0))', "l0:index"),
    ("R-DI4 one asset", "lib/Index.roc", '[one] => {', '[one, ..] => {', "l0:index"),
    ("R-DI4 file ends", "lib/Index.roc", 'name.ends_with(".tar.zst") and', 'Bool.True and', "l0:index"),
    ("R-DI10 time", "lib/Index.roc", 'Ok(Text(t)) => Clock.parse_utc(t).map_err(|BadTime| Bad)?', 'Ok(Text(t)) => Clock.parse_utc(t) ?? 0', "l0:index"),
    ("R-DI15 group", "lib/Index.roc", 'k.group == ident.group and k.version', 'Bool.True and k.version', "l0:index"),
    ("R-DI15 version", "lib/Index.roc", 'and k.version == ident.version and', 'and Bool.True and', "l0:index"),
    ("R-DI15 hash", "lib/Index.roc", 'and k.hash != ident.hash', 'and Bool.True', "l0:index"),
    ("R-DI15 warning", "lib/Index.roc", 'but Talon knows ${old.url} with the hash ${old.hash}', 'but Talon knows ${old.url}', "l0:index"),
    ("R-DI4 warning", "lib/Index.roc", '(${hashes}). It is not a candidate.', '(${hashes}).', "l0:index"),
    ("R-DI6 in_group", "lib/Index.roc", 'keep_if(|c| c.ident.group == facts.group)', 'keep_if(|c| c.ident.group.form == facts.group.form)', "l0:index"),
    ("R-DI6 newest", "lib/Index.roc", 'if c.published_at > best.published_at c else best', 'if c.published_at < best.published_at c else best', "l0:index"),
    ("R-DI6 tie", "lib/Index.roc", 'if c.published_at > best.published_at c else best', 'if c.published_at >= best.published_at c else best', "l0:index"),
    ("R-DI6 one series", "lib/Index.roc", 'list: facts.list.keep_if(|c| c.ident.group.form == form)', 'list: facts.list.keep_if(|c| c.ident.group == newest.ident.group)', "l0:index"),
    ("R-DI6 note", "lib/Index.roc", 'also has releases in other URL forms: ${Str.join_with(others, ", ")}', 'also has releases in other URL forms: ${Str.join_with(others, ",")}', "l0:index"),
    ("R-DI6 note sorted", "lib/Index.roc", 'others = Text.sorted_unique(', 'others = (', "l0:index"),
    ("R-DI9 Highest", "lib/Index.roc", '(Before, Lowest) | (After, Highest) => Before', '(Before, Highest) | (After, Lowest) => Before', "l0:index"),
    ("R-DI9 stable", "lib/Index.roc", '(Same, _) => compare_index(i, j)', '(Same, _) => compare_index(j, i)', "l0:index"),
    ("R-DI9 numbers", "lib/Index.roc", 'version.split_on(".").map(|part| U64.from_str(part) ?? 0)', 'version.split_on(".").map(|part| part.to_utf8().len())', "l0:index"),
    ("R-DI11 host", "lib/Index.roc", 'if host == "github.com" Indexed', 'if host.starts_with("github.com") Indexed', "l0:index"),
    ("R-DI11 line", "lib/Index.roc", '"fixed: ${host} has no index without a registry"', '"fixed: ${host}"', "l0:index"),
    ("R-DA6 size", "lib/Index.roc", 'Ok(Num(n)) => if n >= 0 n.to_u64_wrap() else 0', 'Ok(Num(n)) => 0', "l0:index"),
    ("R-DI3 bad page", "lib/Index.roc", '\t\t\t\t\t_ => Err(BadPage(n))', '\t\t\t\t\t_ => Ok(found)', "l0:index"),
    ("G2 float", "lib/JsonDoc.roc", 'frac_end = fraction_end(bytes, int_end)?', 'frac_end = int_end', "l0:index"),
    ("G2 exponent", "lib/JsonDoc.roc", 'end = exponent_end(bytes, frac_end)?', 'end = frac_end', "l0:talonfile"),
    ("G2 big integer", "lib/JsonDoc.roc", 'Err(_) => Ok({ val: Real(text), next: end })', 'Err(_) => Err(BadJson)', "l0:talonfile"),
    ("G2 leading zero", "lib/JsonDoc.roc", 'int_end - first > 1 and bytes.get(first) == Ok(48)', 'Bool.False', "l0:talonfile"),
    ("G2 fraction needs digit", "lib/JsonDoc.roc", 'if end == i + 1 Err(BadJson) else Ok(end)', 'Ok(end)', "l0:talonfile"),
    ("G2 exponent needs digit", "lib/JsonDoc.roc", 'if end == start Err(BadJson) else Ok(end)', 'Ok(end)', "l0:talonfile"),
    ("R-CC11 no lock for a package", "lib/Fetch.roc", 'hex = Temp.hex(fx.random!())', 'hex = Temp.hex(fx.random!())\n\t\t_ = fx.lock!(facts.roots.pkgs, NoWait)', "l2:fe-flow"),
    ("R-CC11 no lock for an index page", "lib/Github.roc", 'dir = Github.repo_dir({ roots: facts.roots, owner: facts.owner, repo: facts.repo })\n\t\tlisting', 'dir = Github.repo_dir({ roots: facts.roots, owner: facts.owner, repo: facts.repo })\n\t\t_ = fx.lock!(dir, NoWait)\n\t\tlisting', "l2:di-list-flow"),
    ("G2 render", "lib/JsonDoc.roc", 'Real(text) => text', 'Real(_) => "0"', "l0:talonfile"),
]


def run(test):
    kind, what = test.split(":")
    env = dict(os.environ)
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{what}.roc", "--no-cache"]
    elif kind == "l2":
        cmd = ["tests/commands/run.sh", what]
    else:
        cmd = ["tests/run.sh", what]
        env["CASE_TIMEOUT"] = "40"
    p = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True, timeout=300)
    out = p.stdout + p.stderr
    return p.returncode, out


def main():
    flt = sys.argv[1:]
    print("| Rule | Mutation (file) | Result |\n| --- | --- | --- |")
    caught = invalid = 0
    total = 0
    for ids, rel, old, new, test in M:
        if flt and not any(f in ids for f in flt):
            continue
        path = f"{ROOT}/cli/{rel}"
        text = open(path).read()
        if old not in text:
            print(f"| {ids} | {rel}: pattern not found | INVALID |")
            invalid += 1
            continue
        total += 1
        open(path, "w").write(text.replace(old, new, 1))
        try:
            rc, out = run(test)
        finally:
            open(path, "w").write(text)
        compile_error = re.search(r"[1-9][0-9]* compiler error", out) is not None or "Compilation failed" in out or "build of" in out or "build of the L2 app failed" in out
        if rc == 0:
            result = "NOT CAUGHT"
        elif compile_error:
            result = "INVALID (compile error)"
            invalid += 1
            total -= 1
        else:
            result = f"caught by {test}"
            caught += 1
        print(f"| {ids} | {rel}: `{old[:50].strip()}` | {result} |", flush=True)
    print(f"\ncaught {caught} of {total}, invalid {invalid}")


main()
