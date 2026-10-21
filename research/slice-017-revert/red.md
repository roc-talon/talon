== l0: FAIL (log: /home/george/dev/Karakatiza666/talon/.work/logs/l0.log)
            view(scope(Install, [], [], vars_of([a, b]))),
            Ok([(["json", "js"], Bool.True, Bool.False), (["http"], Bool.False, Bool.True), (["http2"], Bool.False, Bool.True), (["pf"], Bool.False, Bool.True), (["pf"], Bool.False, Bool.True)]),
        ),
    ]
    bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
    dbg bad
    bad == []
}

Mentioned values:
http2 = gh("roc-lang", "http", "2.0.0", h_http2)
json2 = gh("someone", "roc-json", "2.3.0", h_json2)
web = gh("roc-lang", "basic-webserver", "0.12.0", h_web)
http1 = gh("roc-lang", "http", "1.9.0", h_http1)
json1 = gh("someone", "roc-json", "2.1.0", h_json1)
cli = gh("roc-lang", "basic-cli", "0.25.0", h_cli)
odd = "https://example.com/lib/1.0.0/${h_http1}.tar.zst"
parser = gh("lukewilliamboswell", "roc-parser", "2.0.0", h_parser)

Roc application crashed with this message:

	tln: error[usage]: /w/talon.toml:6: the key 'yaml' is in no header, and 2 members are under /w: /w/apps/a/main.roc, /w/apps/d/main.roc. Run tln add --file <member file> yaml for one of them.


── ✗ fail ──────────────────────────────────────────── tests/unit/vars.roc:320:1

expect {
    root_text = "[workspace]\nmembers = [\"apps/*/main.roc\"]\n\n[dependencies]\njs = \"someone/roc-json@^2\"\nyaml = \"yaml@2\"\nnewdep = \"acme/newdep@^1\"\n"
    root_toml = Ok({ path: "/w/talon.toml", text: root_text, role: Root })
    a = member("/w/apps/a/main.roc", app_header(["pf: platform \"${cli}\"", "json: \"${json1}\""]), root_toml)
    d = member("/w/apps/d/main.roc", app_header(["pf: platform \"${cli}\""]), root_toml)
    wants_of = |members| match Vars.build({ members, priority: Err(Unset) }) {
        Ok(built) => built.wants
        Err(e) => crash e.line()
    }
    check = |wants, keys| match Vars.check_keys(wants.keep_if(|w| keys.contains(w.key))) {
        Ok(_) => "ok"
        Err(e) => e.line()
    }
    two = wants_of([a, d])
    one = wants_of([a])
    rows = [
        ("a stale key is no failure (R-I8)", check(two, ["js"]), "ok"),
        ("a short name with 2 members names the key", check(two, ["yaml"]), "tln: error[usage]: /w/talon.toml:6: the key 'yaml' is in no header, and 2 members are under /w: /w/apps/a/main.roc, /w/apps/d/main.roc. Run tln add --file <member file> yaml for one of them."),
        ("a full name with 2 members: the first key that fails is the failure", check(two, ["js", "yaml", "newdep"]), "tln: error[usage]: /w/talon.toml:6: the key 'yaml' is in no header, and 2 members are under /w: /w/apps/a/main.roc, /w/apps/d/main.roc. Run tln add --file <member file> yaml for one of them."),
        ("a full name with 2 members", check(two, ["newdep"]), "tln: error[usage]: /w/talon.toml:7: the key 'newdep' is in no header, and 2 members are under /w: /w/apps/a/main.roc, /w/apps/d/main.roc. Run tln add --file <member file> acme/newdep for one of them."),
        ("one member under the file: no failure (install adds the entry)", check(one, ["js", "yaml", "newdep"]), "ok"),
        ("no want", check([], []), "ok"),
    ]
    bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
    dbg bad
    bad == []
}

Ran 6 tests in 656.1 ms.:
    3 passed
    3 failed
    0 compiler errors
