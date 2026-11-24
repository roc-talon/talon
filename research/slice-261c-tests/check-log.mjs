// Slice 261c: a sanity check of a fake log of mk-log.mjs (node:crypto): the checkpoint verifies with the TALON_LOG_KEY of fx/env, the level 0 tile hashes
// give the signed root (a tree under 256 leaves), and each entry of the bundle hashes to its place in the level 0 tile. Usage: node check-log.mjs <case> <host dir> <size>
import { createHash, createPublicKey, verify } from "node:crypto";
import { readFileSync } from "node:fs";
const [dir, host, size] = process.argv.slice(2);
const sha = (...b) => createHash("sha256").update(Buffer.concat(b.map((x) => Buffer.from(x)))).digest();
const split = (n) => { let k = 1; while (k * 2 < n) k *= 2; return k; };
const mth = (hs, a, n) => (n === 1 ? hs[a] : (() => { const k = split(n); return sha([1], mth(hs, a, k), mth(hs, a + k, n - k)); })());
const env = readFileSync(`${dir}/fx/env`, "utf8").split("\n").find((l) => l.startsWith("TALON_LOG_KEY=")).slice(14).trim();
const pub = Buffer.from(env.split("+").slice(2).join("+"), "base64").subarray(1);
const note = readFileSync(`${dir}/fx/http/${host}/log/checkpoint`, "utf8");
const [body, line] = note.split("\n\n");
const sig = Buffer.from(line.split(" ")[2], "base64").subarray(4);
const key = createPublicKey({ key: Buffer.concat([Buffer.from("302a300506032b6570032100", "hex"), pub]), format: "der", type: "spki" });
const n = Number(size);
const tile = readFileSync(`${dir}/fx/http/${host}/log/tile/0/000.p/${n}`);
const hs = []; for (let i = 0; i < n; i++) hs.push(tile.subarray(i * 32, i * 32 + 32));
const bundle = readFileSync(`${dir}/fx/http/${host}/log/tile/entries/000.p/${n}`);
let p = 0, ok = true; for (let i = 0; i < n; i++) { const len = bundle.readUInt16BE(p); const e = bundle.subarray(p + 2, p + 2 + len); p += 2 + len; ok &&= sha([0], e).equals(hs[i]); }
console.log("signature", verify(null, Buffer.from(body + "\n"), key, sig), "root", mth(hs, 0, n).toString("base64") === body.split("\n")[2], "leaves", ok && p === bundle.length);
