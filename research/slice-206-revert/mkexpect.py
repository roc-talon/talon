#!/usr/bin/env python3
# Slice 206, manager answers Q390 to Q392: the expected files of the new cases, written from the rules (not from a run of the code).
# Run from the repo root after mkcases.py: python3 -I research/slice-206-revert/mkexpect.py
import os, subprocess, tempfile, shutil
ROOT = os.getcwd()
L2 = os.path.join(ROOT, "tests/commands/cases/registry")
UA = "tln/0.0.1"  # Help.version, as in the other registry cases
GET = "$HOME/.cache/roc/talon/index/registry/http_127.0.0.1_9/get"

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(text)

def read(path):
    return open(path).read()

h2 = "2CLmeph6kVSdi6orXdVymPEDaudFDtB28sm3zpnsvmGN"
json2 = f"https://github.com/someone/roc-json/releases/download/1.1.0/{h2}.tar.zst"
G_JSON = "github.com/someone/roc-json/releases/download/{v}/"

# Q390, R-AP18: ap18-closure-log-size.
d = os.path.join(L2, "ap18-closure-log-size/expect")
line = f"== closure group={G_JSON} name=someone/roc-json\n"
write(f"{d}/stdout", line + "log_size 40\nreleases 1\nartifacts 1\n"
      f"candidate someone/roc-json 1.1.0 1.1.0 1791194400 3400 {json2}\n" + line + "exit 15\n")
write(f"{d}/stderr", f"tln: error[network]: the answer of the registry http://127.0.0.1:9 is not a closure answer: the release {json2} has the log index 41, above the log size 40\n")
post = (f"http_send POST http://127.0.0.1:9/v1/closure timeout=20\n  User-Agent: {UA}\n  Content-Type: application/json\n"
        f"  <body> {{\"groups\":[{{\"group\":\"{G_JSON}\"}}],\"hashes\":[]}}\n")
write(f"{d}/calls.log", "env_all\n" + post + post)
write(f"{d}/exit", "0\n")
write(f"{d}/tree.diff", "")

# Q391, R-IX6 per group: ix6-offline-groups.
c = os.path.join(L2, "ix6-offline-groups")
d = c + "/expect"
k = "728ee13ade9201bf3df3b7d22a57d179"
hb = "6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL"
p4 = "/v1/releases?group=github.com%2Fsomeone%2Froc-b%2Freleases%2Fdownload%2Fv%7Bv%7D%2F"
body = read(f"{c}/fx/http/127.0.0.1%3A9/v1/releases%3Fgroup=github.com%252Fsomeone%252Froc-b%252Freleases%252Fdownload%252Fv%257Bv%257D%252F")
runs = read(f"{c}/fx/runs").splitlines()
url_b1 = f"https://github.com/someone/roc-b/releases/download/v1.0.0/{hb}.tar.zst"
write(f"{d}/stdout", f"== {runs[0]}\nstatus: 200\nsource: live\nbody: {body}\n"
      f"== {runs[1]}\ncandidate someone/roc-b 1.0.0 v1.0.0 1790000000 0 {url_b1}\n"
      "missing-group someone/roc-b github.com/someone/roc-b/releases/download/{v}/\n")
write(f"{d}/stderr", "index: cached at 2026-10-14T15:00:00Z\n")
write(f"{d}/calls.log", "env_all\n"
      f"list_dirs {GET}\nhttp_get http://127.0.0.1:9{p4}\n  User-Agent: {UA}\n"
      f"write_atomic {GET}/{k}.json {GET}/{k}.meta\n"
      f"list_dirs {GET}\nread_files {GET}/{k}.meta {GET}/{k}.json\n"
      f"list_dirs {GET}\n"
      f"list_dirs {GET}\n")
write(f"{d}/exit", "0\n")
G = "home/.cache/roc/talon/index/registry/http_127.0.0.1_9/get"
write(f"{d}/tree.diff",
      f"--- {G}/{k}.json\n+++ {G}/{k}.json\n@@ -0,0 +1 @@\n+{body}\n\\ No newline at end of file\n"
      f"--- {G}/{k}.meta\n+++ {G}/{k}.meta\n@@ -0,0 +1,3 @@\n+url {p4}\n+etag \"e1\"\n+max-age 60\n")
print("ok")
