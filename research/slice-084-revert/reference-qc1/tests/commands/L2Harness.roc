import lib.Fx

## The entry `harness` of the L2 test app (slice 066, split from `main.roc`). The table in `main.roc` says what it does.
L2Harness :: [].{

	entry! : Fx => I32
	entry! = |fx| {
		cwd = fx.cwd!()
		tty = fx.tty!()
		fx.out!("env variables: ${fx.env_all!().len().to_str()}\n")
		fx.out!("tty: stdin=${Str.inspect(tty.stdin)} stderr=${Str.inspect(tty.stderr)}\n")
		fx.out!("clock: ${fx.clock!().to_str()}\n")
		fx.out!("args: ${Str.inspect(fx.args!())}\n")
		for result in fx.read_files!(["${cwd}/in.txt", "${cwd}/missing.txt"]) {
			fx.out!("read: ${Str.inspect(result)}\n")
		}
		match fx.write_atomic!([{ path: "${cwd}/out.txt", content: "written" }]) {
			Ok(_) => fx.out!("write: ok\n")
			Err(_) => fx.out!("write: failed\n")
		}
		fx.err!("stderr line\n")
		listed = fx.list_dirs!([cwd, "${cwd}/missing"]).map(|r| r.map_ok(|entries| entries.map(|e| "${e.name} ${Str.inspect(e.is_dir)}").sort_by(|n| n.count_utf8_bytes())))
		fx.out!("list_dirs: ${Str.inspect(listed)}\n")
		fx.out!("canonical: ${Str.inspect(fx.canonical!(["${cwd}/in.txt", "${cwd}/missing.txt"]))}\n")
		fx.out!("delete: ${Str.inspect(fx.delete!(["${cwd}/gone.txt", "${cwd}/missing.txt"]))}\n")
		match fx.lock!("${cwd}/item", NoWait) {
			Held(lock) => {
				fx.out!("lock: held\n")
				# R-CC3 point 5: this ask is under a lock. The fake logs a VIOLATION line before it.
				_ = fx.ask!("Under lock? ")
				fx.unlock!(lock)
			}
			Busy => fx.out!("lock: busy\n")
		}
		match fx.lock!("${cwd}/other", Wait) {
			Held(lock) => fx.unlock!(lock)
			Busy => fx.out!("lock: busy\n")
		}
		match fx.ask!("Name? ") {
			Ok(reply) => fx.out!("ask: ${reply}\n")
			Err(EndOfInput) => fx.out!("ask: end of input\n")
		}
		# Slice 003
		fx.out!("http_get: ${Str.inspect(fx.http_get!({ url: "https://api.example.com/x?page=2", headers: [("A", "1")] }))}\n")
		fx.out!("programs: ${Str.inspect(fx.programs!(["curl", "wget"]))}\n")
		fx.out!("spawn_all: ${Str.inspect(fx.spawn_all!({ jobs: [{ argv: ["tool", "a"], cwd: Err(Inherit) }, { argv: ["other"], cwd: Ok(cwd) }], limit: 8 }))}\n")
		fx.out!("rename: ${Str.inspect(fx.rename!({ from: "${cwd}/in.txt", to: "${cwd}/renamed.txt" }))}\n")
		fx.out!("rename refused: ${Str.inspect(fx.rename!({ from: "${cwd}/renamed.txt", to: "${cwd}/refused" }))}\n")
		fx.out!("make_dirs: ${Str.inspect(fx.make_dirs!(["${cwd}/new/deep"]))}\n")
		fx.out!("random: ${fx.random!().to_str()}\n")
		3
	}
}
