app [main!] { records: "../../../packages/records/main.roc", pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.26.0/GddgvsGjiNXrHFW6au5i5dUDbTs8FinQdrgE2Gqmw53t.tar.zst" }
import pf.Stdout
import records.Release
import records.Artifact
main! = |_args| {
	r : Release.Row
	r = { log_index: 2, hash: "H", group: "g/{v}/", series: "4", version: "4.2.0", url: "https://x", tag: Ok("v4.2.0"), roc_version: Err(None), repo: Ok("a/b"), published_at: 1000, yanked: Bool.False, yank_reason: Err(None), withdrawn: Err(None) }
	Stdout.line!(Release.encode(r))?
	a : Artifact.Row
	a = { hash: "H", kind: Platform, exposed: ["A"], platform_hash: Err(None), roc_pin: Err(None), size: 5, deps: [{ alias: "z", hash: "D", group: "g", series: Ok("1"), version: Ok("1.0.0"), url: "u" }], target_names: ["x"] }
	Stdout.line!(Artifact.encode(a))?
	Ok({})
}
