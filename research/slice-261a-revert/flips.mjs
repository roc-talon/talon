// Slice 261a: every single-bit change of RFC 8032 TEST 3 (256 key bits, 16 message bits, 512 signature bits) is rejected by node:crypto
// (OpenSSL). Any change that node accepts is checked again with the BigInt Go-rules reference ref.mjs (slow, so only for those).
import { createPublicKey, verify as nodeVerify } from "node:crypto";
const { verify: goVerify } = await import("./ref.mjs");
const h = (x) => Buffer.from(x, "hex");
const pk = h("fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025"), m = h("af82");
const s = h("6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a");
const nv = (k, msg, sig) => { try { return nodeVerify(null, msg, createPublicKey({ key: Buffer.concat([h("302a300506032b6570032100"), k]), format: "der", type: "spki" }), sig); } catch { return false; } };
const accepted = [];
for (const [name, buf] of [["key", pk], ["msg", m], ["sig", s]]) for (let i = 0; i < buf.length * 8; i++) {
  const b = Buffer.from(buf); b[i >> 3] ^= 1 << (i & 7);
  const args = name === "key" ? [b, m, s] : name === "msg" ? [pk, b, s] : [pk, m, b];
  if (nv(...args)) accepted.push([name, i, goVerify(...args)]);
}
console.log("unchanged:", nv(pk, m, s), goVerify(pk, m, s), "| flips:", 784, "| node accepts:", accepted.length, JSON.stringify(accepted));
