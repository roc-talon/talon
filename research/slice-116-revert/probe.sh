#!/usr/bin/env bash
# Probe: prints details of a list of bodies against the reference (after ref.sh w0 built refbuild). Usage: probe.sh '<roc expressions of Str bodies, comma separated>'
set -u
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(cd "$HERE/../.." && pwd); . "$ROOT/scripts/env.sh"
ROC=$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc
cd "$HERE/refbuild/worker/tests/unit" || exit 1
{ echo 'import lib.Hints'; echo 'ProbeTest :: [].{}'; echo 'show = |text| match Hints.parse(text.to_utf8()) {'; echo '	Ok(_) => "ok"'; echo '	Err(Bad(p)) => p.to_json()'; echo '	Err(TooLarge(p, _)) => p.to_json() }'; echo "expect { dbg show($1)"; echo 'Bool.True }'; } > ProbeTest.roc
printf '%s\n\nimport ProbeTest\n\nmain! = |_args| Ok({})\n' "$(head -1 w0.roc)" > w0-probe.roc
"$ROC" test w0-probe.roc --no-cache 2>&1 | tail -30
