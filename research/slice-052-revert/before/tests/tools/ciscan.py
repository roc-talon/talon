#!/usr/bin/env python3
"""Static checks of the CI workflow files (slice 018b, TW28). No third-party module.

Usage: python3 -I ciscan.py <check> <repo root>
Checks: yaml fast nightly pin portable. Prints one line `FAIL: <reason>` for each problem.
Exit code 0 when there is no problem, else 1.

The workflows cannot run in the test run (no remote, no runner). So these checks read the files.
The reader below parses the YAML subset that the workflow files must use (docs/slices/018b-ci-jobs.md,
"Shape of the workflow files"): block mappings and sequences, plain and quoted scalars, one-line
flow lists, `{}`, and block scalars (`|`, `>`). Anchors, aliases, tags, multi-line plain scalars
and a flow mapping with keys are errors: that is a rule of the shape, so a file stays easy to read.
If PyYAML is importable, `yaml` also runs its parser on each file.
"""
import glob
import os
import re
import sys


class YamlError(Exception):
    pass


def unquote(s):
    if s[0] == "'":
        return s[1:-1].replace("''", "'")
    return s[1:-1]


def cut_comment(v):
    """Remove a trailing comment of a value. A quoted value ends at its closing quote."""
    v = v.strip()
    if v.startswith("#"):
        return ""
    if v[:1] in ("'", '"'):
        q = v[0]
        i = 1
        while i < len(v):
            if v[i] == q:
                if q == "'" and v[i + 1:i + 2] == "'":
                    i += 2
                    continue
                break
            if v[i] == "\\" and q == '"':
                i += 1
            i += 1
        if i >= len(v):
            raise YamlError("unclosed quote: " + v)
        return v[:i + 1]
    m = re.search(r"\s#", v)
    return v[:m.start()].strip() if m else v


def scalar(v, no):
    v = cut_comment(v)
    if v == "":
        return None
    if v[0] in "&*!%@`":
        raise YamlError("line %d: anchor, alias, tag or reserved start is not in the subset: %s" % (no, v))
    if v[0] in ("'", '"'):
        return unquote(v)
    if v == "{}":
        return {}
    if v[0] == "{":
        raise YamlError("line %d: a flow mapping with keys is not in the subset" % no)
    if v[0] == "[":
        if v[-1] != "]":
            raise YamlError("line %d: a flow list must end on the same line" % no)
        inner = v[1:-1].strip()
        return [scalar(x, no) or "" for x in inner.split(",")] if inner else []
    return v


KEY = re.compile(r"""^("[^"]*"|'[^']*'|[^\s:#'"\[\]{}\-][^:]*|-[^\s:][^:]*):(?:\s+(.*))?$""")


