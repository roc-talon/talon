# Revert check of slice 108 (TW12): apply one mutation, run one layer, put the code back.
# Usage: python3 research/slice-108/mutate.py <id>
import subprocess, sys, shutil, os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
M = {
 "m1-bearer-case": ("worker/lib/Oidc.roc", 'scheme.caseless_ascii_equals("bearer")', 'scheme == "Bearer"', "w0"),
 "m2-reread-bound": ("worker/lib/Oidc.roc", "if (age > reread_after_ms) Reload", "if (age >= reread_after_ms) Reload", "w0"),
 "m3-nbf-underflow": ("worker/lib/Oidc.roc", "nbf.minus_saturated(leeway_s).times_saturated(1000)", "(nbf - leeway_s) * 1000", "w0"),
 "m4-b64-len": ("worker/lib/Oidc.roc", "if bytes.len() % 4 == 1 {", "if bytes.len() % 4 == 5 {", "w0"),
 "m5-empty-sig": ("worker/lib/Oidc.roc", "if signature.is_empty() {", "if Bool.False {", "w0"),
 "m6-repo-case": ("worker/lib/Oidc.roc", "!repository.caseless_ascii_equals(asset.owner_repo)", "repository != asset.owner_repo", "w0"),
 "m7-no-clear": ("worker/Auth.roc", "\t\t\t\tjwks.clear!()\n", "", "w2"),
 "m8-status": ("worker/Auth.roc", "if status != 200 {", "if status == 1 {", "w2"),
 "m9-max-age-first": ("worker/lib/Oidc.roc", "if age > max_age_ms {", "if Bool.False {", "w0"),
}
f, old, new, layer = M[sys.argv[1]]
p = os.path.join(ROOT, f)
keep = open(p).read()
assert keep.count(old) == 1, old
open(p, "w").write(keep.replace(old, new))
try:
    r = subprocess.run(["scripts/test.sh", layer], cwd=ROOT, capture_output=True, text=True)
    print(sys.argv[1], "rc", r.returncode)
    log = open(os.path.join(ROOT, ".work/logs", layer + ".log")).read()
    for line in log.splitlines():
        if line.startswith("FAIL") or "failed" in line or "crash" in line.lower():
            print("  ", line[:160])
finally:
    open(p, "w").write(keep)
