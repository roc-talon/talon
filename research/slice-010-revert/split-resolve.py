#!/usr/bin/env python3
"""One-off split of cli/lib/Resolve.roc (slice 010, first step).
Input: research/slice-010-revert/code-before/cli/lib/Resolve.roc (the file before the split).
Output: ResolveBase, PickFlow, InstallFlow, VerifyFlow, RemoveFlow in cli/lib/. Resolve.roc is written by hand."""
import re
ROOT = '/home/george/dev/Karakatiza666/talon'
SRC = ROOT + '/research/slice-010-revert/code-before/cli/lib/Resolve.roc'
OUT = ROOT + '/cli/lib/'
L = open(SRC).read().split('\n')
body = L[256:]
chunks = []; cur = []
for ln in body:
    if ln.strip() == '':
        if cur: chunks.append(cur); cur = []
    else:
        cur.append(ln)
if cur: chunks.append(cur)
def name_of(c):
    for ln in c:
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_!]*) :', ln)
        if m: return m.group(1)
    return None
C = {}
for c in chunks:
    n = name_of(c)
    if n: C[n] = c

def untab(a, b):
    return [l[1:] if l.startswith('\t') else l for l in L[a - 1:b]]
C['install!'] = ['## The flow of `Resolve.install!`. The steps are in the doc of `Resolve.install!`.'] + untab(102, 114)
C['remove!'] = ['## The flow of `Resolve.remove!`. The steps are in the doc of `Resolve.remove!`.'] + untab(134, 208)
C['verify!'] = ['## The flow of `Resolve.verify!`. The differences from `install!` are in the doc of `Resolve.verify!`.'] + untab(240, 248)

C['Request'] = untab(44, 63)
BASE_TYPES = 'Request Fact Loaded Settings Did Edit Pair Rename Candidates Kept Fresh Asked Row FreshRow Prepared Ran Finish Picked'.split()
BASE_FNS = 'load! settings_of check_pin snapshot_of loaded_text main_of read_releases! prepared! current_rows owner_rows set_edits moved_platform_notes'.split()
mods = {
 'ResolveBase': dict(
    types=BASE_TYPES, public=BASE_FNS,
    private='bad_snapshot no_texts no_intents empty_intent member_files no_facts is_move owner_of no_names'.split()),
 'PickFlow': dict(
    types=['PickInput'], public=['pick!'],
    private='with_close_versions asked! in_file entry_of_repo kept_of fresh_of highest_version no_names no_picks no_kept no_fresh entities_of range_of_selector live_wants! ask_rename! no_wants short_failure index! no_candidates slots_of highest_use pick_loop! platform_wants prepare! newest no_rows no_facts'.split()),
 'InstallFlow': dict(
    types='Planned Done'.split(), public=['install!'],
    private='idle frozen! resolve! no_edits no_pairs fresh_plan fresh_step name_of version_of no_ran finish! outcome_of ladder! ladder_member add_edit pairs_of write! changed_files! no_files no_edited no_names no_kept'.split()),
 'VerifyFlow': dict(types=[], public=['verify!'], private='verified! no_replace checked_members'.split()),
 'RemoveFlow': dict(
    types='RemovePlan Imported'.split(), public=['remove!'],
    private='removal_plans! member_toml shared_alias import_hits! read_sources! imports_text still_imported removal_ladder! write_removal! removed_of removed_text no_edited no_names'.split()),
}
# chunks of the helpers that sit in the module of a flow but come from the original in a different place
extra_names = {'no_names': 'no_names'}
IMPORTS = {'Add','Alias','Answer','Clock','Consent','Fail','Fetch','Frozen','Fx','Github','Guard','Ident','Index','Intent','Ladder','Item','Locked','Lookup','Mode','Net','Pick','Picker','Pin','Project','Prompt','Ranges','Ref','Release','Removal','Report','Roots','Scan','Scope','Selector','Text','Vars','Header','Semver','ResolveBase','PickFlow','InstallFlow'}
IMPORT_LINE = {'Header': 'import header.Header', 'Semver': 'import semver.Semver'}
base_public_re = re.compile(r'(?<![A-Za-z_.])(' + '|'.join(re.escape(f) for f in BASE_FNS) + r')\(')
pick_re = re.compile(r'(?<![A-Za-z_.])pick!\(')

def chunk(n, mod):
    c = list(C[n])
    return c

def rewrite(lines, mod):
    out = []
    for ln in lines:
        s = ln.replace('Resolve.Request', 'ResolveBase.Request')
        is_def = re.match(r'^[A-Za-z_][A-Za-z0-9_!]* [:=]', s) is not None
        if not is_def and not s.lstrip().startswith('#'):
            s = base_public_re.sub(lambda m: 'ResolveBase.' + m.group(1) + '(', s)
            if mod != 'PickFlow': s = pick_re.sub('PickFlow.pick!(', s)
        out.append(s)
    return out

def indent(lines):
    return ['\t' + l if l.strip() else l for l in lines]

def build(mod, spec):
    types = [C[t] for t in spec['types']]
    pub = [C[f] for f in spec['public']]
    priv = []
    for n in spec['private']:
        priv.append(C[n])
    blockparts = []
    if mod == 'ResolveBase':
        blockparts = types + pub
        top = priv
    else:
        blockparts = pub
        top = types + priv
    code = []
    for p in blockparts:
        code.append(indent(rewrite(p, mod)))
    head = ['%s :: [].{' % mod, '']
    for i, p in enumerate(code):
        head += p + ['']
    head[-1] = '}'
    text = head
    for p in top:
        text += [''] + rewrite(p, mod)
    return text

for mod, spec in mods.items():
    text = build(mod, spec)
    joined = '\n'.join(text)
    code_only = '\n'.join(l for l in text if not l.lstrip().startswith('#'))
    imps = []
    for m in sorted(IMPORTS):
        if m == mod: continue
        if re.search(r'(?<![A-Za-z_.])' + m + r'(?![A-Za-z_])', code_only):
            imps.append(IMPORT_LINE.get(m, 'import ' + m))
    # local aliases for the types of the base module
    aliases = []
    if mod != 'ResolveBase':
        for t in BASE_TYPES:
            if re.search(r'(?<![A-Za-z_.])' + t + r'(?![A-Za-z_])', code_only):
                aliases.append('%s : ResolveBase.%s' % (t, t))
        if aliases and 'import ResolveBase' not in imps: imps.append('import ResolveBase')
    imps.sort(key=lambda s: s.split()[-1])
    doc = {
      'ResolveBase': '## The types and the helpers that the flows of `Resolve` share: `Request`, the load of the files, the pin and snapshot checks, the read of the releases, the edits of a header (slice 010 split of `Resolve`).',
      'PickFlow': '## The pick of `install`, `update`, `add` and `verify`: the names, the scope, the index and `Pick.step` (steps 2 to 7 of `Resolve.install!`). Split from `Resolve` in slice 010.',
      'InstallFlow': '## The flow of `install`, `update` and `add` (`Resolve.install!`): the pick, the plan, the ladder and the write. Split from `Resolve` in slice 010.',
      'VerifyFlow': '## The flow of `verify` (`Resolve.verify!`): the part after the pick. Split from `Resolve` in slice 010.',
      'RemoveFlow': '## The flow of `remove` (`Resolve.remove!`). Split from `Resolve` in slice 010.',
    }[mod]
    out = '\n'.join(imps) + '\n\n' + '\n'.join(aliases) + ('\n\n' if aliases else '') + doc + '\n' + joined + '\n'
    open(OUT + mod + '.roc', 'w').write(out)
    print(mod, len(out.split('\n')))
