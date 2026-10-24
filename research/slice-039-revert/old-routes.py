# Slice 039 (TW21): a bare `tln upgrade` now reads the list of compilers (R-UP6). The old L2 cases get one list route:
# H (the compiler of the headers, the roc on PATH) is the only release, so N is H and nothing is downloaded or moved.
# Run: python3 -I research/slice-039-revert/old-routes.py, then UPDATE=1 tests/commands/run.sh upgrade/ug, then read git diff.
import os, json, hashlib
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
H = 'nightly-2026-10-14-38a3029'
sha = 'b5d54c39e66671c9731b9f471e585d8262cd4f54963f0c93082d8dcf334d4c78'
name = 'roc_nightly-linux_x86_64-%s.tar.gz' % H[len('nightly-'):]
item = {'tag_name': H, 'draft': False, 'prerelease': False, 'published_at': '2026-10-10T15:00:00Z',
        'assets': [{'name': name, 'size': 74000000, 'digest': 'sha256:' + sha,
                    'browser_download_url': 'https://github.com/roc-lang/nightlies/releases/download/%s/%s' % (H, name)}]}
for case in ['ug1-flow', 'ug2-lag']:
    d = os.path.join(root, 'tests/commands/cases/upgrade', case, 'fx/http/api.github.com/repos/roc-lang/nightlies')
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, 'releases?per_page=100'), 'w').write('[\n' + json.dumps(item, separators=(',', ':')) + '\n]\n')
