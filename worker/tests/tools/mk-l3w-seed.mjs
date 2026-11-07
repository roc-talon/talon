// The seed.sql of an l3w case (slice 224): the D1 rows of indexed GitHub package releases, with the ids of the design computed here (no Roc code),
// as in mk-ingest.mjs: name_id (R-IK2), the version column (R-IK5). The rows are the ones that an ingest writes (the W2 case reads/ap1-body-etag-cache has the same form).
//   node worker/tests/tools/mk-l3w-seed.mjs <spec.json> > <case>/worker/seed.sql
// spec.json: { "now": "<RFC 3339>", "releases": [ { "owner", "repo", "tag", "version": "X.Y.Z", "hash": "<base58>", "published_at": "<RFC 3339>",
//   "kind": 1 (0 app, 1 package, 2 platform; default 1), "exposes": ["Mod"] (default []), "size": n (default 1000), "roc_version": null,
//   "repository_id": n, "owner_id": n } ] }
// The group form is `github.com/<owner>/<repo>/releases/download/{v}/` when the tag is the version, `.../v{v}/` when the tag is `v` and the version.
// Each release has the provenance `ingest` (via 3). The repository is active (state 0), checked at `now` (not stale, R-AP29).
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';

const B58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
function b58decode(s) {
  let n = 0n;
  for (const ch of s) { const i = B58.indexOf(ch); if (i < 0) throw new Error(`not base58: ${s}`); n = n * 58n + BigInt(i); }
  const out = [];
  while (n > 0n) { out.unshift(Number(n & 0xffn)); n >>= 8n; }
  for (const ch of s) { if (ch !== '1') break; out.unshift(0); }
  return Buffer.from(out);
}
// R-IK2: the first 8 bytes of SHA-256(kind byte, bytes), big-endian, signed.
const nameId = (kind, bytes) => createHash('sha256').update(Buffer.concat([Buffer.from([kind]), Buffer.from(bytes)])).digest().readBigInt64BE(0).toString();
const hashId = (h) => nameId(1, b58decode(h));
const textId = (kind, t) => nameId(kind, Buffer.from(t, 'utf8'));
// R-IK5: the key of an exact X.Y.Z (pre-release code 0xFFFF), XOR 2^63, as a signed integer.
const versionCol = (v) => {
  const [a, b, c] = v.split('.').map(BigInt);
  return BigInt.asIntN(64, ((a << 48n) | (b << 32n) | (c << 16n) | 0xffffn) ^ (1n << 63n)).toString();
};
const q = (s) => (s === null || s === undefined ? 'NULL' : `'${String(s).replace(/'/g, "''")}'`);

const spec = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const now = Date.parse(spec.now);
const out = [`-- Made by worker/tests/tools/mk-l3w-seed.mjs (slice 224). Do not edit by hand: change the spec and make it again.`];
const names = new Map();
const repos = new Map();
spec.releases.forEach((r, i) => {
  const idx = i + 1;
  const form = r.tag === r.version ? `github.com/${r.owner}/${r.repo}/releases/download/{v}/` : r.tag === `v${r.version}` ? `github.com/${r.owner}/${r.repo}/releases/download/v{v}/` : null;
  if (!form) throw new Error(`the tag ${r.tag} is not ${r.version} or v${r.version}`);
  const full = `${r.owner}/${r.repo}`.toLowerCase();
  const art = hashId(r.hash), formId = textId(2, form), repoId = textId(3, full);
  names.set(art, `(${art}, 1, X'${b58decode(r.hash).toString('hex')}')`);
  names.set(formId, `(${formId}, 2, ${q(form)})`);
  names.set(repoId, `(${repoId}, 3, ${q(full)})`);
  repos.set(repoId, r);
  const url = `https://github.com/${r.owner}/${r.repo}/releases/download/${r.tag}/${r.hash}.tar.zst`;
  out.push(`INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (${art}, ${r.kind ?? 1}, ${q(JSON.stringify(r.exposes ?? []))}, NULL, NULL, ${r.size ?? 1000});`);
  out.push(`INSERT INTO log (idx, grp, version, hash, time) VALUES (${idx}, ${q(form)}, ${q(r.version)}, ${q(r.hash)}, ${now});`);
  out.push(`INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (${idx}, ${formId}, ${versionCol(r.version)}, '', ${art}, ${repoId}, ${q(url)}, ${q(r.tag)}, ${q(r.roc_version ?? null)}, ${Date.parse(r.published_at)}, 0, NULL, NULL);`);
  out.push(`INSERT INTO provenance (release, via, claims, time) VALUES (${idx}, 3, NULL, ${now});`);
});
for (const [id, r] of repos) {
  out.push(`INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (${id}, ${r.repository_id}, ${r.owner_id}, 0, NULL, ${now}, ${now});`);
  out.push(`INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (${id}, NULL, ${now}, ${now + 3600000}, 0, 0);`);
}
out.splice(1, 0, `INSERT INTO names (id, kind, value) VALUES\n  ${[...names.values()].join(',\n  ')};`);
process.stdout.write(`${out.join('\n')}\n`);
