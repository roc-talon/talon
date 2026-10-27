# Slice 087 revert check: apply one mutation (name), or restore all files (restore).
import sys, shutil, os
M = {
 "m1": ("cli/lib/RunPlan.roc", "Signaled(n) => (128 + n, Bool.False)", "Signaled(n) => (128 + n, facts.ok_exit.contains((128 + n).to_u8_wrap()))"),
 "m2": ("cli/lib/RunPlan.roc", "c == 0 or (c >= 0 and c <= 255 and facts.ok_exit.contains(c.to_u8_wrap()))", "c == 0 or facts.ok_exit.contains(c.to_u8_wrap())"),
 "m3": ("cli/lib/RunSteps.roc", "Ok(Roc(rest)) => Ok(Proxy.ended!(", "Ok(Roc(rest)) => Ok(Exited(Proxy.run!("),
 "m4": ("cli/lib/RunPlan.roc", "if sel.starts_with(\"+\") => is_warn_sub(sub)", "if sel.starts_with(\"+++\") => is_warn_sub(sub)"),
 "m5": ("cli/lib/ScriptsToml.roc", "if line.starts_with(\"@\") Err(At(", "if line.starts_with(\"@@\") Err(At("),
 "m6": ("cli/lib/RunSteps.roc", "Ok(note) => fx.err!(\"${note}\\n\")", "Ok(_) => {}"),
 "m7": ("cli/lib/RunPlan.roc", "and !pass and facts.ok_exit.is_empty() and", "and !pass and"),
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
s = s.replace(old, new)
if sys.argv[1] == "m3":
    s = s.replace('program_name!: || "roc" }))\n\t\t\t\tOk(Tln', 'program_name!: || "roc" })))\n\t\t\t\tOk(Tln', 1)
open(f, "w").write(s)
