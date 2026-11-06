"""Helpers of mkcases.py (slice 206f): the hand-made fixtures. No code of cli/ is used."""
import json, os, re, shutil, datetime

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CASES = os.path.join(ROOT, "tests", "commands", "cases")
REF = os.path.join(ROOT, "research", "slice-206f-revert", "ref", "cases")
HOST = "127.0.0.1%3A9"


def w(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def rd(path):
    with open(path) as f:
        return f.read()


def fresh(path):
    shutil.rmtree(path, ignore_errors=True)
    os.makedirs(path)


def copy_tree(src, dst):
    shutil.copytree(src, dst, symlinks=True, dirs_exist_ok=True)


def ms(iso):
    t = datetime.datetime.strptime(iso, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc)
    return int(t.timestamp()) * 1000


def series(version):
    a, b, _ = version.split(".")
    return a if int(a) > 0 else "%s.%s" % (a, b)


def ap1_body(repo, gh_json):
    """R-AP1 answer (Registry 4, `GET /v1/packages/{owner}/{repo}/releases`) from a GitHub list: the candidates only."""
    out = []
    for i, rel in enumerate(json.loads(gh_json)):
        if rel["draft"] or rel["prerelease"]:
            continue
        assets = [a for a in rel["assets"] if a["name"].endswith(".tar.zst")]
        if len(assets) != 1:
            continue
        h = assets[0]["name"][: -len(".tar.zst")]
        ver = rel["tag_name"]
        out.append({"log_index": len(out) + 1, "hash": h,
                    "group": "github.com/%s/releases/download/{v}/" % repo,
                    "series": series(ver), "version": ver,
                    "url": assets[0]["browser_download_url"], "tag": ver, "roc_version": None, "repo": repo,
                    "published_at": ms(rel["published_at"]), "yanked": False, "yank_reason": None,
                    "withdrawn": None, "provenance": ["ingest"]})
    return json.dumps({"releases": out, "checked": None, "repos": []}, separators=(",", ":"))


def http_dir(case):
    return os.path.join(case, "fx", "http")


def put_registry_list(case, repo, body):
    base = os.path.join(http_dir(case), HOST, "v1", "packages", *repo.split("/"))
    w(os.path.join(base, "releases"), body)
    w(os.path.join(base, "releases.meta"),
      "status 200\nheader Content-Type: application/json\nheader ETag: \"r1\"\nheader Cache-Control: max-age=60\nrequire-none authorization\nrequire-none cache-control\n")


def put_guard(case, repo, rid=1):
    base = os.path.join(http_dir(case), "api.github.com", "repos", *repo.split("/"))
    w(os.path.join(base, "@"), '{"id":%d,"full_name":"%s","private":false,"fork":false}' % (rid, repo))
    w(base + ".meta", "status 200\nheader Content-Type: application/json\n")


def hunks(diff_text):
    """Split a tree.diff into hunks keyed by the path of the `---` line."""
    out, cur = {}, None
    for line in diff_text.splitlines(keepends=True):
        if line.startswith("--- "):
            cur = line[4:].strip()
            out[cur] = ""
        out[cur] += line
    return out


def hunk_new(path, content):
    """The hunk of a new file (no newline at the end of the content, as the fake writes it)."""
    lines = content.split("\n")
    if content.endswith("\n"):
        body = "".join("+%s\n" % l for l in lines[:-1])
        n = len(lines) - 1
        tail = ""
    else:
        body = "".join("+%s\n" % l for l in lines[:-1]) + "+%s\n" % lines[-1]
        n = len(lines)
        tail = "\\ No newline at end of file\n"
    rng = "+1" if n == 1 else "+1,%d" % n
    return "--- %s\n+++ %s\n@@ -0,0 %s @@\n%s%s" % (path, path, rng, body, tail)


def join_hunks(h):
    return "".join(h[k] for k in sorted(h, key=lambda s: s.encode()))


def guard_lines(repo, token=None, gh=True):
    """The calls of the privacy guard for a repository with no kept answer (slice 203, `FullName.read!`)."""
    d = "$HOME/.cache/roc/talon/index/github/%s" % repo
    out = ["read_files %s/repo.json" % d]
    if token is None and gh:
        out.append("programs gh")
    out += ["http_get https://api.github.com/repos/%s" % repo, "  User-Agent: tln/0.0.1"]
    if token:
        out.append("  Authorization: Bearer %s" % token)
    out.append("write_atomic %s/repo.json" % d)
    return out


def registry_get_lines(repo, md5, write=True):
    d = "$HOME/.cache/roc/talon/index/registry/http_127.0.0.1_9/get"
    out = ["list_dirs %s" % d, "http_get http://127.0.0.1:9/v1/packages/%s/releases" % repo, "  User-Agent: tln/0.0.1"]
    if write:
        out.append("write_atomic %s/%s.json %s/%s.meta" % (d, md5, d, md5))
    return out


P1_MAIN = 'app [main!] {\n\tpf: platform "https://github.com/acme/pfx/releases/download/0.1.0/6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL.tar.zst",\n\troc: "nightly-2026-10-14-38a3029",\n}\n\nmain! = |_args| Ok({})\n'
REG_CONFIG = 'registry = "http://127.0.0.1:9"\n'


def first_prefix(base=None):
    """The calls of a first run on project p1 (no talon.toml) up to the read of the three files (a baseline of the direct code, recorded)."""
    return ["args", "env_all", "tty", "env_all", "clock", "cwd", "canonical $PROJECT/p1/main.roc", "list_dirs $PROJECT/p1", "list_dirs $PROJECT",
            "read_files $PROJECT/p1/main.roc", "canonical $PROJECT/p1/main.roc", "lock $HOME/.cache/roc/talon/projects.json nowait: held",
            "list_dirs $HOME/.cache/roc/talon", "read_files $HOME/.cache/roc/talon/projects.json", "write_atomic $HOME/.cache/roc/talon/projects.json",
            "unlock $HOME/.cache/roc/talon/projects.json", "path_roc", "read_files $HOME/.cache/roc/talon/path-roc.json", "spawn_all limit=1",
            "  job - /fake/bin/roc version", "write_atomic $HOME/.cache/roc/talon/path-roc.json",
            "read_files $PROJECT/p1/main.roc $PROJECT/p1/talon.toml $HOME/.config/talon/config.toml"]


def later_prefix():
    """The calls of a run of a project that projects.json has already (the pattern of registry/al2-install-query run 2, no talon.toml)."""
    return ["args", "env_all", "env_all", "clock", "cwd", "canonical $PROJECT/p1/main.roc", "list_dirs $PROJECT/p1", "list_dirs $PROJECT",
            "read_files $PROJECT/p1/main.roc", "canonical $PROJECT/p1/main.roc", "lock $HOME/.cache/roc/talon/projects.json nowait: held",
            "list_dirs $HOME/.cache/roc/talon", "read_files $HOME/.cache/roc/talon/projects.json", "unlock $HOME/.cache/roc/talon/projects.json",
            "path_roc", "read_files $HOME/.cache/roc/talon/path-roc.json",
            "read_files $PROJECT/p1/main.roc $PROJECT/p1/talon.toml $HOME/.config/talon/config.toml"]


def first_tree_hunks(base=None):
    p = "home/.cache/roc/talon/projects.json"
    return {p: hunk_new(p, '{"format":1,"projects":[{"path":"$PROJECT/p1/main.roc","last_use":1792065600}]}')}


def command_case(new, srcs_fx, cmds, runs, rules, env_extra="GITHUB_TOKEN=tok1\n", given_extra=None):
    """A whole-command case on project p1 with the registry in config.toml.
    runs: a list of dicts {calls, stdout, stderr} (the expected text of each run, in order); the tree is built by the caller."""
    dst = os.path.join(CASES, new)
    fresh(dst)
    w(os.path.join(dst, "entry"), "commands\n")
    for src in srcs_fx:
        copy_tree(os.path.join(CASES, src, "fx"), os.path.join(dst, "fx"))
    runs_file = os.path.join(dst, "fx", "runs")
    if os.path.exists(runs_file):
        os.remove(runs_file)
    al2 = os.path.join(CASES, "registry/al2-install-query")
    for f in ("gitdirs", "jobs", "path-roc"):
        shutil.copy(os.path.join(al2, "fx", f), os.path.join(dst, "fx", f))
    w(os.path.join(dst, "fx", "env"), "HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\n" + env_extra)
    w(os.path.join(dst, "fx", "programs"), "roc\ncurl\n")
    w(os.path.join(dst, "fx", "commands"), "".join(c + "\n" for c in cmds))
    w(os.path.join(dst, "given", "project", "p1", "main.roc"), P1_MAIN)
    w(os.path.join(dst, "given", "home", ".config", "talon", "config.toml"), REG_CONFIG)
    w(os.path.join(dst, "rules"), rules)
    return dst


def strip_env(lines):
    return [l for l in lines if l != "env_all"][0:] if lines and lines[0] == "env_all" else lines


def run_stdout(cmd, code, text=""):
    return "== %s\n%sexit %d\n" % (cmd, text, code)
