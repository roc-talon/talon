// The test bundles of slice 111 (the archive read, Registry R-PU38; docs/registry/PLAN.md B.1 "Package assets"). No npm package: Node zlib has zstd from 22.15.
//   node worker/tests/tools/mk-bundle.mjs          writes the cases worker/tests/cases/archive/*/ (github/, requests.jsonl, expect/, rules, app)
//                                                   and the W0 fixture worker/tests/unit/fixtures/roc-semver-0.2.0.tar
//   node worker/tests/tools/mk-bundle.mjs check    checks blake3.mjs against the names of real bundles of the roc cache
// The files are tracked. Run the script again only when a case changes: the hashes are in the names and in the expected answers.
// A real bundle comes from the github/ file of the case (tracked), else from the roc cache (ROC_PACKAGES, default ~/.cache/roc/packages).
// run.mjs imports `generate` for a fake answer that is too large to track (`<file>.gen.json`): the bytes are made while the Worker reads.
import { zstdCompressSync, zstdDecompressSync, constants } from 'node:zlib';
import { mkdirSync, writeFileSync, readFileSync, existsSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { rocHash } from './blake3.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const casesDir = join(here, '..', 'cases', 'archive');
const unitFixtures = join(here, '..', 'unit', 'fixtures');
const rocPackages = process.env.ROC_PACKAGES ?? join(homedir(), '.cache', 'roc', 'packages');

// ---- tar (ustar, with a pax `x` record for a path that does not fit) ----
const enc = (s) => Buffer.from(s, 'utf8');
function header(name, { size = 0, type = '0', link = '', prefix = '', mode = 0o644 }) {
  const h = Buffer.alloc(512);
  const put = (off, len, v) => { const b = Buffer.isBuffer(v) ? v : enc(v); if (b.length > len) throw new Error(`tar field too long: ${v}`); b.copy(h, off); };
  put(0, 100, name);
  put(100, 8, `${mode.toString(8).padStart(7, '0')}\0`);
  put(108, 8, '0000000\0');
  put(116, 8, '0000000\0');
  put(124, 12, `${size.toString(8).padStart(11, '0')}\0`);
  put(136, 12, '00000000000\0');
  put(156, 1, type);
  put(157, 100, link);
  put(257, 6, 'ustar\0');
  put(263, 2, '00');
  put(345, 155, prefix);
  h.fill(32, 148, 156);
  let sum = 0;
  for (const b of h) sum += b;
  put(148, 8, `${sum.toString(8).padStart(6, '0')}\0 `);
  return h;
}
const padded = (b) => Buffer.concat([b, Buffer.alloc((512 - (b.length % 512)) % 512)]);
function paxRecord(key, value) {
  const body = ` ${key}=${value}\n`;
  let n = Buffer.byteLength(body) + 1;
  while (String(n).length + Buffer.byteLength(body) !== n) n = String(n).length + Buffer.byteLength(body);
  return enc(`${n}${body}`);
}
// A member: { path, data = '', type = '0', link = '' }. type: '0' file, '1' hard link, '2' symbolic link, '3' character device, '5' directory.
function member(m) {
  const data = Buffer.isBuffer(m.data) ? m.data : enc(m.data ?? '');
  const p = enc(m.path);
  const opts = { size: data.length, type: m.type ?? '0', link: m.link ?? '' };
  const out = [];
  if (p.length <= 100) {
    out.push(header(m.path, opts));
  } else {
    const cut = [...m.path].map((c, i) => (c === '/' ? i : -1)).filter((i) => i > 0 && i <= 155 && p.length - i - 1 <= 100 && p.length - i - 1 > 0);
    if (cut.length) {
      out.push(header(m.path.slice(cut[0] + 1), { ...opts, prefix: m.path.slice(0, cut[0]) }));
    } else {
      const rec = paxRecord('path', m.path);
      out.push(header('PaxHeaders/long', { size: rec.length, type: 'x' }), padded(rec), header(m.path.slice(-100).replace(/^\/+/, ''), opts));
    }
  }
  out.push(padded(data));
  return Buffer.concat(out);
}
// end: 'two' (POSIX), 'one', 'none'. pad: the total is a multiple of pad (GNU tar pads to 10240). after: bytes after it all.
export function tar(members, { end = 'two', pad = 0, after = Buffer.alloc(0) } = {}) {
  let b = Buffer.concat([...members.map(member), Buffer.alloc(end === 'two' ? 1024 : end === 'one' ? 512 : 0)]);
  if (pad > 0) b = Buffer.concat([b, Buffer.alloc((pad - (b.length % pad)) % pad)]);
  return Buffer.concat([b, after]);
}

// ---- zstd ----
export const zstd = (b, level = 19) => zstdCompressSync(b, { params: { [constants.ZSTD_c_compressionLevel]: level } });
// The window descriptor byte of a zstd frame header (RFC 8878 3.1.1.1.2): window = 2^(10+e) + 2^(10+e)/8 * m.
function windowByte(bytes) {
  for (let e = 0; e < 32; e++) for (let m = 0; m < 8; m++) if (2 ** (10 + e) * (1 + m / 8) === bytes) return (e << 3) | m;
  throw new Error(`no window descriptor for ${bytes}`);
}
// One zstd frame of raw blocks: no compression, no content size, the window of the caller. A block is at most min(window, 128 KiB).
export function zstdRaw(b, window = 131072) {
  const max = Math.min(window, 131072);
  const parts = [Buffer.from([0x28, 0xb5, 0x2f, 0xfd, 0x00, windowByte(window)])];
  let off = 0;
  do {
    const n = Math.min(max, b.length - off);
    const last = off + n >= b.length ? 1 : 0;
    const h = (n << 3) | last;
    parts.push(Buffer.from([h & 255, (h >> 8) & 255, (h >> 16) & 255]), b.subarray(off, off + n));
    off += n;
  } while (off < b.length);
  return Buffer.concat(parts);
}

// ---- fake answers that are made while the Worker reads (run.mjs: `<file>.gen.json`) ----
// {"kind":"raw-pkg","content":N}: a zstd frame of raw blocks (window 128 KiB) of the made package tar and zero bytes after it, N bytes of content in all
// (a valid bundle: with no byte count the Worker would accept it). {"kind":"zeros","bytes":N}: N zero bytes. {"kind":"raw-tar","bytes":N}: a zstd frame of raw blocks (window 128 KiB) of a tar with one member `big.bin`,
// N bytes in all (the frame bytes count). The Response has no Content-Length unless the spec names one: {"content_length": N}.
export function generate(spec) {
  const total = spec.bytes;
  let sent = 0;
  let pre = Buffer.alloc(0);
  if (spec.kind === 'raw-tar') {
    const blocks = Math.ceil(total / (131072 + 3));
    const size = total - 6 - 3 * blocks - 512; // the data of big.bin, so the frame has `total` bytes (the tar has no end blocks: the read stops first)
    pre = Buffer.from([0x28, 0xb5, 0x2f, 0xfd, 0x00, windowByte(131072)]);
    let left = 512 + size;
    let first = true;
    const hdr = header('big.bin', { size });
    return { body: new ReadableStream({ pull(c) {
      if (pre) { c.enqueue(new Uint8Array(pre)); pre = null; }
      if (left <= 0) { c.close(); return; }
      const n = Math.min(131072, left);
      left -= n;
      const blk = new Uint8Array(3 + n);
      const h = (n << 3) | (left <= 0 ? 1 : 0);
      blk[0] = h & 255; blk[1] = (h >> 8) & 255; blk[2] = (h >> 16) & 255;
      if (first) { blk.set(hdr, 3); first = false; }
      c.enqueue(blk);
    } }), headers: spec.content_length ? { 'content-length': String(spec.content_length) } : {} };
  }
  if (spec.kind === 'raw-pkg') return { body: rawPkgStream(spec.content), headers: {} };
  if (spec.kind === 'zeros') {
    return { body: new ReadableStream({ pull(c) {
      if (sent >= total) { c.close(); return; }
      const n = Math.min(1 << 20, total - sent);
      sent += n;
      c.enqueue(new Uint8Array(n));
    } }), headers: spec.content_length ? { 'content-length': String(spec.content_length) } : {} };
  }
  throw new Error(`unknown gen kind ${spec.kind}`);
}

// The raw-pkg stream (see generate) and the same bytes as one Buffer (for its hash).
function rawPkgStream(content) {
  let off = 0;
  let head = true;
  return new ReadableStream({ pull(c) {
    if (head) { c.enqueue(new Uint8Array([0x28, 0xb5, 0x2f, 0xfd, 0x00, windowByte(131072)])); head = false; }
    if (off >= content) { c.close(); return; }
    const n = Math.min(131072, content - off);
    const blk = new Uint8Array(3 + n);
    const h = (n << 3) | (off + n >= content ? 1 : 0);
    blk[0] = h & 255; blk[1] = (h >> 8) & 255; blk[2] = (h >> 16) & 255;
    if (off < pkgTar.length) blk.set(pkgTar.subarray(off, Math.min(pkgTar.length, off + n)), 3);
    off += n;
    c.enqueue(blk);
  } });
}
const rawPkgBuffer = (content) => zstdRaw(Buffer.concat([pkgTar, Buffer.alloc(content - pkgTar.length)]));

// ---- the made bundles ----
const H = { // made hashes for the header entries (base58 of 32 bytes; no bundle has them)
  plat: '3wQ1i3oJpeXzvm6Sdb7KsQRrxmGiz2Rn4WpTnZcbXtfe',
  json: '7Hc1J9u5WrD1NGTHxmFr6t3CQ4F9VXPUCyRcZ1HGnFno',
  alpha: 'C6Jtcve7FRNtkwgmuyRBJnZfJyTrfJWhDcLp6gk4w4Gz',
};
const SEMVER = 'https://github.com/Karakatiza666/roc-semver/releases/download/0.2.0/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i.tar.zst';
const CBOR = 'https://github.com/Karakatiza666/roc-cbor/releases/download/0.2.2/Cn5TmeqTbMewyChxexex2F3izTnMriXRv5ZMLVV3eUYb.tar.zst';
const pkgHeader = `## A made package of slice 111.\npackage\n\t[\n\t\tZeta,\n\t\tAlpha,\n\t]\n\t{\n\t\tsemver: "${SEMVER}",\n\t}\n`;
const appHeader = `app [main!] {\n\tpf: platform "https://github.com/t/plat/releases/download/1.2.3/${H.plat}.tar.zst",\n\tjson: "https://github.com/t/json/releases/download/v0.25.1/${H.json}.tar.zst",\n\talpha: "https://example.com/pkgs/${H.alpha}.tar.zst",\n\troc: "nightly-2026-10-31-f7bef6b",\n}\n\nmain! = |_args| Ok({})\n`;
const platHeader = `platform ""\n\trequires {\n\t\tmain! : List(Str) => Try({}, [Exit(I32)])\n\t}\n\texposes [Stdout, Arg]\n\tpackages {\n\t\tcbor: "${CBOR}",\n\t}\n\tprovides { "roc_main": main_for_host! }\n\ttargets: {\n\t\tfiles: "targets/",\n\t\texe: {\n\t\t\tx64mac: ["libhost.a", app],\n\t\t\tarm64musl: ["crt1.o", "libhost.a", app],\n\t\t},\n\t}\n`;
const mod = (name) => `${name} :: [].{\n\tx : U64\n\tx = 1\n}\n`;
const pkgMembers = [{ path: 'main.roc', data: pkgHeader }, { path: 'Zeta.roc', data: mod('Zeta') }, { path: 'Alpha.roc', data: mod('Alpha') }, { path: 'targets/x64mac/libhost.a', data: 'not a target of a package' }];
const pkgTar = tar(pkgMembers);
const pkgWire = (hash, size) => ({ hash, kind: 'package', exposed: ['Zeta', 'Alpha'], platform_hash: null, roc_pin: null, size, deps: [{ alias: 'semver', hash: 'BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i', group: 'github.com/Karakatiza666/roc-semver/releases/download/{v}/', series: '0.2', version: '0.2.0', url: SEMVER }], target_names: [] });

// A case: { name, rules, items: [{ asset (bytes) | real (hash) | raw github file, url, expect, ... }] }. Each item is one request GET /archive?url=<url>.
const gh = (repo, tag, hash) => `https://github.com/t/${repo}/releases/download/${tag}/${hash}.tar.zst`;
const problem = (status, type, detail) => ({ status, problem: detail === undefined ? { type } : { type, detail } });
const refused = (detail) => problem(422, '/errors/not-a-candidate', detail);
const ok = (json) => ({ status: 200, headers: { 'content-type': 'application/json' }, json });

function cases() {
  const out = [];
  const realSemver = 'BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i';
  const realCfw = 'f352LLRKJCZ4JJVEocp3H9e4e6Sxa6Ym5CxZ1GZCpfd';
  const cfwExposed = ['Ai', 'Analytics', 'Assets', 'Body', 'Cache', 'Cbor', 'Ctx', 'D1', 'Email', 'Env', 'Http', 'Hyperdrive', 'Id64', 'Io', 'Js', 'Kv', 'Log', 'Memo', 'Native', 'Object', 'Queue', 'R2', 'RateLimit', 'Request', 'Response', 'Rpc', 'Secret', 'SecretsStore', 'Service', 'Sql', 'Tcp', 'Time', 'Vectorize', 'Version', 'WebCrypto', 'WebSocket', 'Worker', 'Workflows'];
  out.push({
    name: 'pu38-real-bundles',
    rules: 'R-PU38 R-RE1 R-RE19 R-RE20 R-IK7 R-AP49 R-GA2',
    items: [
      // # R-PU38 row 1, R-RE1: a real roc bundle of a package (roc-semver 0.2.0, roc bundle with a 2 MiB window and Content-Length), the hash of Design 2.
      { real: realSemver, url: `https://github.com/Karakatiza666/roc-semver/releases/download/0.2.0/${realSemver}.tar.zst`, contentLength: true,
        expect: ok({ hash: realSemver, kind: 'package', exposed: ['Semver', 'VersionReq'], platform_hash: null, roc_pin: null, size: 8270, deps: [], target_names: [] }) },
      // # R-RE20, R-IK7: the real platform 0.0.2 (targets/wasm32/host.wasm), its 2 package deps, through the 302 of a GitHub release download.
      { real: realCfw, url: `https://github.com/Karakatiza666/roc-cloudflare-workers/releases/download/0.0.2/${realCfw}.tar.zst`, redirect: `https://release-assets.githubusercontent.com/t/${realCfw}.tar.zst`,
        expect: ok({ hash: realCfw, kind: 'platform', exposed: cfwExposed, platform_hash: null, roc_pin: null, size: 228076,
          deps: [{ alias: 'cbor', hash: 'Cn5TmeqTbMewyChxexex2F3izTnMriXRv5ZMLVV3eUYb', group: 'github.com/Karakatiza666/roc-cbor/releases/download/{v}/', series: '0.2', version: '0.2.2', url: CBOR },
            { alias: 'http', hash: '6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS', group: 'github.com/roc-lang/http/releases/download/{v}/', series: '2', version: '2.0.0', url: 'https://github.com/roc-lang/http/releases/download/2.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst' }],
          target_names: ['wasm32'] }) },
    ],
  });

  const appTar = tar([{ path: 'main.roc', data: appHeader }, { path: 'Helper.roc', data: mod('Helper') }]);
  const platTar = tar([
    { path: 'main.roc', data: platHeader }, { path: 'Stdout.roc', data: mod('Stdout') }, { path: 'Arg.roc', data: mod('Arg') },
    { path: 'targets/', type: '5' }, { path: 'targets/x64mac/libhost.a', data: 'a' }, { path: 'targets/arm64musl/crt1.o', data: 'b' },
    { path: 'targets/arm64musl/libhost.a', data: 'c' }, { path: 'targets/newtarget1/host.o', data: 'd' },
    { path: 'targets/macos-sysroot/usr/lib/libSystem.tbd', data: 'e' }, { path: 'targets/README.md', data: 'f' },
  ]);
  const pkgZ = zstd(pkgTar);
  const appZ = zstdRaw(appTar);
  const platZ = zstd(platTar, 3);
  out.push({
    name: 'pu38-made-kinds',
    rules: 'R-PU38 R-RE1 R-RE19 R-RE20 R-IK7 R-AP49',
    items: [
      // # R-AP49: a package: exposed in header order, a dep with group, series and version, no targets for a package (R-RE20)
      { asset: pkgZ, url: gh('pkg', '1.0.0', rocHash(pkgZ)), contentLength: true, expect: ok(pkgWire(rocHash(pkgZ), pkgZ.length)) },
      // # R-AP49, R-RE19: an app: exposed is empty, the platform hash, the roc: pin, deps sorted by alias, a dep URL with no version (group with no {v}, series and version null)
      { asset: appZ, url: gh('app', '2.0.0', rocHash(appZ)), expect: ok({ hash: rocHash(appZ), kind: 'app', exposed: [], platform_hash: H.plat, roc_pin: 'nightly-2026-10-31-f7bef6b', size: appZ.length,
        deps: [{ alias: 'alpha', hash: H.alpha, group: 'example.com/pkgs/', series: null, version: null, url: `https://example.com/pkgs/${H.alpha}.tar.zst` },
          { alias: 'json', hash: H.json, group: 'github.com/t/json/releases/download/v{v}/', series: '0.25', version: '0.25.1', url: `https://github.com/t/json/releases/download/v0.25.1/${H.json}.tar.zst` }],
        target_names: [] }) },
      // # R-RE20, R-IK7 (36 and up): a platform: the names of targets/<name>/ sorted, a new name, no name for a file in targets/ and for macos-sysroot (row 11)
      { asset: platZ, url: gh('plat', '0.3.0', rocHash(platZ)), contentLength: true, expect: ok({ hash: rocHash(platZ), kind: 'platform', exposed: ['Stdout', 'Arg'], platform_hash: null, roc_pin: null, size: platZ.length,
        deps: [{ alias: 'cbor', hash: 'Cn5TmeqTbMewyChxexex2F3izTnMriXRv5ZMLVV3eUYb', group: 'github.com/Karakatiza666/roc-cbor/releases/download/{v}/', series: '0.2', version: '0.2.2', url: CBOR }],
        target_names: ['arm64musl', 'newtarget1', 'x64mac'] }) },
    ],
  });

  // Hash cases.
  const cut = pkgZ.subarray(0, Math.floor(pkgZ.length / 2));
  const tail = tar(pkgMembers, { pad: 10240 });
  const tailZ = zstdRaw(Buffer.concat([tail, Buffer.alloc(300000)])); // the tar ends early; 300 KB of zeros after it go to the hash (R-PU38 row 4)
  const linkZ = zstd(tar([...pkgMembers, { path: 'evil', type: '2', link: '/etc/passwd' }]));
  const afterZ = zstd(tar(pkgMembers, { after: enc('x') }));
  const oneZ = zstd(tar(pkgMembers, { end: 'one' }));
  const noneZ = zstd(tar(pkgMembers, { end: 'none' }));
  const wrong = 'GddgvsGjiNXrHFW6au5i5dUDbTs8FinQdrgE2Gqmw53t';
  out.push({
    name: 'pu38-hash-and-end',
    rules: 'R-PU38 R-PU6 R-AP21',
    items: [
      // # R-PU38 row 4: the bytes are a good bundle, but the URL names another hash
      { asset: pkgZ, url: gh('pkg', '1.0.1', wrong), expect: refused(`the BLAKE3 hash of the asset is ${rocHash(pkgZ)}, not the hash ${wrong} of the URL`) },
      // # R-PU38 rows 4, 6: a cut stream under the hash of the whole bundle
      { asset: cut, url: gh('pkg', '1.0.2', rocHash(pkgZ)), expect: refused(`the BLAKE3 hash of the asset is ${rocHash(cut)}, not the hash ${rocHash(pkgZ)} of the URL`) },
      // # R-PU38 row 1: the same cut stream under its own hash: the zstd stream ends inside a frame (row 10)
      { asset: cut, url: gh('pkg', '1.0.3', rocHash(cut)), expect: refused('the asset is not a valid zstd stream: the stream ends inside a frame') },
      // # R-PU38 row 4: the tar ends early, the hash reads to the end (300 KB of zero bytes after the end blocks, raw zstd blocks)
      { asset: tailZ, url: gh('pkg', '1.0.4', rocHash(tailZ)), expect: ok(pkgWire(rocHash(tailZ), tailZ.length)) },
      // # R-PU38 row 6: one zero block and no zero block at the end are accepted
      { asset: oneZ, url: gh('pkg', '1.0.5', rocHash(oneZ)), expect: ok(pkgWire(rocHash(oneZ), oneZ.length)) },
      { asset: noneZ, url: gh('pkg', '1.0.6', rocHash(noneZ)), expect: ok(pkgWire(rocHash(noneZ), noneZ.length)) },
      // # R-PU38 row 6: data after the end is a strict error of roc-tar
      { asset: afterZ, url: gh('pkg', '1.0.7', rocHash(afterZ)), expect: refused(`tar: a byte that is not zero at offset ${tar(pkgMembers).length}, after the end of the archive`) },
      // # R-PU38 rows 4 and 6: a symbolic link under a wrong hash: the hash reads to the end, and the hash comes first (rows 8, 9)
      { asset: linkZ, url: gh('pkg', '1.0.8', wrong), expect: refused(`the BLAKE3 hash of the asset is ${rocHash(linkZ)}, not the hash ${wrong} of the URL`) },
      // # GitHub has no such asset: no archive read (502, the text is a proposal of slice 111)
      { missing: true, url: gh('pkg', '9.9.9', wrong), expect: problem(502, '/errors/upstream', 'the asset read failed with status 404') },
    ],
  });

  // Size cases (row 2). The bodies are made by run.mjs (gen.json), so 100 MB is not tracked.
  out.push({
    name: 'pu38-size',
    rules: 'R-PU38 R-AP21',
    items: [
      // # R-PU38 row 2: Content-Length over 100 MB: refused before the read (the body is never read: zeros would give another refusal)
      { gen: { kind: 'zeros', bytes: 100000001, content_length: 100000001 }, url: gh('big', '1.0.0', wrong), expect: refused('the asset has 100000001 bytes (Content-Length), more than the limit of 100000000 bytes') },
      // # R-PU38 row 2: no Content-Length (a chunked answer), and a valid bundle of 100,002,295 bytes under its own hash: the byte count stops the read (with no count it is a good package).
      // The detail has the count at the stop, which depends on the chunks, so only the type is checked.
      { gen: { kind: 'raw-pkg', content: 100000000 }, url: gh('big', '1.0.1', 'RAWPKG100M'), expect: refused() },
      // # R-PU38 row 2: Content-Length of exactly 100 MB passes the check, so the Worker reads the body (zeros, so not the hash of the URL)
      { gen: { kind: 'zeros', bytes: 100000000, content_length: 100000000 }, url: gh('big', '1.0.2', wrong), expect: refused(`the BLAKE3 hash of the asset is ${'ZEROS100M'}, not the hash ${wrong} of the URL`) },
    ],
  });

  // Window cases (row 3): the same tar in a raw frame with the window descriptor of the case.
  const w8 = zstdRaw(pkgTar, 8 * 1048576);
  const w9 = zstdRaw(pkgTar, 9 * 1048576);
  const w16 = zstdRaw(pkgTar, 16 * 1048576);
  out.push({
    name: 'pu38-window',
    rules: 'R-PU38 R-AP21',
    items: [
      // # R-PU38 row 3: a window of exactly 8 MiB is accepted
      { asset: w8, url: gh('win', '1.0.0', rocHash(w8)), expect: ok(pkgWire(rocHash(w8), w8.length)) },
      // # R-PU38 row 3: 9 MiB and 16 MiB are refused
      { asset: w9, url: gh('win', '1.0.1', rocHash(w9)), expect: refused('the zstd window of the asset is larger than 8388608 bytes') },
      { asset: w16, url: gh('win', '1.0.2', rocHash(w16)), expect: refused('the zstd window of the asset is larger than 8388608 bytes') },
    ],
  });

  // Path and header cases (rows 5 to 7), each a good hash.
  const long255 = `${'d'.repeat(154)}/${'e'.repeat(94)}/A.roc`; // 255 bytes: ustar prefix (154) and name (100)
  const long256 = `${'d'.repeat(155)}/${'e'.repeat(94)}/A.roc`; // 256 bytes: ustar prefix (155) and name (100), joined by the reader
  const variants = [
    ['dotdot', [{ path: 'src/../main.roc', data: 'x' }], 'the archive has a path that roc unbundle refuses (a .. part): src/../main.roc'],
    ['symlink', [{ path: 'evil', type: '2', link: 'main.roc' }], 'the archive has a symbolic link, not a file: evil'],
    ['hardlink', [{ path: 'hard', type: '1', link: 'main.roc' }], 'the archive has a hard link, not a file: hard'],
    ['device', [{ path: 'dev', type: '3' }], 'the archive has a member of type 3, not a file: dev'],
    ['duplicate', [{ path: 'Zeta.roc', data: 'again' }], 'the archive has the path Zeta.roc two times'],
    ['reserved', [{ path: 'src/con.roc', data: 'x' }], 'the archive has a path that roc unbundle refuses (a Windows reserved name): src/con.roc'],
    ['mainupper', [{ path: 'MAIN.ROC', data: 'x' }], 'the archive has the path MAIN.ROC two times'],
    ['path256', [{ path: long256, data: 'x' }], `tar: the path or link of the member at offset ${tar(pkgMembers, { end: 'none' }).length} has 256 bytes, more than the limit 255`],
  ];
  const items = [];
  const ok255 = zstd(tar([...pkgMembers, { path: long255, data: 'x' }]));
  // # R-PU38 rows 5, 6: a path of exactly 255 bytes is accepted (ustar prefix and name)
  items.push({ asset: ok255, url: gh('paths', '1.0.0', rocHash(ok255)), expect: ok(pkgWire(rocHash(ok255), ok255.length)) });
  let v = 1;
  for (const [, extra, detail] of variants) {
    const z = zstd(tar([...pkgMembers, ...extra]));
    // # R-PU38 rows 5, 6, 12, 17
    items.push({ asset: z, url: gh('paths', `1.0.${v++}`, rocHash(z)), expect: refused(detail) });
  }
  const noMain = zstd(tar([{ path: 'src/main.roc', data: pkgHeader }, { path: 'Zeta.roc', data: mod('Zeta') }]));
  const badHeader = zstd(tar([{ path: 'main.roc', data: 'module [x]\n\nx = 1\n' }]));
  const bigHeader = zstd(tar([{ path: 'main.roc', data: Buffer.concat([enc(pkgHeader), Buffer.alloc(1048577 - Buffer.byteLength(pkgHeader), 32)]) }]));
  const okHeader = zstd(tar([{ path: 'main.roc', data: Buffer.concat([enc(pkgHeader), Buffer.alloc(1048576 - Buffer.byteLength(pkgHeader), 32)]) }, ...pkgMembers.slice(1)]));
  // # R-PU38 row 7: main.roc only in a subdir
  items.push({ asset: noMain, url: gh('paths', '1.1.0', rocHash(noMain)), expect: refused('the archive has no main.roc at its root') });
  // # R-PU38 row 7, R-PK5: a main.roc whose header does not parse (row 16)
  items.push({ asset: badHeader, url: gh('paths', '1.1.1', rocHash(badHeader)), expect: refused('main.roc has no valid header: it starts with no app, package or platform header') });
  // # R-PU38 row 5: the header file is collected up to 1 MiB: 1048577 bytes are refused, 1048576 bytes are accepted
  items.push({ asset: bigHeader, url: gh('paths', '1.1.2', rocHash(bigHeader)), expect: refused('tar: the member at offset 0 has 1048577 bytes, more than the collect limit 1048576') });
  items.push({ asset: okHeader, url: gh('paths', '1.1.3', rocHash(okHeader)), expect: ok(pkgWire(rocHash(okHeader), okHeader.length)) });
  out.push({ name: 'pu38-paths-and-header', rules: 'R-PU38 R-PK5 R-PK8 R-AP21', items });
  return out;
}

// The hash of 100,000,000 zero bytes (the third size case), computed once.
function zerosHash() {
  return rocHash(Buffer.alloc(100000000));
}

function realBundle(dir, hash, served) {
  const inCase = served ? fileOf(dir, served) : join(dir, 'none');
  const file = existsSync(inCase) ? inCase : join(rocPackages, hash, `${hash}.tar.zst`);
  const b = readFileSync(file);
  if (rocHash(b) !== hash) throw new Error(`${file}: the BLAKE3 base58 is ${rocHash(b)}, not ${hash}`);
  return b;
}

const encodeName = (s) => s.replace(/[%?:\\*<>|"]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase().padStart(2, '0')}`);
const fileOf = (dir, url) => { const u = new URL(url); return join(dir, 'github', encodeName(u.host), ...u.pathname.split('/').filter(Boolean).map(encodeName)); };
const write = (f, data) => { mkdirSync(dirname(f), { recursive: true }); writeFileSync(f, data); };

function main() {
  let zh;
  for (const c of cases()) {
    const dir = join(casesDir, c.name);
    const keep = new Map();
    for (const it of c.items) if (it.real) keep.set(it.real, realBundle(dir, it.real, it.redirect ?? it.url));
    rmSync(dir, { recursive: true, force: true });
    const reqs = [], exps = [], log = [];
    for (const it of c.items) {
      if (it.url.includes('RAWPKG100M')) it.url = it.url.replace('RAWPKG100M', rocHash(rawPkgBuffer(it.gen.content)));
      reqs.push(JSON.stringify({ method: 'GET', path: `/archive?url=${encodeURIComponent(it.url)}` }));
      log.push(`GET ${it.url}`);
      const f = fileOf(dir, it.url);
      if (it.real) {
        const b = keep.get(it.real);
        if (it.redirect) {
          write(f, '');
          write(`${f}.meta.json`, `${JSON.stringify({ status: 302, headers: { location: it.redirect } })}\n`);
          write(fileOf(dir, it.redirect), b);
          log.push(`GET ${it.redirect}`);
        } else {
          write(f, b);
          if (it.contentLength) write(`${f}.meta.json`, `${JSON.stringify({ headers: { 'content-length': String(b.length) } })}\n`);
        }
      } else if (it.asset) {
        write(f, it.asset);
        if (it.contentLength) write(`${f}.meta.json`, `${JSON.stringify({ headers: { 'content-length': String(it.asset.length) } })}\n`);
      } else if (it.gen) {
        write(f, '');
        write(`${f}.gen.json`, `${JSON.stringify(it.gen)}\n`);
      } else if (it.missing) {
        write(f, '');
        write(`${f}.meta.json`, `${JSON.stringify({ status: 404 })}\n`);
      }
      let e = JSON.stringify(it.expect);
      if (e.includes('ZEROS100M')) { zh ??= zerosHash(); e = e.replace('ZEROS100M', zh); }
      exps.push(e);
    }
    write(join(dir, 'requests.jsonl'), `${reqs.join('\n')}\n`);
    write(join(dir, 'expect', 'responses.jsonl'), `${exps.join('\n')}\n`);
    write(join(dir, 'expect', 'github.log'), `${log.join('\n')}\n`);
    write(join(dir, 'rules'), `${c.rules}\n`);
    write(join(dir, 'app'), 'archive\n'); // run.mjs: this case runs the test app worker/archive-test.roc (archive-test.wasm)
    console.log(`wrote ${dir} (${c.items.length} requests)`);
  }
  // The W0 fixture: the tar of the real roc-semver 0.2.0 bundle (roc bundle output, 31744 bytes).
  const semver = realBundle(join(casesDir, 'pu38-real-bundles'), 'BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i', SEMVER);
  write(join(unitFixtures, 'roc-semver-0.2.0.tar'), zstdDecompressSync(semver));
  console.log(`wrote ${join(unitFixtures, 'roc-semver-0.2.0.tar')}`);
}

function check() {
  let bad = 0;
  for (const h of ['RqzsHgZKL2K1SoSAG7fCaMTyzdZmpXPYEkCjNbM4i7a', 'BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i', 'f352LLRKJCZ4JJVEocp3H9e4e6Sxa6Ym5CxZ1GZCpfd']) {
    const f = join(rocPackages, h, `${h}.tar.zst`);
    if (!existsSync(f)) { console.log(`skip ${h}: not in ${rocPackages}`); continue; }
    const got = rocHash(readFileSync(f));
    console.log(`${got === h ? 'ok' : 'BAD'} ${h}${got === h ? '' : ` got ${got}`}`);
    if (got !== h) bad++;
  }
  process.exit(bad ? 1 : 0);
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) (process.argv[2] === 'check' ? check : main)();
