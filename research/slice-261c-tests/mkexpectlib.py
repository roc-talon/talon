# Slice 261c (test agent): helpers of mk-expect.py and mk-old.py (the check calls of the proposal of docs/slices/261-log-inclusion-proofs.md section 14.3).
import json, os, shutil, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCRATCH = os.path.join(ROOT, ".tmp/s261c-expect")
UA = "  User-Agent: tln/0.0.1"


def read(p):
    with open(p) as f:
        return f.read()


def put(p, text):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as f:
        f.write(text)


def runs_of(lines):
    """The calls of each run (a run starts with the line `args`)."""
    out = []
    for l in lines:
        if l == "args":
            out.append([])
        out[-1].append(l)
    return out


def post_end(run):
    """The index after the block of the last closure POST of a run (the check point: after the pick)."""
    i = max(k for k, l in enumerate(run) if l.startswith("http_send POST ") and l.endswith("/v1/closure timeout=20"))
    i += 1
    while i < len(run) and run[i].startswith("  "):
        i += 1
    return i


class Log:
    """The registry `base` (R-RG7 form) and its <origin> dir (R-IX1)."""

    def __init__(self, base, origin):
        self.base, self.origin = base, origin
        self.kept = f"$HOME/.local/share/talon/log/{origin}/checkpoint"
        self.copy = f"$HOME/.cache/roc/talon/index/registry/{origin}/log/"

    def read_kept(self):
        return [f"read_files {self.kept}"]

    def get_checkpoint(self, sleeps=()):
        out = [f"http_get {self.base}/log/checkpoint", UA]
        for ms in sleeps:
            out += [f"sleep {ms}", f"http_get {self.base}/log/checkpoint", UA]
        return out

    def read_copies(self, tiles):
        return ["read_files " + " ".join(self.copy + t for t in tiles)]

    def fetch(self, tiles):
        return [x for t in tiles for x in (f"http_get_bytes {self.base}/log/{t}", UA)]

    def write(self, tiles, checkpoint=True):
        return ["write_atomic " + " ".join([self.copy + t for t in tiles] + ([self.kept] if checkpoint else []))]


def copies_of(spec_dir, size, origin, leaves):
    """The text copies of R-IX8 of the tree of `size` (mk-log.mjs `kept` in a scratch dir) and the checkpoint text that the fake serves (the served file)."""
    d = os.path.join(SCRATCH, "copies", f"{origin}-{size}")
    if os.path.isdir(d):
        shutil.rmtree(d)
    os.makedirs(d)
    spec = read(os.path.join(spec_dir, "mk-log.json"))
    js = json.loads(spec)
    js.pop("serve", None), js.pop("tamper", None), js.pop("omit", None)
    js["leaves"] = leaves
    js["kept"] = {"size": size, "home": "home"}
    put(os.path.join(d, "mk-log.json"), json.dumps(js))
    subprocess.run(["node", os.path.join(ROOT, "tests/tools/mk-log.mjs"), d], check=True, capture_output=True)
    out = {}
    base = os.path.join(d, "home")
    for dp, _, fs in os.walk(base):
        for f in fs:
            p = os.path.join(dp, f)
            rel = os.path.relpath(p, base)
            if rel.startswith(".local"):
                continue
            out[rel] = read(p)
    return out
