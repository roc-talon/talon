#!/usr/bin/env node
// Print the table of drive.mjs lines for each scenario (count, status mismatches, p50, p90, max of client_ms) and write one CSV row for each scenario.
//   node research/bench/summary.mjs <file.jsonl> [<file.jsonl> ...] [--csv <out.csv>]   (default CSV: summary.csv in the current dir)
// With several files, the lines of one scenario are added up. Add --by-colo to also print one table for each colo.
import { writeFileSync } from 'node:fs';
import { csv, readJsonl, summarize, table } from './lib.mjs';

const argv = process.argv.slice(2);
const files = [];
let csvOut = 'summary.csv', byColo = false;
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--csv') csvOut = argv[++i];
  else if (argv[i] === '--by-colo') byColo = true;
  else files.push(argv[i]);
}
if (files.length === 0) { console.error('usage: summary.mjs <file.jsonl> [...] [--csv <out.csv>] [--by-colo]'); process.exit(2); }
const lines = files.flatMap((f) => readJsonl(f));
const rows = summarize(lines);
console.log(table(rows));
writeFileSync(csvOut, csv(rows));
console.log(`\ncsv: ${csvOut} (${rows.length} rows)`);
if (byColo) {
  for (const colo of [...new Set(lines.map((l) => l.colo ?? '-'))].sort()) {
    console.log(`\ncolo ${colo}`);
    console.log(table(summarize(lines.filter((l) => (l.colo ?? '-') === colo))));
  }
}
