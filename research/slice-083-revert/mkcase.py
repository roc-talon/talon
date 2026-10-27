#!/usr/bin/env python3
"""Test-agent helper of slice 083: write the fx tables of a tool case from a short spec.
Usage: mkcase.py <case dir> <config.toml text or -> <spec.json>
spec: {"repos": {"acme/app": [[tag, published_at, hash]...]}, "src": "<src file text of every app>", "commands": [...], "builds": n}
The release lists are the GitHub answer (newest tag first)."""
import json, os, sys
case, cfg, spec = sys.argv[1], sys.argv[2], json.load(open(sys.argv[3]))
src = open(os.path.join(case, 'fx/src/platform-basic-cli.src')).read() if False else None
for repo, rels in spec['repos'].items():
    d = os.path.join(case, 'fx/http/api.github.com/repos', repo)
    os.makedirs(d, exist_ok=True)
    rows = []
    for tag, pub, h in rels:
        rows.append('{"tag_name":"%s","draft":false,"prerelease":false,"published_at":"%s","assets":[{"name":"%s.tar.zst","size":1048576,"browser_download_url":"https://github.com/%s/releases/download/%s/%s.tar.zst"}]}' % (tag, pub, h, repo, tag, h))
    open(os.path.join(d, 'releases%3Fper_page=100'), 'w').write('[\n' + ',\n'.join(rows) + '\n]\n')
jobs = ['# R-DA3 the download, R-FE2 `roc unbundle`, R-HF5 the extract, R-HF2 the chmod, R-GC10 the compat check. The first rule whose needle is in the arguments answers.']
for repo, rels in spec['repos'].items():
    for tag, pub, h in rels:
        name = '%s-%s.src' % (repo.split('/')[1], tag)
        open(os.path.join(case, 'fx/src', name), 'w').write(spec['src'])
        jobs.append('unbundle %s.tar.zst\t0\t-\t-\tdir:{cwd}/%s;copy:{cwd}/%s/main.roc={w}/fx/src/%s' % (h, h, h, name))
jobs += ['unbundle CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst\t0\t-\t-\tdir:{cwd}/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA;copy:{cwd}/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA/main.roc={w}/fx/src/platform-basic-cli.src', 'curl --fail\t0\t-\t-\tfile:{out}', 'curl', 'wget', 'tar']
open(os.path.join(case, 'fx/jobs'), 'w').write('\n'.join(jobs) + '\n')
open(os.path.join(case, 'fx/commands'), 'w').write('\n'.join(spec['commands']) + '\n')
open(os.path.join(case, 'fx/probes'), 'w').write('# One row for each build, in order (the build probes of the case).\n' + '0\t../fixtures/check/out/build-pass.stdout\t-\tfile:{out}\n' * spec['builds'])
os.makedirs(os.path.join(case, 'given/home/.config/talon'), exist_ok=True)
open(os.path.join(case, 'given/home/.config/talon/config.toml'), 'w').write(cfg.replace('\\n', '\n'))
