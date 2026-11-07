// CPU time of talon-registry by Worker version, from the Workers analytics (GraphQL).
// Usage: set -a; . ./.env; set +a; node research/deploy-121/coldcpu/query.mjs [days]
const days = Number(process.argv[2] ?? 7);
const since = new Date(Date.now() - days * 864e5).toISOString();
const q = `query($a:String!,$s:Time!){viewer{accounts(filter:{accountTag:$a}){workersInvocationsAdaptive(limit:100,filter:{scriptName:"talon-registry",datetime_geq:$s},orderBy:[scriptVersion_ASC]){dimensions{scriptVersion status}sum{requests errors}quantiles{cpuTimeP25 cpuTimeP50 cpuTimeP90 cpuTimeP99 cpuTimeP999}max{cpuTime}}}}}`;
const r = await fetch('https://api.cloudflare.com/client/v4/graphql', { method: 'POST', headers: { authorization: `Bearer ${process.env.CLOUDFLARE_API_TOKEN}`, 'content-type': 'application/json' }, body: JSON.stringify({ query: q, variables: { a: process.env.CLOUDFLARE_ACCOUNT_ID, s: since } }) });
const j = await r.json();
if (j.errors) { console.error(JSON.stringify(j.errors)); process.exit(1); }
const rows = j.data.viewer.accounts[0].workersInvocationsAdaptive;
const us = (x) => (x / 1000).toFixed(1);
console.log('version   status        requests  errors  p50 ms  p90 ms  p99 ms  p99.9 ms  max ms');
for (const x of rows) console.log([x.dimensions.scriptVersion.slice(0, 8), x.dimensions.status.padEnd(12), String(x.sum.requests).padStart(8), String(x.sum.errors).padStart(6), us(x.quantiles.cpuTimeP50).padStart(6), us(x.quantiles.cpuTimeP90).padStart(6), us(x.quantiles.cpuTimeP99).padStart(6), us(x.quantiles.cpuTimeP999).padStart(8), us(x.max.cpuTime).padStart(6)].join('  '));
