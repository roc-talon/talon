// Slice 261: the public vector of the live log for the Talon-side tests (261b TlogTest). node:crypto only.
// checkpoint-386.txt is the answer of GET https://registry.roc-talon.org/log/checkpoint on 2026-11-23 (201 bytes).
// The key is the PUBLIC verifier key in secrets/log-key-verifier (the built-in key of tln, Design Q636 (15)). The signer key is never read.
// Usage (repo root): node research/slice-261-vectors/live.mjs   prints the note text, the public key and the signature in hex.
import { createPublicKey, verify } from "node:crypto";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..", "..");
const verifier = readFileSync(join(ROOT, "secrets", "log-key-verifier"), "utf8").trim();
const parts = verifier.split("+");
const [name, id, data] = [parts[0], parts[1], parts.slice(2).join("+")];
const key = Buffer.from(data, "base64");
if (key.length !== 33 || key[0] !== 1) throw new Error("not an Ed25519 verifier key");
const cp = readFileSync(join(HERE, "checkpoint-386.txt"), "utf8");
const [body, line] = cp.split("\n\n");
const note = body + "\n";
const m = line.match(/^— (\S+) (\S+)\n$/);
if (!m || m[1] !== name) throw new Error("no signature line of the key");
const sig = Buffer.from(m[2], "base64");
if (sig.subarray(0, 4).toString("hex") !== id) throw new Error("key id differs");
const pub = createPublicKey({ key: Buffer.concat([Buffer.from("302a300506032b6570032100", "hex"), key.subarray(1)]), format: "der", type: "spki" });
if (!verify(null, Buffer.from(note), pub, sig.subarray(4))) throw new Error("signature does not verify");
console.log(JSON.stringify({ verifier, note, public_key: key.subarray(1).toString("hex"), signature: sig.subarray(4).toString("hex") }, null, 1));
