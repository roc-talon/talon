// Does the bot set find the same epoch boundaries (Resolution 4, R-EP3) as all hashes? Data: conformance/compat-sweep/
// (46 hashes x 22 nightlies, measured 2026-10-13). Run: node boundaries.mjs
// The set (R-MX11) is the newest labelled release of each series. All releases of the sample are in the 18-month window.
// A hash with no known label is not in the index, so it is not a member.
import { readFileSync } from "node:fs";

const dir = new URL("../../conformance/compat-sweep/", import.meta.url);
const tags = readFileSync(new URL("tags.txt", dir), "utf8").trim().split("\n");
const res = {};
for (const line of readFileSync(new URL("results.tsv", dir), "utf8").trim().split("\n")) {
  const [n, h, r] = line.split("\t");
  (res[h] ??= {})[n] = r;
}
const labels = Object.fromEntries(readFileSync(new URL("labels.tsv", dir), "utf8").trim().split("\n").map((l) => l.split("\t")));
const parse = (l) => { const [g, v] = l.split("@"); const [ma, mi, pa] = v.split(".").map(Number); return { g, ma, mi, pa }; };
const series = (x) => `${x.g}@${x.ma === 0 ? `0.${x.mi}` : x.ma}`;
const best = {}; // series -> { hash, version }
for (const [h, l] of Object.entries(labels)) {
  if (l === "?") continue;
  for (const one of l.split(",")) {
    const x = parse(one), s = series(x), k = x.ma * 1e8 + x.mi * 1e4 + x.pa;
    if (!best[s] || best[s].k < k || (best[s].k === k && !best[s].hashes.includes(h))) best[s] = { k: Math.max(k, best[s]?.k ?? 0), hashes: best[s]?.k === k ? [...best[s].hashes, h] : [h] };
  }
}
const members = new Set(Object.values(best).flatMap((b) => b.hashes));
// Only the newest series of each group: a smaller set, to see how far the set can shrink.
const newestOfGroup = {};
for (const [s, b] of Object.entries(best)) { const g = s.split("@")[0]; if (!newestOfGroup[g] || newestOfGroup[g].k < b.k) newestOfGroup[g] = b; }
const small = new Set(Object.values(newestOfGroup).flatMap((b) => b.hashes));

const code = (r) => r === "pass" || r === "fail";
function boundaries(set, min = 2) {
  const out = [];
  for (let i = 1; i < tags.length; i++) {
    let changed = 0;
    for (const h of set) { const a = res[h]?.[tags[i - 1]], b = res[h]?.[tags[i]]; if (code(a) && code(b) && a !== b) changed++; }
    if (changed >= min) out.push(tags[i].slice(8, 18));
  }
  return out;
}
const all = new Set(Object.keys(res));
const rows = [["all hashes", all], ["bot set (R-MX11)", members], ["newest series of each group only", small]];
const ref = boundaries(all).join(" ");
console.log("| Set | Hashes | Boundaries (date of the later nightly) | Same as all |\n| --- | --- | --- | --- |");
for (const [name, set] of rows) { const b = boundaries(set).join(" "); console.log(`| ${name} | ${set.size} | ${b} | ${b === ref ? "yes" : "no"} |`); }
// The same with a threshold of 1 changed hash, to see if a smaller set needs a lower threshold.
console.log("\n| Set | Boundaries with 1 changed hash or more | Same as all (threshold 2) |\n| --- | --- | --- |");
for (const [name, set] of rows) { const b = boundaries(set, 1).join(" "); console.log(`| ${name} | ${b} | ${b === ref ? "yes" : "no"} |`); }
// Which hashes change at each boundary of all hashes.
for (let i = 1; i < tags.length; i++) {
  const ch = [...all].filter((h) => { const a = res[h]?.[tags[i - 1]], b = res[h]?.[tags[i]]; return code(a) && code(b) && a !== b; });
  if (ch.length) console.log(`${tags[i].slice(8, 18)}: ${ch.map((h) => `${labels[h] ?? h}${members.has(h) ? "" : " (not in set)"}`).join(", ")}`);
}