tests/unit/verify.roc: All (2) tests passed in 348.9 ms.
tests/unit/why.roc: All (6) tests passed in 814.2 ms.
== l2: FAIL (log: /home/george/dev/Karakatiza666/talon/.work/logs/l2.log)
      -read_files $HOME/.cache/roc/packages/4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq/main.roc $HOME/.cache/roc/packages/9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK/main.roc $PROJECT/w3/lib/main.roc
      -random
      -list_dirs $HOME/.cache/roc/packages
      -read_files $HOME/.cache/roc/packages/3CjxCHLyKRMyh9nKodyVQYJcsttYAyPLjYTpoH2fnZtA/main.roc
       args
       env_all
       clock
      @@ -112,7 +86,10 @@
         User-Agent: tln/0.0.0
       write_atomic $HOME/.cache/roc/talon/index/github/acme/core/1.json $HOME/.cache/roc/talon/index/github/acme/core/1.meta
       list_dirs $HOME/.cache/roc/talon/index/github/acme/pfx
      -read_files $HOME/.cache/roc/talon/index/github/acme/pfx/1.meta $HOME/.cache/roc/talon/index/github/acme/pfx/1.json
      +programs gh
      +http_get https://api.github.com/repos/acme/pfx/releases?per_page=100
      +  User-Agent: tln/0.0.0
      +write_atomic $HOME/.cache/roc/talon/index/github/acme/pfx/1.json $HOME/.cache/roc/talon/index/github/acme/pfx/1.meta
       random
       list_dirs $HOME/.cache/roc/packages
       read_files $HOME/.cache/roc/packages/8bp2yxDtY2ayou722hzyv51Ts1yBaFshmVGtLXpkDy8r/main.roc $HOME/.cache/roc/packages/9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK/main.roc $PROJECT/w4/lib/main.roc
    file tree differs (- expected, + actual):
      --- expected
      +++ actual
      @@ -3,11 +3,6 @@
       @@ -0,0 +1 @@
       +[{"tag_name":"1.0.0","draft":false,"prerelease":false,"published_at":"2026-07-20T12:00:00Z","assets":[{"name":"8bp2yxDtY2ayou722hzyv51Ts1yBaFshmVGtLXpkDy8r.tar.zst","size":1000,"browser_download_url":"https://github.com/acme/core/releases/download/1.0.0/8bp2yxDtY2ayou722hzyv51Ts1yBaFshmVGtLXpkDy8r.tar.zst"}]},{"tag_name":"1.1.0","draft":false,"prerelease":false,"published_at":"2026-09-01T12:00:00Z","assets":[{"name":"GFxDoMVtm3uCVP4qTSN11k2YKtzwLWibi2UNecy1KX6a.tar.zst","size":1000,"browser_download_url":"https://github.com/acme/core/releases/download/1.1.0/GFxDoMVtm3uCVP4qTSN11k2YKtzwLWibi2UNecy1KX6a.tar.zst"}]}]
       \ No newline at end of file
      ---- home/.cache/roc/talon/index/github/acme/json/1.json
      -+++ home/.cache/roc/talon/index/github/acme/json/1.json
      -@@ -0,0 +1 @@
      -+[{"tag_name":"2.0.0","draft":false,"prerelease":false,"published_at":"2026-08-16T12:00:00Z","assets":[{"name":"7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst","size":1000,"browser_download_url":"https://github.com/acme/json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst"}]},{"tag_name":"2.0.5","draft":false,"prerelease":false,"published_at":"2026-09-05T12:00:00Z","assets":[{"name":"8FNd42oEnQP2CUSB4YWEqcsHBwCq8z26bL1Xk3PwDQ8f.tar.zst","size":1000,"browser_download_url":"https://github.com/acme/json/releases/download/2.0.5/8FNd42oEnQP2CUSB4YWEqcsHBwCq8z26bL1Xk3PwDQ8f.tar.zst"}]},{"tag_name":"2.1.0","draft":false,"prerelease":false,"published_at":"2026-09-25T12:00:00Z","assets":[{"name":"4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq.tar.zst","size":1000,"browser_download_url":"https://github.com/acme/json/releases/download/2.1.0/4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq.tar.zst"}]},{"tag_name":"2.2.0","draft":false,"prerelease":false,"published_at":"2026-10-14T12:00:00Z","assets":[{"name":"3CjxCHLyKRMyh9nKodyVQYJcsttYAyPLjYTpoH2fnZtA.tar.zst","size":1000,"browser_download_url":"https://github.com/acme/json/releases/download/2.2.0/3CjxCHLyKRMyh9nKodyVQYJcsttYAyPLjYTpoH2fnZtA.tar.zst"}]}]
      -\ No newline at end of file
       --- home/.cache/roc/talon/index/github/acme/pfx/1.json
       +++ home/.cache/roc/talon/index/github/acme/pfx/1.json
       @@ -0,0 +1 @@
      @@ -22,24 +17,6 @@
       +++ home/.cache/roc/talon/projects.json
       @@ -0,0 +1 @@
       +{"format":1,"projects":[{"path":"$PROJECT/solo/main.roc","last_use":1792065600},{"path":"$PROJECT/w3/apps/a/main.roc","last_use":1792065600},{"path":"$PROJECT/w3/apps/b/main.roc","last_use":1792065600},{"path":"$PROJECT/w4/apps/a/main.roc","last_use":1792065600},{"path":"$PROJECT/w4/apps/b/main.roc","last_use":1792065600},{"path":"$PROJECT/w5/apps/a/main.roc","last_use":1792065600},{"path":"$PROJECT/w5/apps/b/main.roc","last_use":1792065600}]}
      ---- project/w3/apps/a/main.roc
      -+++ project/w3/apps/a/main.roc
      -@@ -1,5 +1,5 @@
      - app [main!] {
      --	pf: platform "https://github.com/acme/pfx/releases/download/0.1.0/6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL.tar.zst",
      -+	pf: platform "https://github.com/acme/pfx/releases/download/0.1.1/9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK.tar.zst",
      - 	json: "https://github.com/acme/json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst",
      - 	roc: "nightly-2026-10-14-38a3029",
      - }
      ---- project/w3/apps/b/main.roc
      -+++ project/w3/apps/b/main.roc
      -@@ -1,5 +1,5 @@
      - app [main!] {
      --	pf: platform "https://github.com/acme/pfx/releases/download/0.1.0/6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL.tar.zst",
      -+	pf: platform "https://github.com/acme/pfx/releases/download/0.1.1/9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK.tar.zst",
      - 	lib: "../../lib/main.roc",
      - 	roc: "nightly-2026-10-14-38a3029",
      - }
       --- project/w5/apps/a/main.roc
       +++ project/w5/apps/a/main.roc
       @@ -1,6 +1,6 @@
