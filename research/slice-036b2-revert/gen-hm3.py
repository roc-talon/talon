# Slice 036b2: make the L2 case moves/hm3-budget (probe.max for the second search of a held move). Run: python3 -I research/slice-036b2-revert/gen-hm3.py
# The case is run 1 of moves/hm1-noninteractive with `probe.max = 2` in the root talon.toml.
import os, shutil
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
cases = os.path.join(root, 'tests/commands/cases/moves')
src, dst = os.path.join(cases, 'hm1-noninteractive'), os.path.join(cases, 'hm3-budget')
shutil.rmtree(dst, ignore_errors=True)
os.makedirs(dst)
for d in ('fx', 'given'):
    shutil.copytree(os.path.join(src, d), os.path.join(dst, d), symlinks=True)
shutil.copy(os.path.join(src, 'entry'), dst + '/entry')
open(dst + '/fx/commands', 'w').write('add acme/json@2.2.0 --file ws/apps/b/main.roc\n')
toml = dst + '/given/project/ws/talon.toml'
open(toml, 'a').write('\n[resolution]\nprobe = { max = 2 }\n')
shutil.copy(os.path.join(root, 'research/slice-036b2-revert/hm3-rules.txt'), dst + '/rules')
