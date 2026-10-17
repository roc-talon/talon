// The id functions of Registry 5.1 (R-IK2 to R-IK5). Prototype: the Worker does the same in Roc.
import { createHash } from "node:crypto";

export const KIND = { artifact: 1, form: 2, repo: 3 };

// R-IK2: the first 8 bytes of SHA-256(kind byte || value), as a signed big-endian integer.
// Returned as decimal text: D1 takes no BigInt, and an INTEGER column stores the text as an integer (K3, K10).
export function nameId(kind, value) {
  const bytes = typeof value === "string" ? Buffer.from(value, "utf8") : Buffer.from(value);
  const d = createHash("sha256").update(Buffer.from([KIND[kind]])).update(bytes).digest();
  return d.readBigInt64BE(0).toString();
}

const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
  "November", "December"];

// R-IK4: a nightly tag in one of the two forms of CLI 6.2, R-CV1 -> days since 1970-01-01 * 2^28 + the first 28 bits of the sha.
export function nightlyId(tag) {
  const m = /^nightly-(\d{4})-(\d{2}|[A-Z][a-z]+)-(\d{2})-([0-9a-f]{7,40})$/.exec(tag);
  if (!m) return null;
  const month = /^\d/.test(m[2]) ? Number(m[2]) : MONTHS.indexOf(m[2]) + 1;
  if (month < 1 || month > 12) return null;
  const ms = Date.UTC(Number(m[1]), month - 1, Number(m[3]));
  const date = new Date(ms);
  if (date.getUTCMonth() !== month - 1 || date.getUTCDate() !== Number(m[3])) return null;
  return (ms / 86400000) * 2 ** 28 + parseInt(m[4].slice(0, 7), 16);
}

// R-IK5: the version of tln in one integer, for the key of compat_hints. -1 is "unknown" (R-CT12).
export function talonVersionId(text) {
  const m = /^(\d{1,5})\.(\d{1,5})\.(\d{1,5})$/.exec(text);
  if (!m || m.slice(1).some((p) => Number(p) > 65535)) return -1;
  return Number(m[1]) * 2 ** 32 + Number(m[2]) * 2 ** 16 + Number(m[3]);
}