class Reader:
    def __init__(self, text):
        self.raw = text.split("\n")
        self.i = 0
        for n, line in enumerate(self.raw, 1):
            ind = re.match(r"[ \t]*", line).group(0)
            if "\t" in ind:
                raise YamlError("line %d: tab in indentation" % n)
        if text.startswith("---") or "\n---" in text:
            raise YamlError("document markers are not in the subset")

    def peek(self):
        """Index of the next line that is not blank and not a comment, or None."""
        j = self.i
        while j < len(self.raw):
            s = self.raw[j].strip()
            if s and not s.startswith("#"):
                return j
            j += 1
        return None

    def indent(self, j):
        return len(self.raw[j]) - len(self.raw[j].lstrip(" "))

    def block(self, indent):
        j = self.peek()
        if j is None or self.indent(j) != indent:
            raise YamlError("line %d: bad indent" % ((j or 0) + 1))
        self.i = j
        if self.raw[j].lstrip().startswith("- ") or self.raw[j].strip() == "-":
            return self.seq(indent)
        return self.map(indent)

    def seq(self, indent):
        out = []
        while True:
            j = self.peek()
            if j is None or self.indent(j) != indent or not (self.raw[j].lstrip().startswith("- ") or self.raw[j].strip() == "-"):
                if j is not None and self.indent(j) > indent:
                    raise YamlError("line %d: unexpected indent" % (j + 1))
                return out
            line = self.raw[j]
            rest = line.lstrip()[1:].lstrip(" ")
            inner = indent + (len(line.lstrip()) - len(rest))
            if rest == "" or rest.startswith("#"):
                self.i = j + 1
                k = self.peek()
                if k is None or self.indent(k) <= indent:
                    out.append(None)
                else:
                    out.append(self.block(self.indent(k)))
            elif KEY.match(rest):
                self.raw[j] = " " * inner + rest
                self.i = j
                out.append(self.map(inner))
            else:
                self.i = j + 1
                out.append(scalar(rest, j + 1))

    def map(self, indent):
        out = {}
        while True:
            j = self.peek()
            if j is None:
                return out
            ind = self.indent(j)
            if ind < indent:
                return out
            if ind > indent:
                raise YamlError("line %d: unexpected indent (a multi-line plain scalar?)" % (j + 1))
            text = self.raw[j][ind:]
            if text.startswith("- ") or text == "-":
                return out
            m = KEY.match(text.rstrip())
            if not m:
                raise YamlError("line %d: not a key: %s" % (j + 1, text))
            key = m.group(1)
            if key[0] in ("'", '"'):
                key = unquote(key)
            if key in out:
                raise YamlError("line %d: duplicate key %s" % (j + 1, key))
            rest = m.group(2)
            self.i = j + 1
            rest = cut_comment(rest) if rest is not None else ""
            if rest[:1] in ("|", ">"):
                out[key] = self.literal(indent, rest)
            elif rest == "":
                k = self.peek()
                if k is not None and self.indent(k) > indent:
                    out[key] = self.block(self.indent(k))
                elif k is not None and self.indent(k) == indent and self.raw[k].lstrip().startswith("- "):
                    out[key] = self.seq(indent)
                else:
                    out[key] = None
            else:
                out[key] = scalar(rest, j + 1)

    def literal(self, indent, head):
        lines = []
        while self.i < len(self.raw):
            line = self.raw[self.i]
            if line.strip() and self.indent(self.i) <= indent:
                break
            lines.append(line)
            self.i += 1
        while lines and not lines[-1].strip():
            lines.pop()
        sizes = [len(x) - len(x.lstrip(" ")) for x in lines if x.strip()]
        cut = min(sizes) if sizes else 0
        body = [x[cut:] for x in lines]
        return ("\n".join(body) if head[0] == "|" else " ".join(x.strip() for x in body)) + ("" if head.endswith("-") else "\n")