commands: 32 passed, 3 failed
== l3: FAIL (log: /home/george/dev/Karakatiza666/talon/.work/logs/l3.log)
FAIL install/in1-workspace-frozen-rename
    stdout differs (- expected, + actual):
      --- expected
      +++ actual
      @@ -17,12 +17,7 @@
       == tln add acme/util
       exit 2
       == tln add --file apps/b/main.roc acme/json@2.2.0
      -note: json 2.2.0 is 1d old (min-release-age 2d)
      -$PROJECT/apps/a/main.roc: check: passed
      -$PROJECT/apps/a/main.roc: build: passed
      -$PROJECT/apps/b/main.roc: check: passed
      -$PROJECT/apps/b/main.roc: build: passed
      -exit 13
      +exit 10
       == tln add --file apps/b/main.roc acme/json
       check: passed
       build: passed
    stderr differs (- expected, + actual):
      --- expected
      +++ actual
      @@ -5,7 +5,5 @@
       renamed 1 stale key in talon.toml
       tln: error[usage]: flag '--frozen' works only for tln install with no names
       tln: error[usage]: no current member in the workspace at $PROJECT. Members: $PROJECT/apps/a/main.roc, $PROJECT/apps/b/main.roc. Pass --file <member file>.
      -~ json: acme/json 2.0.0 -> 2.2.0 (held): json 2.0.0 is outside =2.2.0
      -  writes $PROJECT/apps/a/main.roc
      -tln: error[consent]: moving the held variable json needs consent. Pass --allow-moves or --yes.
      +tln: error[no_tuple]: no tuple works: '=2.2.0' for acme/json excludes the version 2.0.0 held by $PROJECT/apps/a/main.roc. Moving a held version needs consent (R-NI3), which this version of tln cannot ask. Nothing was written.
       tln: error[internal]: command 'probe' is not built yet
    roc calls differs (- expected, + actual):
      --- expected
      +++ actual
      @@ -1,12 +1,6 @@
       version
       version
       version
      -check main.roc
      -check main.roc
      -build main.roc --output=$HOME/.cache/roc/talon/tmp/$HEX/tln-probe.out
      -check main.roc
      -check main.roc
      -build main.roc --output=$HOME/.cache/roc/talon/tmp/$HEX/tln-probe.out
       version
       check main.roc
       check main.roc
scenarios: 25 passed, 1 failed, 1 skipped

step       result seconds
check      pass   5.2
fmt        pass   0.1
l0         FAIL   13.0
l2         FAIL   49.1
l3         FAIL   9.2
selftest   pass   5.8
exit 1
