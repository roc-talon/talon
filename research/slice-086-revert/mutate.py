# Slice 086 revert check: apply one mutation (name), or restore all files (restore).
import sys, shutil, os
M = {
 "m1": ("cli/lib/NoRank.roc", "project: run.toml.min_age, user: config.min_release_age", "project: Err(Unset), user: config.min_release_age"),
 "m2": ("cli/lib/NoRank.roc", "toml: run.toml.nightly, config: config.nightly", "toml: Err(Unset), config: config.nightly"),
 "m3": ("cli/lib/PathFlow.roc", "Ok({ exclude: resolution.min_release_age_exclude,", "Ok({ exclude: [],"),
 "m4": ("cli/lib/Project.roc", "Ok(d) => d.toml.map_err(|_| NoToml)", "Ok(_) => Err(NoToml)"),
 "m5": ("cli/lib/ResolveBase.roc", "toml = { min_age: loaded.intent.resolution.min_release_age,", "toml = { min_age: Err(Unset),"),
 "m6": ("cli/lib/NoRank.roc", "toml: facts.run.?toml ?? NoRank.no_toml })?", "toml: NoRank.no_toml })?"),
}
here = os.path.dirname(os.path.abspath(__file__))
if sys.argv[1] == "restore":
    for f in set(v[0] for v in M.values()):
        b = os.path.join(here, "orig", os.path.basename(f))
        if os.path.exists(b): shutil.copy(b, f)
    sys.exit(0)
f, old, new = M[sys.argv[1]]
os.makedirs(os.path.join(here, "orig"), exist_ok=True)
b = os.path.join(here, "orig", os.path.basename(f))
if not os.path.exists(b): shutil.copy(f, b)
s = open(f).read(); assert s.count(old) == 1, old
open(f, "w").write(s.replace(old, new))