def load(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    r = Reader(text)
    j = r.peek()
    if j is None:
        raise YamlError("empty file")
    doc = r.block(r.indent(j))
    if r.peek() is not None:
        raise YamlError("line %d: text after the document" % (r.peek() + 1))
    try:
        import yaml  # optional second parser
    except ImportError:
        return doc
    try:
        yaml.safe_load(text)
    except yaml.YAMLError as e:
        raise YamlError("PyYAML: %s" % e)
    return doc


# --- helpers over the parsed workflow ---
def jobs(doc):
    j = doc.get("jobs") if isinstance(doc, dict) else None
    return j if isinstance(j, dict) else {}


def steps(job):
    s = job.get("steps") if isinstance(job, dict) else None
    return [x for x in s if isinstance(x, dict)] if isinstance(s, list) else []


def env_of(*nodes):
    out = {}
    for n in nodes:
        e = n.get("env") if isinstance(n, dict) else None
        if isinstance(e, dict):
            out.update({k: str(v) for k, v in e.items()})
    return out


TEST_SH = re.compile(r"^[ \t]*((?:[A-Za-z_][A-Za-z_0-9]*=\S*[ \t]+)*)scripts/test\.sh[ \t]*(.*)$", re.M)


def test_runs(doc):
    """Yield (job name, job, index, step, inline env, argument text) for each step that runs scripts/test.sh."""
    for name, job in jobs(doc).items():
        for n, st in enumerate(steps(job)):
            for m in TEST_SH.finditer(str(st.get("run", ""))):
                inline = dict(a.split("=", 1) for a in m.group(1).split())
                yield name, job, n, st, inline, m.group(2).strip()


def shell_of(job, st):
    d = job.get("defaults")
    d = d.get("run") if isinstance(d, dict) else None
    return st.get("shell") or (d.get("shell") if isinstance(d, dict) else None)


def triggers(doc):
    on = doc.get("on")
    if isinstance(on, dict):
        return set(on)
    if isinstance(on, list):
        return set(on)
    return {on} if on else set()


def matrix_include(job):
    s = job.get("strategy")
    m = s.get("matrix") if isinstance(s, dict) else None
    inc = m.get("include") if isinstance(m, dict) else None
    return [x for x in inc if isinstance(x, dict)] if isinstance(inc, list) else []


def workflow(root, name, fails):
    p = os.path.join(root, ".github", "workflows", name)
    if not os.path.isfile(p):
        fails.append("%s is missing" % os.path.relpath(p, root))
        return None
    try:
        return load(p)
    except YamlError as e:
        fails.append("%s: %s" % (name, e))
        return None


def cache_steps(doc):
    for name, job in jobs(doc).items():
        for st in steps(job):
            if str(st.get("uses", "")).startswith("actions/cache"):
                w = st.get("with") if isinstance(st.get("with"), dict) else {}
                yield name, str(w.get("path", "")), str(w.get("key", "")), w


# --- the checks ---
def check_yaml(root, fails):
    files = sorted(glob.glob(os.path.join(root, ".github", "workflows", "*.y*ml")))
    names = [os.path.basename(f) for f in files]
    for need in ("ci.yml", "nightly.yml"):
        if need not in names:
            fails.append(".github/workflows/%s is missing" % need)
    for f in files:
        n = os.path.basename(f)
        try:
            doc = load(f)
        except YamlError as e:
            fails.append("%s: %s" % (n, e))
            continue
        if not isinstance(doc, dict):
            fails.append("%s: the top level is not a mapping" % n)
            continue
        for k in ("name", "on", "permissions", "jobs"):
            if k not in doc:
                fails.append("%s: top-level key %s is missing" % (n, k))
        perm = doc.get("permissions")
        if not (isinstance(perm, dict) and perm.get("contents") == "read"):
            fails.append("%s: permissions must be `contents: read` (least privilege)" % n)
        if not jobs(doc):
            fails.append("%s: no job" % n)
        for jn, job in jobs(doc).items():
            if "runs-on" not in job:
                fails.append("%s: job %s has no runs-on" % (n, jn))
            if not re.fullmatch(r"\d+", str(job.get("timeout-minutes", ""))):
                fails.append("%s: job %s has no timeout-minutes (a number)" % (n, jn))
            if not steps(job):
                fails.append("%s: job %s has no steps" % (n, jn))
            for st in steps(job):
                u = st.get("uses")
                if u is None and "run" not in st:
                    fails.append("%s: job %s has a step with no uses and no run" % (n, jn))
                if u is not None and not u.startswith("./") and not re.search(r"@(v\d+(\.\d+){0,2}|[0-9a-f]{40})$", u):
                    fails.append("%s: action %s is not pinned (a major tag `@v<N>` or a 40 digit sha)" % (n, u))


def check_fast(root, fails):
    doc = workflow(root, "ci.yml", fails)
    if doc is None:
        return
    for t in ("push", "pull_request"):
        if t not in triggers(doc):
            fails.append("ci.yml: no `%s` trigger" % t)
    runs = list(test_runs(doc))
    if not runs:
        fails.append("ci.yml: no step runs scripts/test.sh")
    got = {}
    for name, job, n, st, inline, args in runs:
        if job.get("runs-on") != "${{ matrix.os }}":
            fails.append("ci.yml: job %s must have `runs-on: ${{ matrix.os }}`" % name)
        if args != "${{ matrix.steps }}":
            fails.append("ci.yml: job %s runs `scripts/test.sh %s`, it must pass `${{ matrix.steps }}`" % (name, args))
        if shell_of(job, st) != "bash":
            fails.append("ci.yml: job %s: the test step needs `shell: bash` (the default on Windows is PowerShell)" % name)
        env = env_of(doc, job, st)
        env.update(inline)
        for v in ("OPT", "SLOW", "NET", "REAL_ROC"):
            if v in env:
                fails.append("ci.yml: job %s sets %s: the fast set has no such variable (TW20, TW25, TW27)" % (name, v))
        inc = matrix_include(job)
        for e in inc:
            got[str(e.get("os", "")).split("-")[0]] = e.get("steps")
    for osn, want in (("ubuntu", ""), ("macos", ""), ("windows", "check fmt l0")):
        if osn not in got:
            fails.append("ci.yml: the matrix (include) has no %s entry" % osn)
        elif (got[osn] or "") != want:
            fails.append("ci.yml: matrix steps of %s are `%s`, must be `%s`" % (osn, got[osn] or "", want))
    # Linux: bubblewrap for the network cut of L3 (tests/lib.sh netoff). Ubuntu 24.04 blocks user namespaces by default.
    lin = [st for job in jobs(doc).values() for st in steps(job) if "Linux" in str(st.get("if", ""))]
    if not any("bubblewrap" in str(s.get("run", "")) and "apparmor_restrict_unprivileged_userns=0" in str(s.get("run", "")) for s in lin):
        fails.append("ci.yml: no step `if: runner.os == 'Linux'` that installs bubblewrap and sets kernel.apparmor_restrict_unprivileged_userns=0")


def check_nightly(root, fails):
    doc = workflow(root, "nightly.yml", fails)
    if doc is None:
        return
    on = doc.get("on")
    sched = on.get("schedule") if isinstance(on, dict) else None
    crons = [x.get("cron") for x in sched if isinstance(x, dict)] if isinstance(sched, list) else []
    if not crons or not all(isinstance(c, str) and len(c.split()) == 5 for c in crons):
        fails.append("nightly.yml: `on.schedule` needs a list with `cron: <5 fields>`")
    for t in ("workflow_dispatch",):
        if t not in triggers(doc):
            fails.append("nightly.yml: no `%s` trigger (the merge run by hand)" % t)
    for t in ("push", "pull_request"):
        if t in triggers(doc):
            fails.append("nightly.yml: has a `%s` trigger: the nightly run is not for each change" % t)
    runs = list(test_runs(doc))
    if not runs:
        fails.append("nightly.yml: no step runs scripts/test.sh")
    for name, job, n, st, inline, args in runs:
        env = env_of(doc, job, st)
        env.update(inline)
        for k, v in (("OPT", "speed"), ("SLOW", "1"), ("NET", "1"), ("REAL_ROC", "1")):
            if env.get(k) != v:
                fails.append("nightly.yml: job %s must set %s=%s for scripts/test.sh (got %s)" % (name, k, v, env.get(k)))
        if "GITHUB_TOKEN" not in env and "GH_TOKEN" not in env:
            fails.append("nightly.yml: job %s must give GITHUB_TOKEN to the test step (the net cases call api.github.com, R-RG3)" % name)
        if args:
            fails.append("nightly.yml: job %s runs `scripts/test.sh %s`: the nightly run has all steps" % (name, args))
        if not str(job.get("runs-on", "")).startswith("ubuntu"):
            fails.append("nightly.yml: job %s must run on ubuntu" % name)
    for name, path, key, w in cache_steps(doc):
        if ".work/cache" in path:
            fails.append("nightly.yml: job %s caches the roc package cache: the nightly run must download the packages again (R-FE6)" % name)


def check_pin(root, fails):
    script = os.path.join(root, "scripts", "get-roc.sh")
    env_sh = open(os.path.join(root, "scripts", "env.sh"), encoding="utf-8").read()
    pinned = re.findall(r"nightly-\d{4}-\d{2}-\d{2}-[0-9a-f]+", env_sh)
    m = re.search(r"^ROC_TAG=\$\{ROC_TAG:-(nightly-\d{4}-\d{2}-\d{2}-[0-9a-f]+)\}$", env_sh, re.M)
    if not m:
        fails.append("scripts/env.sh: no line `ROC_TAG=${ROC_TAG:-nightly-<date>-<sha>}`")
    elif m.group(1) != "nightly-2026-10-14-38a3029":
        fails.append("scripts/env.sh: ROC_TAG is %s, the pin is nightly-2026-10-14-38a3029 (docs/slices/PLAN.md)" % m.group(1))
    if len(pinned) != 1:
        fails.append("scripts/env.sh: the nightly tag must be in the text once (ROC_TAG), found %d" % len(pinned))
    roc_line = re.search(r"^ROC=\$\{ROC:-(.*)\}$", env_sh, re.M)
    if not roc_line or not re.search(r"\$\{?ROC_TAG\}?", roc_line.group(1)):
        fails.append("scripts/env.sh: the default of ROC must use $ROC_TAG")
    elif m and env_sh.index("ROC_TAG=") > roc_line.start():
        fails.append("scripts/env.sh: ROC_TAG must be set before the ROC line")
    if not os.path.isfile(script):
        fails.append("scripts/get-roc.sh is missing")
    else:
        t = open(script, encoding="utf-8").read()
        if not os.access(script, os.X_OK):
            fails.append("scripts/get-roc.sh is not executable")
        if t.split("\n", 1)[0] != "#!/usr/bin/env bash":
            fails.append("scripts/get-roc.sh: the first line must be `#!/usr/bin/env bash`")
        for word in ("env.sh", "ROC_TAG", "roc-lang/nightlies", "linux_x86_64", "macos_apple_silicon", "windows_x86_64", "sha256", "digest"):
            if word not in t:
                fails.append("scripts/get-roc.sh does not mention %s" % word)
        if re.search(r"nightly-\d{4}-", t):
            fails.append("scripts/get-roc.sh has a literal nightly tag: the tag comes from scripts/env.sh only")
    for name in ("ci.yml", "nightly.yml"):
        doc = workflow(root, name, fails)
        if doc is None:
            continue
        p = os.path.join(root, ".github", "workflows", name)
        text = open(p, encoding="utf-8").read()
        if re.search(r"nightly-\d{4}-", text):
            fails.append("%s: a literal nightly tag: the tag comes from scripts/env.sh only" % name)
        for bad in ("cloudflare-workers", ".cache/nightlies"):
            if bad in text:
                fails.append("%s: uses %s, a local path that CI does not have" % (name, bad))
        run_idx = {}
        for jn, job in jobs(doc).items():
            ss = steps(job)
            get = [n for n, s in enumerate(ss) if re.search(r"scripts/get-roc\.sh", str(s.get("run", "")))]
            if not get:
                fails.append("%s: job %s has no step that runs scripts/get-roc.sh" % (name, jn))
                continue
            body = str(ss[get[0]].get("run", ""))
            if "GITHUB_ENV" not in body or not re.search(r"\bROC=", body):
                fails.append("%s: job %s: the get-roc step must write ROC=<path> to $GITHUB_ENV" % (name, jn))
            tags = [n for n, s in enumerate(ss) if "ROC_TAG" in str(s.get("run", "")) and "GITHUB_ENV" in str(s.get("run", ""))]
            if not tags:
                fails.append("%s: job %s: no step writes ROC_TAG (from scripts/env.sh) to $GITHUB_ENV" % (name, jn))
            for n, st in enumerate(ss):
                if re.search(r"^\s*(?:\w+=\S*\s+)*scripts/test\.sh", str(st.get("run", "")), re.M) and n < get[0]:
                    fails.append("%s: job %s runs the tests before get-roc" % (name, jn))
        binc = [(n, p, k, w) for n, p, k, w in cache_steps(doc) if "nightlies" in p]
        if not binc:
            fails.append("%s: no cache step for the roc binary (path with `nightlies`)" % name)
        for n, p, k, w in cache_steps(doc):
            if "runner.os" not in k:
                fails.append("%s: cache key `%s` has no runner.os" % (name, k))
        for n, p, k, w in binc:
            if "env.ROC_TAG" not in k or "restore-keys" in w:
                fails.append("%s: the roc binary cache key must have env.ROC_TAG and no restore-keys (another tag must not restore)" % name)
        if name == "ci.yml":
            pk = [(n, p, k, w) for n, p, k, w in cache_steps(doc) if ".work/cache" in p]
            if not pk:
                fails.append("ci.yml: no cache step for the roc package cache (path `.work/cache/roc`)")
            for n, p, k, w in pk:
                if "hashFiles(" not in k and "steps." not in k:
                    fails.append("ci.yml: the package cache key needs a hash of the header URLs (hashFiles or a step output)")


def check_portable(root, fails):
    shells = sorted(set(glob.glob(os.path.join(root, "scripts", "*.sh")) + glob.glob(os.path.join(root, "tests", "*.sh")) +
                        glob.glob(os.path.join(root, "tests", "commands", "*.sh")) + glob.glob(os.path.join(root, "tests", "tools", "*.sh"))))
    for f in shells:
        t = open(f, encoding="utf-8").read()
        rel = os.path.relpath(f, root)
        first = t.split("\n", 1)[0]
        if re.search(r"\bmapfile\b|\breadarray\b|\bdeclare -A\b", t) and first != "#!/usr/bin/env bash":
            fails.append("%s: uses bash 4 features, the first line must be `#!/usr/bin/env bash` (macOS /bin/bash is 3.2), found `%s`" % (rel, first))
        if re.search(r"\|\s*bc\b|\$\(\s*bc\b", t):
            fails.append("%s: uses bc (Git Bash on Windows has none): use awk" % rel)
    doc = workflow(root, "ci.yml", fails)
    if doc is None:
        return
    mac = [st for job in jobs(doc).values() for st in steps(job) if "macOS" in str(st.get("if", ""))]
    body = "\n".join(str(s.get("run", "")) for s in mac)
    if "brew install" not in body:
        fails.append("ci.yml: no step `if: runner.os == 'macOS'` with `brew install`")
    for pkg in ("bash", "coreutils", "findutils", "diffutils"):
        if not re.search(r"brew install[^\n]*\b%s\b" % pkg, body):
            fails.append("ci.yml: the macOS step does not install %s (the scripts need GNU tools)" % pkg)
    if "GITHUB_PATH" not in body or "gnubin" not in body:
        fails.append("ci.yml: the macOS step must put the gnubin dirs and brew bash first on PATH (GITHUB_PATH)")


CHECKS = {"yaml": check_yaml, "fast": check_fast, "nightly": check_nightly, "pin": check_pin, "portable": check_portable}

if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in CHECKS:
        print("usage: ciscan.py <%s> <repo root>" % "|".join(CHECKS))
        sys.exit(2)
    fails = []
    try:
        CHECKS[sys.argv[1]](sys.argv[2], fails)
    except (OSError, YamlError) as e:
        fails.append("%s" % e)
    for x in fails:
        print("FAIL: " + x)
    sys.exit(1 if fails else 0)
