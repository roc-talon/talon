import lib.Fx
import lib.JsonDoc
import lib.Net
import lib.ProbeShare
import lib.ProbeShareFlow
import lib.Roots
import L2Util

## The entry `probe-share` of the L2 test app (slice 217, R-PB6). Each line of `fx/runs` is one run of `ProbeShareFlow.send!` (the share step of the command, without the probe). The registry of the run is `http://127.0.0.1:9`
## (its routes are `fx/http/127.0.0.1%3A9/...`: the closure answer `v1/closure.POST` and the hint answer `v1/compat.POST`). The roots are the dirs of the case. The whole command is the case `ps8` (entry `commands`).
##
## `<hash> [url=<text>] [json] [env:<NAME>=<value>]...`
##
## | Word | Meaning |
## | --- | --- |
## | `url=<text>` | The `source` (the release URL of the header entry): the guard reads it. No `url=`: no source, no guard call. |
## | `json` | Also prints the `data` (`ProbeShare.data`) after the lines. |
## | `env:<NAME>=<value>` | Added to the environment of the run (one `env_all!` call at the start of each run). |
##
## It prints `== <line>`, then the lines of `ProbeShare.lines` with the label `<hash>` (and the `data` for `json`), then `exit <code>` and the failure on stderr when the send has a `stop` or fails.
L2ProbeShare :: [].{

	entry! : Fx, Str => I32
	entry! = |fx, w| {
		cache = "${w}/home/.cache/roc"
		roots = Roots.{ cache, pkgs: "${cache}/packages", build: cache, config: "${w}/home/.config/talon", data: "${w}/home/.local/share/talon" }
		for line in L2Util.file_lines!("${w}/fx/runs").keep_if(|l| !l.starts_with("#")) {
			fx.out!("== ${line}\n")
			env = fx.env_all!()
			given = L2Util.words(line)
			extra = given.keep_oks(
				|word| if word.starts_with("env:") {
					match word.drop_prefix("env:").split_first("=") {
						Ok({ before, after }) => Ok((before, after))
						Err(_) => Err(NotEnv)
					}
				} else {
					Err(NotEnv)
				},
			)
			match given {
				[hash, .. as rest] => {
					source = match rest.find_first(|word| word.starts_with("url=")) {
						Ok(word) => word.drop_prefix("url=")
						Err(_) => ""
					}
					found = ProbeShareFlow.send!(fx, { roots, net: Net.from_env(env.concat(extra)), origin: "http://127.0.0.1:9", source, hash, env: env.concat(extra), setting: "TALON_REGISTRY" })
					match found {
						Ok(done) => {
							for out_line in ProbeShare.lines({ label: hash, shared: done.shared, kept_back: done.kept_back, unsent: done.unsent }) {
								fx.out!("  ${out_line}")
							}
							if rest.contains("json") {
								fx.out!("  ${JsonDoc.render(ProbeShare.data({ shared: done.shared, kept_back: done.kept_back, unsent: done.unsent }))}\n")
							}
							match done.stop {
								Ok(fail) => L2Util.report!(fx, fail)
								Err(None) => {}
							}
						}
						Err(fail) => L2Util.report!(fx, fail)
					}
				}
				[] => fx.out!("  bad line\n")
			}
		}
		0
	}
}
