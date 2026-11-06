// The case archive/pu38-zero-run (slice 123, Registry R-PU38 rows 3, 5, 10; docs/slices/123-platform-003.md part 123c).
//   node worker/tests/tools/mk-zero-run.mjs        writes worker/tests/cases/archive/pu38-zero-run/ only (the other cases of mk-bundle.mjs stay as they are)
// A zstd frame with a long run of zero bytes has a high ratio: 32 MiB of zeros are about 1 KB packed. Platform 0.0.2 `ZstdStream.push!` stops one push at 16 MiB of output
// (`OutputLimit`, 422 "a block gives too many bytes"). Platform 0.0.3 `ZstdStream.feed!` gives the output in parts, so these assets are good candidates (200).
//   1. a package with a member `data/zeros.bin` of 32 MiB of zeros (inside the 256 MiB limit of row 5)
//   2. a package, then 32 MiB of zeros after the end blocks of the tar (row 4/6: zero bytes after the end are accepted)
import { mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { zstdCompressSync, constants } from 'node:zlib';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tar } from './mk-bundle.mjs';
import { rocHash } from './blake3.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const dir = join(here, '..', 'cases', 'archive', 'pu38-zero-run');
const window = join(here, '..', 'cases', 'archive', 'pu38-window');
const SEMVER = 'https://github.com/Karakatiza666/roc-semver/releases/download/0.2.0/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i.tar.zst';
const enc = (s) => Buffer.from(s, 'utf8');
const pkgHeader = `## A made package of slice 111.\npackage\n\t[\n\t\tZeta,\n\t\tAlpha,\n\t]\n\t{\n\t\tsemver: "${SEMVER}",\n\t}\n`;
const mod = (name) => `${name} :: [].{\n\tx : U64\n\tx = 1\n}\n`;
const members = [{ path: 'main.roc', data: pkgHeader }, { path: 'Zeta.roc', data: mod('Zeta') }, { path: 'Alpha.roc', data: mod('Alpha') }, { path: 'targets/x64mac/libhost.a', data: 'not a target of a package' }];
// A window of 1 MiB (windowLog 20), so the frame is inside the 8 MiB limit of row 3.
const z = (b) => zstdCompressSync(b, { params: { [constants.ZSTD_c_compressionLevel]: 3, [constants.ZSTD_c_windowLog]: 20 } });
const MiB32 = 32 * 1048576;

const inMember = z(tar([...members, { path: 'data/zeros.bin', data: Buffer.alloc(MiB32) }]));
const afterEnd = z(tar(members, { after: Buffer.alloc(MiB32) }));
const items = [['1.0.0', inMember], ['1.0.1', afterEnd]];

// The good answer: the line of pu38-window request 1 with the hash and the size of this asset.
const wire = JSON.parse(readFileSync(join(window, 'expect', 'responses.jsonl'), 'utf8').split('\n')[0]);
rmSync(dir, { recursive: true, force: true });
const reqs = [], exps = [], log = [];
for (const [tag, asset] of items) {
  const hash = rocHash(asset);
  const url = `https://github.com/t/zero/releases/download/${tag}/${hash}.tar.zst`;
  const f = join(dir, 'github', 'github.com', 't', 'zero', 'releases', 'download', tag, `${hash}.tar.zst`);
  mkdirSync(dirname(f), { recursive: true });
  writeFileSync(f, asset);
  reqs.push(JSON.stringify({ method: 'GET', path: `/archive?url=${encodeURIComponent(url)}` }));
  log.push(`GET ${url}`);
  exps.push(JSON.stringify({ ...wire, json: { ...wire.json, hash, size: asset.length } }));
  console.log(`${tag}: ${asset.length} bytes packed, hash ${hash}`);
}
mkdirSync(join(dir, 'expect'), { recursive: true });
writeFileSync(join(dir, 'requests.jsonl'), `${reqs.join('\n')}\n`);
writeFileSync(join(dir, 'expect', 'responses.jsonl'), `${exps.join('\n')}\n`);
writeFileSync(join(dir, 'expect', 'github.log'), `${log.join('\n')}\n`);
writeFileSync(join(dir, 'rules'), 'R-PU38 R-PU6 R-AP21\n');
writeFileSync(join(dir, 'app'), 'archive\n');
