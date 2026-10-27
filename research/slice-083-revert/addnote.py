#!/usr/bin/env python3
"""Test-agent helper of slice 083: put a note line into expect/stderr of a case, before the `platform` line that goes with the line that holds <anchor>
(the `building ...` line of the build, or any other line). Usage: addnote.py <case dir> <anchor> <note text> [--after]"""
import sys
case, anchor, note = sys.argv[1:4]
after = '--after' in sys.argv
p = case + '/expect/stderr'
lines = open(p).read().split('\n')
idx = [i for i, l in enumerate(lines) if anchor in l]
assert len(idx) == 1, (anchor, idx)
i = idx[0]
if not after and i > 0 and lines[i - 1].startswith('platform '):
    i -= 1
if after:
    i += 1
lines.insert(i, note)
open(p, 'w').write('\n'.join(lines))
