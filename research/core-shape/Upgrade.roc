import Program

## A small model of `tln upgrade`: read the header, probe candidates newest first in rounds of 2,
## ask before a download, write the first candidate that passes.
Upgrade := [].{
	run : List(Str) -> Program.Program([Upgraded(Str), NoTuple, Refused])
	run = |candidates|
		Read("main.roc", |r| {
			match r {
				Err(_) => Done(NoTuple)
				Ok(header) => Ask("download 1 nightly (70 MB)?", |yes| if yes search(header, candidates) else Done(Refused))
			}
		})

	search : Str, List(Str) -> Program.Program([Upgraded(Str), NoTuple, Refused])
	search = |header, candidates|
		match candidates {
			[] => Done(NoTuple)
			_ => {
				round = candidates.take_first(2)
				Probes(round, |results| {
					passed = List.map2(round, results, |c, res| (c, res)).find_first(|(_, res)| res == Pass)
					match passed {
						Ok((c, _)) => Write("main.roc", header.replace_first("OLD", c), Done(Upgraded(c)))
						Err(_) => search(header, candidates.drop_first(2))
					}
				})
			}
		}
}

expect {
	files = Dict.from_list([("main.roc", "pf: OLD")])
	probe = |c| if c == "0.25" Pass else Fail(["Yaml.roc"])
	out = Program.run_fake(Upgrade.run(["0.27", "0.26", "0.25"]), files, probe, Bool.True)
	out.result == Upgraded("0.25")
	and out.files.get("main.roc") == Ok("pf: 0.25")
	and out.log == ["read main.roc", "ask download 1 nightly (70 MB)?", "probes 0.27,0.26", "probes 0.25", "write main.roc"]
}

expect {
	files = Dict.from_list([("main.roc", "pf: OLD")])
	out = Program.run_fake(Upgrade.run(["0.27"]), files, |_| Pass, Bool.False)
	out.result == Refused and out.files.get("main.roc") == Ok("pf: OLD")
}
