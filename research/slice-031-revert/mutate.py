#!/usr/bin/env python3
# Slice 031 revert check (TW12): one change at a time in the private reference, run the steps that can see it, write the result.
# Usage: mutate.py [id ...]   (no id: all)   Run with the reference in the tree (swap.sh ref). Steps run one after the other (one scripts/test.sh at a time).
import os, subprocess, sys, shutil
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
os.chdir(ROOT)
REF = 'research/slice-031-revert/reference/'
L = 'cli/lib/'
M = []
STEPS = {'Probe.roc': 'l0:probe l0:units', 'Opts.roc': 'l0:opts l3f:update/up2', 'Intent.roc': 'l0:intent', 'ResolveBase.roc': 'l2', 'Units.roc': 'l0:units', 'Uses.roc': 'l0:uses', 'Ladder.roc': 'l2', 'RealJobs.roc': 'l3f:fx/pl1', 'RemoveFlow.roc': 'l2', 'VerifyFlow.roc': 'l2'}
def m(id, rule, file, old, new, steps=None):
    steps = steps or STEPS[os.path.basename(file)]
    M.append(dict(id=id, rule=rule, file=file, old=old, new=new, steps=steps))

# Probe.roc
m('pw1', 'R-PP6', L+'Probe.roc', 'Check => 1\n\t\tBuild(_) => 4', 'Check => 1\n\t\tBuild(_) => 1')
m('pw2', 'R-PP6', L+'Probe.roc', 'Check => 1\n\t\tBuild(_) => 4', 'Check => 2\n\t\tBuild(_) => 4')
m('ps1', 'R-LY4', L+'Probe.roc', 'pick(layers.flag_slots, layers.project.slots, layers.user.slots)', 'pick(Err(Unset), layers.project.slots, layers.user.slots)')
m('ps2', 'R-LY4', L+'Probe.roc', 'pick(Err(Unset), layers.project.timeout, layers.user.timeout) ?? 30', 'pick(Err(Unset), layers.user.timeout, layers.project.timeout) ?? 30')
m('ps3', 'R-P5', L+'Probe.roc', 'layers.user.max) ?? 100', 'layers.user.max) ?? 50')
m('ps4', 'R-PP7', L+'Probe.roc', 'layers.user.slots) ?? 12', 'layers.user.slots) ?? 8')
m('ps5', 'R-P5', L+'Probe.roc', 'layers.user.max_toolchains) ?? 10', 'layers.user.max_toolchains) ?? 5')
m('ps6', 'R-P5', L+'Probe.roc', 'layers.user.timeout) ?? 30', 'layers.user.timeout) ?? 60')
# Opts.roc
m('op1', 'R-FL11', L+'Opts.roc', 'Ok(n) if n >= 1 =>', 'Ok(n) if n >= 0 =>', 'check l0 l3')
m('op2', 'R-FL11', L+'Opts.roc', 'value_of(args, "--slots")', 'value_of(args, "--slot")', 'check l0 l3')
# Intent.roc
m('in1', 'R-P5', L+'Intent.roc', 'one("timeout", 1)', 'one("timeout", 0)')
m('in2', 'R-P5', L+'Intent.roc', 'one("slots", 1)', 'one("slots", 0)')
m('in3', 'R-P5', L+'Intent.roc', 'one("max", 0)', 'one("max", 1)')
m('in4', 'R-TF4', L+'Intent.roc', 'warnings: entries.keep_if(|e| !known.contains(e.key))', 'warnings: entries.keep_if(|e| known.contains(e.key))')
m('in5', 'R-P5', L+'Intent.roc', 'one("max-toolchains", 0)', 'one("max-toolchains", 1)')
m('in6', 'R-LY4', L+'Intent.roc', 'read_probe(keys_of(doc, "probe"), "probe", key_line(doc, ["probe"]))', 'read_probe([], "probe", key_line(doc, ["probe"]))')
m('in7', 'R-LY4', L+'Intent.roc', 'Ok(Value.Table(t)) => read_probe(', 'Ok(Value.Table(t)) => read_probe([], "resolution.probe", 0) |> |_ignore| read_probe(')
# ResolveBase
m('rb1', 'R-LY4', L+'ResolveBase.roc', 'project: loaded.intent.resolution.probe, user: loaded.config.probe', 'project: loaded.intent.resolution.probe, user: { max: Err(Unset), timeout: Err(Unset), slots: Err(Unset), max_toolchains: Err(Unset) }')
m('rb2', 'R-LY4', L+'ResolveBase.roc', 'project: loaded.intent.resolution.probe, user: loaded.config.probe', 'project: { max: Err(Unset), timeout: Err(Unset), slots: Err(Unset), max_toolchains: Err(Unset) }, user: loaded.config.probe')
m('rb3', 'R-FL11', L+'ResolveBase.roc', 'flag_slots: request.probe.slots', 'flag_slots: request.probe.slots.map_ok(|_n| 12)')
# Units.roc
m('un1', 'R-LD2', L+'Units.roc', 'if kept.any(|k| k.hash == n.hash) kept else kept.append(n)', 'kept.append(n)', 'check l0')
m('un2', 'R-P4', L+'Units.roc', '{ hash: n.hash, nightly: facts.nightly, target: "any" })', '{ hash: n.hash, nightly: facts.nightly, target: "host" })')
m('un3', 'R-AL4', L+'Units.roc', 'f.hash == hash and f.nightly == nightly and f.target == "any"', 'f.hash == hash and f.target == "any"', 'check l0')
m('un4', 'R-PP6', L+'Units.roc', 'weight: Probe.weight(Check),', 'weight: Probe.weight(Build({ output: "" })),', 'check l0')
m('un5', 'R-LD2', L+'Units.roc', 'file: "main.roc" }),\n\t\t\tdir: Text.join(facts.pkgs, n.hash),', 'file: "main.roc" }),\n\t\t\tdir: facts.pkgs,')
m('un6', 'R-P5', L+'Units.roc', 'if left < facts.fixed {', 'if left <= facts.fixed {', 'check l0')
m('un7', 'R-P5', L+'Units.roc', 'rest = left - facts.fixed', 'rest = left', 'check l0')
m('un8', 'R-PP4', L+'Units.roc', 'left = if facts.max > facts.started facts.max - facts.started else 0', 'left = facts.max', 'check l0')
m('un9', 'R-P5', L+'Units.roc', 'if facts.wanted <= rest Ok', 'if facts.wanted < rest Ok', 'check l0')
m('un10', 'R-P4', L+'Units.roc', 'App(path) => if path.starts_with("/") e else { ..e, file: Package({ hash, path }) }', 'App(_) => e', 'check l0')
m('un11', 'R-P3', L+'Units.roc', 'Ok(fail) => return Err(fail)', 'Ok(fail) => return Err(fail)', 'check l0') if False else None
m('un12', 'R-P3', L+'Units.roc', 'Hang => say("hangs")', 'Hang => Err(NoBlame)', 'check l0')
m('un13', 'R-EP7', L+'Units.roc', 'Crash => say("crashes")', 'Crash => Err(NoBlame)', 'check l0')
m('un14', 'R-UM1', L+'Units.roc', 'm == "main.roc" or used.any(|u| u.hash == n.hash and u.path == m)', 'used.any(|u| u.hash == n.hash and u.path == m)', 'check l0')
m('un15', 'R-UM1', L+'Units.roc', 'm == "main.roc" or used.any(|u| u.hash == n.hash and u.path == m)', 'Bool.True', 'check l0')
m('un16', 'R-UM1', L+'Units.roc', 'say("no module is named")', 'Err(NoBlame)', 'check l0')
m('un17', 'R-P6', L+'Units.roc', 'f.modules.keep_if(|m| !baseline.any(|e| e.file == Package({ hash: n.hash, path: m })))', 'f.modules', 'check l0')
m('un18', 'R-UM1', L+'Units.roc', '''			Fail => if f.modules.is_empty() {''', '''			Fail => if f.modules.is_empty() and Bool.False {''', 'check l0')
m('un19', 'R-LD3', L+'Units.roc', 'if n.is_platform "the platform ${n.name} ${n.version}" else', 'if Bool.False "the platform ${n.name} ${n.version}" else', 'check l0')
m('un20', 'R-P3', L+'Units.roc', 'Fail.new(Internal, "the unit check of ${label_of(n)} on ${facts.compiler} gave no result: ${text}. Run the command again.")', 'Fail.new(Internal, "the unit check")', 'check l0')
m('un21', 'R-P3', L+'Units.roc', '[(n, text), ..] => Ok(', '[.., (n, text)] => Ok(', 'check l0')
m('un22', 'R-EC12', L+'Units.roc', 'Fail.new(Budget, "${base}. Set probe.max higher.")', 'Fail.new(NoTuple, "${base}. Set probe.max higher.")', 'check l0')
m('un23', 'R-UM1', L+'Units.roc', 'm == "main.roc" or used.any', 'm == "main.roc" or used.any') if False else None
m('un24', 'R-P6', L+'Units.roc', 'Fail => f.modules.keep_if(', 'Fail => f.modules.keep_if(') if False else None
m('un25', 'R-UM1', L+'Units.roc', 'Fail => f.modules.keep_if(|m| !baseline', 'Fail => f.modules.keep_if(|m| Bool.True or !baseline', 'check l0') if False else None
m('un26', 'R-P2', L+'Units.roc', 'Pass => Err(NoBlame)', 'Pass => say("passes")', 'check l0')
m('un27', 'R-UM1', L+'Units.roc', 'suspects = |facts| facts.nodes.keep_if(|n| !new_modules', 'suspects = |facts| facts.nodes.keep_if(|n| new_modules(n, fact_of(facts.facts, n.hash, facts.nightly), []).is_empty() or !new_modules') if False else None
# Uses.roc
m('us1', 'R-UM1', L+'Uses.roc', 'Ok(id) => Ident.of_url(id).map_ok(|i| Package(i.hash))', 'Ok(_) => Ok(App)', 'check l0')
m('us2', 'R-UM1', L+'Uses.roc', 'Ok(row) => if acc.used.contains(row) acc.used else acc.used.append(row)', 'Ok(row) => acc.used.append(row)')
m('us3', 'R-UM1', L+'Uses.roc', 'if seen.contains(t.path) or acc.next.any', 'if seen.contains("x/never") or acc.next.any')
m('us4', 'R-UM1', L+'Uses.roc', 'if path.starts_with(under) Ok({ owner: Package(hash)', 'if Bool.True Ok({ owner: Package(hash)', 'check l0') if False else None
m('us5', 'R-UM1', L+'Uses.roc', 'find_first(|e| e.from == source.owner and e.alias == alias)', 'find_first(|e| e.alias == alias)', 'check l0')
m('us6', 'R-UM1', L+'Uses.roc', 'App => facts.project_dir', 'App => facts.pkgs', 'check l0')
m('us7', 'R-UM1', L+'Uses.roc', 'if seen.contains(t.path) or acc.next.any(|n| n.path == t.path) acc else acc.append({ owner: t.owner, path: t.path })', 'if acc.next.any(|n| n.path == t.path) acc else acc.append({ owner: t.owner, path: t.path })', 'check l0') if False else None
# Ladder.roc
m('ld1', 'R-PP4', L+'Ladder.roc', '_ = Facts.save!(fx, { roots: request.roots, rows: units.facts, existing: Replace })?', '_ = {}', 'check l0 l2')
m('ld2', 'R-PP4', L+'Ladder.roc', 'rows: units.facts, existing: Replace', 'rows: units.facts, existing: Keep')
m('ld3', 'R-AL4', L+'Ladder.roc', 'if request.no_probe [] else Units.missing', 'Units.missing') if False else None
m('ld4', 'R-LF3', L+'Ladder.roc', 'wanted = if request.no_probe [] else Units.missing({ nodes, nightly: started.id, facts: state.facts })', 'wanted = Units.missing({ nodes, nightly: started.id, facts: state.facts })')
m('ld5', 'R-AL4', L+'Ladder.roc', 'wanted = if request.no_probe [] else Units.missing({ nodes, nightly: started.id, facts: state.facts })', 'wanted = if request.no_probe [] else nodes')
m('ld6', 'R-P5', L+'Ladder.roc', 'fixed: 1, wanted: wanted.len() }', 'fixed: 0, wanted: wanted.len() }')
m('ld7', 'R-P5', L+'Ladder.roc', 'if fit.cut {', 'if fit.cut and fit.run > 1000 {')
m('ld8', 'R-UM1', L+'Ladder.roc', '_ = Units.judge({ nodes, facts, nightly: started.id, compiler: started.id, baseline, used })?', '_ = Units.judge({ nodes, facts, nightly: started.id, compiler: started.id, baseline, used })')
m('ld9', 'R-P3', L+'Ladder.roc', 'Ok(fail) => return Err(fail)\n\t\tErr(None) => {}', 'Ok(_) => {}\n\t\tErr(None) => {}')
m('ld10', 'R-UM1', L+'Ladder.roc', 'used = if Units.suspects({ nodes, facts, nightly: started.id, baseline }).is_empty() [] else used_modules!', 'used = used_modules!') if False else None
m('ld11', 'R-P6', L+'Ladder.roc', 'Units.suspects({ nodes, facts, nightly: started.id, baseline }).is_empty()', 'Units.suspects({ nodes, facts, nightly: started.id, baseline: [] }).is_empty()')
m('ld12', 'R-PP4', L+'Ladder.roc', 'count = state.count + 1 + run_nodes.len()', 'count = state.count + 1')
m('ld13', 'R-PP4', L+'Ladder.roc', 'Ok({ lines: checked.lines.concat(built.lines), state: { count: count + 2, facts } })', 'Ok({ lines: checked.lines.concat(built.lines), state: { count: count + 1, facts } })')
m('ld14', 'R-PP4', L+'Ladder.roc', 'Err(None) => Ok({ lines: checked.lines, state: { count: count + 1, facts } })', 'Err(None) => Ok({ lines: checked.lines, state: { count, facts } })')
m('ld15', 'R-P5', L+'Ladder.roc', 'timeout: limit })\n\t# Slice 026b', 'timeout: 30 })\n\t# Slice 026b')
m('ld16', 'R-FL11', L+'Ladder.roc', 'pool: request.probe.slots, started, base, specs: [specs.before].concat(unit_specs)', 'pool: 12, started, base, specs: [specs.before].concat(unit_specs)')
m('ld17', 'R-LD2', L+'Ladder.roc', 'specs: [specs.before].concat(unit_specs)', 'specs: unit_specs.concat([specs.before])') if False else None
m('ld18', 'R-NS12', L+'Ladder.roc', 'Units.missing({ nodes, nightly: started.id, facts: state.facts })', 'Units.missing({ nodes, nightly: "x", facts: state.facts })')
m('ld19', 'R-EF1', L+'Ladder.roc', 'keys: Units.keys({ nodes, nightly: started.id })', 'keys: Units.keys({ nodes, nightly: "other" })')
m('ld20', 'R-P5', L+'Ladder.roc', 'spent_at(request, count)?', '_ = {}')
m('ld21', 'R-P5', L+'Ladder.roc', 'spent_at(request, count + 1)?', '_ = {}')
m('ld22', 'R-LD2', L+'Ladder.roc', 'mine = request.closures.keep_if(|c| c.file == member.file).map(|c| c.walked)', 'mine = request.closures.map(|c| c.walked)')
m('ld23', 'R-LD2', L+'Ladder.roc', 'run_nodes = wanted.sublist({ start: 0, len: fit.run })', 'run_nodes = wanted')
m('ld24', 'R-UM1', L+'Ladder.roc', 'is_app = member.kind == App\n\tvar $sources', 'is_app = member.kind != Platform\n\tvar $sources')
m('ld25', 'R-UM1', L+'Ladder.roc', 'sources = $sources.concat(read_owned!(fx, $todo))', 'sources = $sources.concat(read_owned!(fx, []))')
m('ld26', 'R-UM1', L+'Ladder.roc', '$todo = level.next', '$todo = []')
m('ld27', 'R-UM1', L+'Ladder.roc', 'Uses.edges({ rows: [], links: mine.join_map(|w| w.links) })', 'Uses.edges({ rows: [], links: [] })')
m('ld28', 'R-PP4', L+'Ladder.roc', 'facts = replaced(state.facts, units.facts)', 'facts = state.facts')
m('ld29', 'R-PP2', L+'Ladder.roc', 'if rest.len() == run_nodes.len() Ok({ first, rest }) else Err(no_answer("the probes"))', 'Ok({ first, rest })') if False else None
m('ld30', 'R-LD4', L+'Ladder.roc', 'timeout: request.probe.timeout })\n\tplan = ', 'timeout: 30 })\n\tplan = ') if False else None
m('ld31', 'R-CC9', L+'Ladder.roc', 'Launch.touch!(fx, run.roots, { id: run.started.id, now: run.now })', '{}') if False else None
m('ld32', 'R-LD1', L+'Ladder.roc', 'baseline = Ladder.baseline({ output: round.first, dir, pkgs, compiler: if other base.id else compiler, timeout: limit })?\n\tmatch units.failure', 'match units.failure') if False else None
# RealJobs.roc (L3)
m('rj1', 'R-PP6', 'cli/RealJobs.roc', 'Ok(spec) => running.fold(0, |sum, e| sum + e.weight) + slots_of(spec, pool) <= pool'.replace('Ok(spec)', 'Ok(spec)'), 'Ok(spec) => running.fold(0, |sum, e| sum + e.weight) + slots_of(spec, pool) <= pool + 1', 'check l3') if False else None
m('rj1', 'R-PP6', 'cli/RealJobs.roc', 'slots_of(spec, pool) <= pool\n', 'slots_of(spec, pool) <= pool + 1\n', 'check l3')
m('rj2', 'R-PP6', 'cli/RealJobs.roc', 'else if spec.weight > pool pool else', 'else if spec.weight > pool * 100 pool else', 'check l3')
m('rj3', 'R-PP7', 'cli/RealJobs.roc', 'running.fold(0, |sum, e| sum + e.weight) + slots_of(spec, pool) <= pool', 'running.len() + 1 + 0 * slots_of(spec, pool) <= pool', 'check l3')
m('rj5', 'R-PP6', 'cli/RealJobs.roc', 'pool = if round.pool == 0 1 else round.pool', 'pool = 12', 'check l3')
m('rj6', 'R-PP5', 'cli/RealJobs.roc', 'Ok(_) => if now >= entry.deadline {', 'Ok(_) => if now >= entry.deadline + 100000000000000 {', 'check l3')
m('rj7', 'R-PP6', 'cli/RealJobs.roc', 'weight: slots_of(spec, pool) })', 'weight: 1 })', 'check l3')
m('ld33', 'R-LD7', L+'Ladder.roc', 'var $todo = if is_app [] else Scan.roots({ kind: member.kind, file: member.file, exposed }).keep_if(|f| f != member.file).map(|path| { owner: App, path })', 'var $todo = if is_app [] else Scan.roots({ kind: member.kind, file: member.file, exposed }).keep_if(|f| f == member.file).map(|path| { owner: App, path })')
# review Q3: remove and verify run the unit probes
m('vr1', 'R-LD2', L+'VerifyFlow.roc', 'no_probe: request.probe.no_probe,\n\t\t\t\tclosures,', 'no_probe: Bool.True,\n\t\t\t\tclosures,')
m('vr2', 'R-LD2', L+'VerifyFlow.roc', 'no_probe: request.probe.no_probe,\n\t\t\t\tclosures,', 'no_probe: request.probe.no_probe,\n\t\t\t\tclosures: closures.take_first(0),')
m('vr3', 'R-UM1', L+'VerifyFlow.roc', 'text: ResolveBase.loaded_text(loaded, m.file) })', 'text: "" })')
m('vr4', 'R-AL4', L+'Ladder.roc', 'out = verify_member!(fx, request, started, $state, member)?', 'out = verify_member!(fx, request, started, { count: 0, facts: [] }, member)?')
m('vr5', 'R-PP4', L+'VerifyFlow.roc', 'probes: done.probes,', 'probes: done.probes + 1,', 'l2 l3f:verify/vf1-verify')
m('vr6', 'R-LD2', L+'Ladder.roc', 'known = Facts.load!(fx, { roots: request.roots, keys: Units.keys({ nodes, nightly: started.id }) })?\n\t\tvar $state = { count: 0, facts: known }\n\t\tvar $done = no_done\n\t\tfor member in request.members {\n\t\t\tout = verify_member!', 'known = Facts.load!(fx, { roots: request.roots, keys: Units.keys({ nodes, nightly: "other" }) })?\n\t\tvar $state = { count: 0, facts: known }\n\t\tvar $done = no_done\n\t\tfor member in request.members {\n\t\t\tout = verify_member!')
m('rm1', 'R-LD2', L+'RemoveFlow.roc', 'keep_if(|r| !facts.aliases.contains(r.alias)).map(|r| { alias: r.alias, value: r.value, is_platform: r.is_platform })', 'keep_if(|r| facts.aliases.contains(r.alias)).map(|r| { alias: r.alias, value: r.value, is_platform: r.is_platform })')
m('rm2', 'R-PP4', L+'RemoveFlow.roc', 'probes: done.probes,', 'probes: done.probes + 1,', 'l2 l3f:remove/rm1-remove-entries')
m('rm3', 'R-LD2', L+'RemoveFlow.roc', 'members: [candidate], owners, moved: [], downloads: ResolveBase.ladder_downloads(request), probe: ResolveBase.probe_settings(request, loaded), no_probe: request.probe.no_probe, closures }', 'members: [candidate], owners, moved: [], downloads: ResolveBase.ladder_downloads(request), probe: ResolveBase.probe_settings(request, loaded), no_probe: request.probe.no_probe, closures: closures.take_first(0) }')
m('rm4', 'R-LF3', L+'RemoveFlow.roc', 'no_probe: request.probe.no_probe, closures }', 'no_probe: Bool.False, closures }')
M = [x for x in M if x]

