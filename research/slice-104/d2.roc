app [main!] { records: "../../packages/records/main.roc" }

import records.Artifact

main! = |_args| Ok({})

# D2 probe: a dep without `version` is BadJson, and the dep text ends with "version":null}.
expect {
	row = { hash: "H1", kind: Package, size: 1, exposed: [], platform_hash: Err(None), roc_pin: Err(None), deps: [{ alias: "a", hash: "H", group: "g", series: Err(None), version: Err(None), url: "u" }], target_names: [] }
	text = Artifact.encode(row)
	bad = match Artifact.decode(text.replace_first(",\"version\":null", "")) {
		Err(BadJson(_)) => Bool.True
		_ => Bool.False
	}
	text.contains("\"version\":null}") and bad
}
