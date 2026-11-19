// Slice 257e: the log key tool. node:crypto only (Go is not installed here).
// Commands (repo root):
//   node research/log-key/log-key.mjs make --signer-out <file> --verifier-out <file> [--origin <origin>]
//   node research/log-key/log-key.mjs verify --verifier-file <file> --checkpoint-file <file>
//   node research/log-key/log-key.mjs self-test
// `make` writes the SECRET signer key text only to the file --signer-out (mode 600, no overwrite, no newline).
// It never prints the secret. It prints the public verifier key text.
// Key text forms (Go golang.org/x/mod/sumdb/note, C2SP signed-note):
//   signer:   PRIVATE+KEY+<origin>+<key id hex 8>+<base64(0x01 || 32-byte seed)>
//   verifier: <origin>+<key id hex 8>+<base64(0x01 || 32-byte public key)>
//   key id:   first 4 bytes of SHA-256(origin || 0x0A || 0x01 || public key)
import { createHash, createPrivateKey, createPublicKey, generateKeyPairSync, sign, verify, randomBytes } from "node:crypto";
import { closeSync, existsSync, mkdirSync, openSync, readFileSync, rmSync, statSync, writeSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const DEFAULT_ORIGIN = "registry.roc-talon.org/log";
const PKCS8_PREFIX = Buffer.from("302e020100300506032b657004220420", "hex");
const SPKI_PREFIX = Buffer.from("302a300506032b6570032100", "hex");
const sha = (...b) => createHash("sha256").update(Buffer.concat(b.map((x) => Buffer.from(x)))).digest();
const hex = (b) => Buffer.from(b).toString("hex");
const b64 = (b) => Buffer.from(b).toString("base64");

export function checkOrigin(o) {
  // tlog-cosignature: non-empty UTF-8, at most 255 bytes, no space, no control character, no "+".
  if (typeof o !== "string" || o.length === 0) throw new Error("origin is empty");
  if (Buffer.byteLength(o, "utf8") > 255) throw new Error("origin is longer than 255 bytes");
  if (/[\s+\x00-\x1f\x7f]/u.test(o)) throw new Error("origin has a space, a plus sign or a control character");
  return o;
}
export const keyId = (origin, pub) => sha(Buffer.from(origin, "utf8"), [0x0a, 0x01], pub).subarray(0, 4);
export const signerText = (origin, id, seed) => `PRIVATE+KEY+${origin}+${hex(id)}+${b64(Buffer.concat([Buffer.from([1]), seed]))}`;
export const verifierText = (origin, id, pub) => `${origin}+${hex(id)}+${b64(Buffer.concat([Buffer.from([1]), pub]))}`;
const privOfSeed = (seed) => createPrivateKey({ key: Buffer.concat([PKCS8_PREFIX, seed]), format: "der", type: "pkcs8" });
const pubOfPriv = (priv) => Buffer.from(createPublicKey(priv).export({ format: "jwk" }).x, "base64url");

// A new key: the seed comes from the OS random source (Ed25519 key generation of node:crypto).
export function makeKey(origin) {
  checkOrigin(origin);
  const { privateKey } = generateKeyPairSync("ed25519");
  const seed = Buffer.from(privateKey.export({ format: "der", type: "pkcs8" })).subarray(16);
  const pub = pubOfPriv(privateKey);
  const id = keyId(origin, pub);
  return { signer: signerText(origin, id, seed), verifier: verifierText(origin, id, pub), seed, pub, id };
}
// Split only at the first 4 "+": the key data is base64 and can hold "+".
export function parseSigner(text) {
  const p = text.split("+");
  if (p.length < 5 || p[0] !== "PRIVATE" || p[1] !== "KEY") throw new Error("not a signer key text");
  const [origin, id] = [p[2], p[3]];
  const kd = Buffer.from(p.slice(4).join("+"), "base64");
  if (!/^[0-9a-f]{8}$/.test(id) || kd.length !== 33 || kd[0] !== 1) throw new Error("bad signer key text");
  return { origin, id, seed: kd.subarray(1) };
}
export function parseVerifier(text) {
  const p = text.split("+");
  if (p.length < 3) throw new Error("not a verifier key text");
  const kd = Buffer.from(p.slice(2).join("+"), "base64");
  if (!/^[0-9a-f]{8}$/.test(p[1]) || kd.length !== 33 || kd[0] !== 1) throw new Error("bad verifier key text");
  return { origin: p[0], id: p[1], pub: kd.subarray(1) };
}
export const bodyOf = (origin, size, root) => `${origin}\n${size}\n${b64(root)}\n`;
export const noteOf = (body, origin, id, sig) => `${body}\n— ${origin} ${b64(Buffer.concat([id, sig]))}\n`;

// Check a signed checkpoint note against a verifier key text. Returns { origin, size, root } or throws.
export function verifyNote(note, verifierTxt) {
  const v = parseVerifier(verifierTxt);
  const cut = note.indexOf("\n\n");
  if (cut < 0) throw new Error("no empty line before the signature lines");
  const body = note.slice(0, cut + 1);
  const sigs = note.slice(cut + 2).split("\n").filter((l) => l.length);
  const lines = body.split("\n");
  if (lines.length !== 4 || lines[3] !== "") throw new Error("the body is not 3 lines (origin, size, root)");
  if (lines[0] !== v.origin) throw new Error(`origin ${lines[0]} is not ${v.origin}`);
  if (!/^(0|[1-9][0-9]*)$/.test(lines[1])) throw new Error("bad size");
  const root = Buffer.from(lines[2], "base64");
  if (root.length !== 32 || b64(root) !== lines[2]) throw new Error("bad root hash");
  const pubKey = createPublicKey({ key: Buffer.concat([SPKI_PREFIX, v.pub]), format: "der", type: "spki" });
  for (const l of sigs) {
    const m = /^— (\S+) (\S+)$/u.exec(l);
    if (!m || m[1] !== v.origin) continue;
    const raw = Buffer.from(m[2], "base64");
    if (raw.length !== 68 || hex(raw.subarray(0, 4)) !== v.id) continue;
    if (verify(null, Buffer.from(body, "utf8"), pubKey, raw.subarray(4))) return { origin: lines[0], size: Number(lines[1]), root: lines[2] };
  }
  throw new Error("no valid signature line for this key");
}

// Write a file: mode 600, never overwrite (flag "wx"), no newline.
export function writeNew(path, text) {
  const fd = openSync(path, "wx", 0o600);
  try { writeSync(fd, text); } finally { closeSync(fd); }
}

function flags(argv) {
  const o = {};
  for (let i = 0; i < argv.length; i += 2) {
    if (!argv[i].startsWith("--") || argv[i + 1] === undefined) throw new Error(`bad argument: ${argv[i]}`);
    o[argv[i].slice(2)] = argv[i + 1];
  }
  return o;
}

function make(f) {
  if (!f["signer-out"] || !f["verifier-out"]) throw new Error("need --signer-out <file> and --verifier-out <file>");
  const origin = f.origin ?? DEFAULT_ORIGIN;
  if (existsSync(f["signer-out"]) || existsSync(f["verifier-out"])) throw new Error("an output file exists; it is never overwritten");
  const k = makeKey(origin);
  writeNew(f["signer-out"], k.signer);
  writeNew(f["verifier-out"], k.verifier);
  console.log(`origin:   ${origin}`);
  console.log(`key id:   ${hex(k.id)}`);
  console.log(`verifier: ${k.verifier}`);
  console.log(`signer key text written to ${f["signer-out"]} (mode 600, no newline). It is not printed.`);
}

function verifyCmd(f) {
  if (!f["verifier-file"] || !f["checkpoint-file"]) throw new Error("need --verifier-file <file> and --checkpoint-file <file>");
  const r = verifyNote(readFileSync(f["checkpoint-file"], "utf8"), readFileSync(f["verifier-file"], "utf8").trim());
  console.log(`ok: ${r.origin} size ${r.size} root ${r.root}`);
}

function selfTest() {
  const HERE = dirname(fileURLToPath(import.meta.url));
  const dir = join(HERE, "..", "..", ".tmp", `log-key-selftest-${process.pid}`);
  mkdirSync(dir, { recursive: true });
  let bad = 0;
  const check = (name, ok) => { console.log(`${ok ? "ok  " : "FAIL"} ${name}`); if (!ok) bad++; };
  const throws = (fn) => { try { fn(); return false; } catch { return true; } };
  try {
    // 1. The published Go example key (golang.org/x/mod/sumdb/note, PeterNeumann), as in research/slice-257a-vectors/vectors.mjs.
    const go = {
      signer: "PRIVATE+KEY+PeterNeumann+c74f20a3+AYEKFALVFGyNhPJEMzD1QIDr+Y7hfZx09iUvxdXHKDFz",
      verifier: "PeterNeumann+c74f20a3+ARpc2QcUPDhMQegwxbzhKqiBfsVkmqq/LDE4izWy10TW",
    };
    const gs = parseSigner(go.signer);
    const gpub = pubOfPriv(privOfSeed(gs.seed));
    check("go example: key id c74f20a3", hex(keyId("PeterNeumann", gpub)) === "c74f20a3" && gs.id === "c74f20a3");
    check("go example: verifier text", verifierText("PeterNeumann", keyId("PeterNeumann", gpub), gpub) === go.verifier);
    check("go example: signer text", signerText("PeterNeumann", keyId("PeterNeumann", gpub), gs.seed) === go.signer);
    // 2. make: files, mode, no overwrite, no newline.
    const sf = join(dir, "signer.key"), vf = join(dir, "verifier.key");
    const origin = "selftest.example/log";
    const k = makeKey(origin);
    writeNew(sf, k.signer); writeNew(vf, k.verifier);
    check("signer file mode 600", (statSync(sf).mode & 0o777) === 0o600);
    check("verifier file mode 600", (statSync(vf).mode & 0o777) === 0o600);
    check("overwrite refused", throws(() => writeNew(sf, "x")) && readFileSync(sf, "utf8") === k.signer);
    check("signer file has no newline", !readFileSync(sf, "utf8").includes("\n"));
    check("default origin is registry.roc-talon.org/log", DEFAULT_ORIGIN === "registry.roc-talon.org/log" && makeKey(DEFAULT_ORIGIN).signer.startsWith("PRIVATE+KEY+registry.roc-talon.org/log+"));
    check("bad origins refused", ["", "a b", "a+b", "a\nb", "x".repeat(256)].every((o) => throws(() => makeKey(o))));
    // 3. The key id and the keys agree with each other.
    const ps = parseSigner(readFileSync(sf, "utf8"));
    const pv = parseVerifier(readFileSync(vf, "utf8"));
    check("signer and verifier have one origin and key id", ps.origin === pv.origin && ps.id === pv.id && ps.id === hex(keyId(origin, pv.pub)));
    check("seed gives the public key of the verifier", pubOfPriv(privOfSeed(ps.seed)).equals(pv.pub));
    // 4. Round trip: sign a checkpoint with node:crypto, verify with the verifier text.
    const root = randomBytes(32);
    const body = bodyOf(origin, 4242, root);
    const note = noteOf(body, origin, Buffer.from(ps.id, "hex"), sign(null, Buffer.from(body), privOfSeed(ps.seed)));
    const r = verifyNote(note, readFileSync(vf, "utf8"));
    check("round trip: signed checkpoint verifies", r.size === 4242 && r.root === b64(root));
    check("tampered size fails", throws(() => verifyNote(note.replace("\n4242\n", "\n4243\n"), k.verifier)));
    const other = makeKey(origin);
    check("another key fails", throws(() => verifyNote(note, other.verifier)));
    check("another origin fails", throws(() => verifyNote(note, verifierText("other/log", keyId("other/log", pv.pub), pv.pub))));
    // 5. The CLI path: make writes no secret to stdout.
    const out = join(dir, "cli");
    mkdirSync(out);
    const me = fileURLToPath(import.meta.url);
    const run = (args) => spawnSync(process.execPath, [me, ...args], { encoding: "utf8" });
    const m1 = run(["make", "--signer-out", join(out, "s"), "--verifier-out", join(out, "v"), "--origin", "bench.example/log"]);
    const secret = readFileSync(join(out, "s"), "utf8");
    check("cli make: exit 0, the secret is not in stdout or stderr", m1.status === 0 && !(m1.stdout + m1.stderr).includes(secret.split("+").slice(4).join("+")));
    check("cli make: the verifier is printed", m1.stdout.includes(readFileSync(join(out, "v"), "utf8")));
    const m2 = run(["make", "--signer-out", join(out, "s"), "--verifier-out", join(out, "v2")]);
    check("cli make: second run refuses to overwrite", m2.status !== 0 && !existsSync(join(out, "v2")));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
  check("throwaway files deleted", !existsSync(dir));
  console.log(bad === 0 ? "self-test: PASS" : `self-test: FAIL (${bad})`);
  process.exit(bad === 0 ? 0 : 1);
}
import { spawnSync } from "node:child_process";

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try {
    const [cmd, ...rest] = process.argv.slice(2);
    if (cmd === "make") make(flags(rest));
    else if (cmd === "verify") verifyCmd(flags(rest));
    else if (cmd === "self-test") selfTest();
    else throw new Error("commands: make, verify, self-test (see README.md)");
  } catch (e) {
    console.error(`error: ${e.message}`);
    process.exit(2);
  }
}