ENV = dict(os.environ)
def sh(cmd):
    p = subprocess.run(cmd, shell=True, capture_output=True, text=True, env=ENV, executable='/bin/bash')
    return p.returncode, p.stdout + p.stderr

def run(steps):
    """Returns (result, first failing line). The steps run in order; the first failure ends."""
    for st in steps.split():
        kind, _, arg = st.partition(':')
        if kind == 'l0':
            rc, log = sh('. scripts/env.sh; $ROC test tests/unit/%s.roc --no-cache' % arg)
            if rc != 0:
                bad = [l for l in log.splitlines() if 'compiler error' in l and not l.strip().startswith('0')]
                if any(('ERROR' in l or '\u2717' in l) for l in log.splitlines()) and 'failed' not in log:
                    return 'INVALID (does not compile)', st
                return 'caught', st + ' ' + next((l.strip() for l in log.splitlines() if 'failed' in l or 'FAIL' in l), '')[:90]
        elif kind == 'l2':
            rc, log = sh('. scripts/env.sh; $ROC build tests/commands/main.roc --opt=dev --output=$WORK/bin/l2 2>&1 | tail -5; test ${PIPESTATUS[0]} = 0')
            if rc != 0:
                return 'INVALID (does not compile)', 'l2 build'
            rc, log = sh('. scripts/env.sh; L2BIN=$WORK/bin/l2 tests/commands/run.sh')
            if rc != 0:
                return 'caught', 'l2 ' + next((l for l in log.splitlines() if l.startswith('FAIL')), '')
        elif kind == 'l3f':
            rc, log = sh('. scripts/env.sh; tests/run.sh %s' % arg)
            if rc != 0:
                if 'FAIL' not in log:
                    return 'INVALID (does not compile)', 'l3 build'
                return 'caught', 'l3 ' + next((l for l in log.splitlines() if l.startswith('FAIL')), '')
    return 'NOT CAUGHT', ''

def main():
    want = sys.argv[1:]
    out = []
    for x in M:
        if want and x['id'] not in want:
            continue
        path = x['file']
        text = open(path).read()
        if text.count(x['old']) != 1:
            out.append((x['id'], x['rule'], 'BAD MUTATION (%d matches)' % text.count(x['old']), ''))
            print(out[-1], flush=True)
            continue
        open(path, 'w').write(text.replace(x['old'], x['new']))
        try:
            res, why = run(x['steps'])
        finally:
            shutil.copyfile(REF + path, path)
        out.append((x['id'], x['rule'], res, why))
        print(out[-1], flush=True)
    sh('. scripts/env.sh; $ROC build tests/commands/main.roc --opt=dev --output=$WORK/bin/l2')
    with open('research/slice-031-revert/results-%s.md' % ('part' if want else 'all'), 'w') as f:
        f.write('| id | rule | result | first failing line |\n| --- | --- | --- | --- |\n')
        for r in out:
            f.write('| %s | %s | %s | %s |\n' % r)
main()
