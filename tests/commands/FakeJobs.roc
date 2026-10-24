import pf.Path
import lib.Probe
import FakeBase

## The job calls of the fake `Fx` (http, spawn, probes, exec). The answers come from the files in `<w>/fx/`.
## The table of the `fx/` files and the log lines is in the doc of `FakeFx`. Each call gets the case dir `w` first.
FakeJobs :: [].{

	## The answer of the fake `http_get!` (see the table in `FakeFx.roc`). The route is `<host>/<path>[?<query>]` of the URL.
	http_get! : Str, { url : Str, headers : List((Str, Str)) } => Try({ status : U16, headers : List((Str, Str)), body : Str }, [Timeout, Failed(Str)])
	http_get! = |w, request| {
		FakeBase.log!(w, "http_get ${request.url}")
		for (name, value) in request.headers {
			FakeBase.log!(w, "  ${name}: ${value}")
		}
		rest = request.url.drop_prefix("https://").drop_prefix("http://")
		(path_part, query) = match rest.split_on("?") {
			[p] => (p, "")
			[p, .. as q] => (p, Str.join_with(q, "?"))
			[] => (rest, "")
		}
		with_query = "${w}/fx/http/${path_part}?${query}"
		plain = "${w}/fx/http/${path_part}"
		route = if !query.is_empty() and (FakeBase.exists!(with_query) or FakeBase.exists!("${with_query}.meta")) with_query else plain
		if !FakeBase.exists!(route) and !FakeBase.exists!("${route}.meta") {
			Ok({ status: 404, headers: [], body: "{\"message\":\"Not Found\"}" })
		} else {
			meta = FakeBase.lines(FakeBase.read_or_empty!("${route}.meta"))
			status = match meta.find_first(|l| l.starts_with("status ")) {
				Ok(l) => U16.from_str(l.drop_prefix("status ")) ?? 200
				Err(_) => 200
			}
			headers = meta.keep_if(|l| l.starts_with("header ")).map(
				|l| match l.drop_prefix("header ").split_on(":") {
					[name, .. as value] => (name.trim(), Str.join_with(value, ":").trim())
					[] => ("", "")
				},
			)
			fails = meta.find_first(|l| l.starts_with("error "))
			etag = headers.find_first(|(name, _)| name == "ETag")
			sent = request.headers.find_first(|(name, _)| name == "If-None-Match")
			match fails {
				Ok("error timeout") => Err(Timeout)
				Ok(l) => Err(Failed(l.drop_prefix("error failed ")))
				Err(_) => match (etag, sent) {
					(Ok((_, tag)), Ok((_, same))) if tag == same => Ok({ status: 304, headers, body: "" })
					_ => Ok({ status, headers, body: FakeBase.read_or_empty!(route) })
				}
			}
		}
	}

	## The answer of the fake `spawn_all!` (see the table in `FakeFx.roc`).
	spawn_all! : Str, { jobs : List({ argv : List(Str), cwd : Try(Str, [Inherit]) }), limit : U64 } => List({ ended : [Exited(I32), Signaled(I32), NotStarted(Str)], stdout : Str, stderr_last : Str })
	spawn_all! = |w, batch| {
		FakeBase.log!(w, "spawn_all limit=${batch.limit.to_str()}")
		rules = FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/jobs")).keep_if(|l| !l.starts_with("#")).map(|l| l.split_on("\t"))
		var $results = []
		for job in batch.jobs {
			text = Str.join_with(job.argv, " ")
			cwd = match job.cwd {
				Ok(dir) => dir
				Err(Inherit) => "${w}/project"
			}
			FakeBase.log!(
				w,
				"  job ${
					match job.cwd {
						Ok(dir) => dir
						Err(Inherit) => "-"
					}
				} ${text}",
			)
			rule = rules.find_first(
				|fields| match fields {
					[needle, ..] => text.contains(needle)
					_ => Bool.False
				},
			)
			one = match rule {
				Ok([_, code, out, err, made]) => {
					for item in made.split_on(";").keep_if(|m| m != "-" and !m.is_empty()) {
						FakeBase.create_item!(item.replace_each("{cwd}", cwd).replace_each("{w}", w).replace_each("{out}", word_after(job.argv, "--output")).replace_each("{dir}", word_after(job.argv, "-C")))
					}
					{ ended: ended_of(code), stdout: if out == "-" "" else out, stderr_last: if err == "-" "" else err }
				}
				_ => { ended: Exited(99), stdout: "", stderr_last: "fake spawn_all: no rule for: ${text}" }
			}
			$results = $results.append(one)
		}
		$results
	}

	## The answer of the fake `probes!` (see the table in `FakeFx.roc`). Slice 031: a unit probe (a `check` in a dir under `/packages/`) is answered by `fx/units` and is not counted for the rows of `fx/probes`.
	probes! : Str, { pool : U64, specs : List(Probe.Spec) } => List(Probe.Output)
	probes! = |w, round| {
		specs = round.specs
		FakeBase.log!(w, "probes ${specs.len().to_str()}${if round.pool == 12 "" else " pool=${round.pool.to_str()}"}")
		rows = FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/probes")).keep_if(|l| !l.starts_with("#")).map(|l| l.split_on("\t"))
		units = FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/units")).keep_if(|l| !l.starts_with("#")).map(|l| l.split_on("\t"))
		var $results = []
		for spec in specs {
			index = FakeBase.lines(FakeBase.read_or_empty!("${w}/out/calls.log")).keep_if(|l| l.starts_with("  probe ") and !l.contains("/packages/")).len()
			FakeBase.log!(w, "  probe ${spec.dir} ${spec.compiler} ${spec.program} ${Str.join_with(spec.args, " ")} timeout=${spec.timeout.to_str()}")
			if !spec.env.is_empty() {
				FakeBase.log!(w, "    env ${Str.join_with(spec.env.map(|(name, value)| "${name}=${value}"), " ")}")
			}
			describe_copy!(w, spec)
			text! = |name| if name == "-" "" else FakeBase.read_or_empty!("${w}/fx/${name}")
			is_unit = spec.dir.contains("/packages/") and spec.args.first() == Ok("check")
			hash = spec.dir.split_on("/").last() ?? ""
			one = if is_unit and !FakeBase.exists!(spec.dir) {
				# Slice 036b, F1: the real `Fx` starts a probe in the dir of the package. A package that is not fetched has no dir: `not started: NotFound`.
				{ ended: NotStarted("NotFound"), stdout: "", stderr: "" }
			} else if is_unit {
				match match units.find_first(|row| row.first() == Ok("${hash}:${spec.compiler}")) {
					Ok(row) => Ok(row)
					Err(_) => units.find_first(|row| row.first() == Ok(hash))
				} {
					Ok([_, code, out, err]) => { ended: probe_ended(code), stdout: text!(out), stderr: text!(err) }
					_ => default_probe(spec)
				}
			} else {
				match rows.get(index) {
					Ok([code, out, err]) => { ended: probe_ended(code), stdout: text!(out), stderr: text!(err) }
					_ => default_probe(spec)
				}
			}
			$results = $results.append(one)
		}
		run_hooks!(w, FakeBase.lines(FakeBase.read_or_empty!("${w}/out/calls.log")).keep_if(|l| l.starts_with("probes ")).len())
		$results
	}

	exec! : Str, { argv : List(Str), env : List((Str, Str)) } => Try(I32, [NotStarted(Str)])
	exec! = |w, run| {
		joined = Str.join_with(run.argv, " ")
		FakeBase.log!(w, "exec ${joined}")
		for (name, value) in run.env {
			FakeBase.log!(w, "  env ${name}=${value}")
		}
		rules = FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/exec")).keep_if(|l| !l.starts_with("#")).map(|l| l.split_on("\t"))
		match rules.find_first(|row| joined.contains(row.first() ?? "")) {
			Ok([_, code, ..]) => if code.starts_with("notstarted:") {
				Err(NotStarted(code.drop_prefix("notstarted:")))
			} else {
				Ok(I32.from_str(code) ?? 99)
			}
			_ => Ok(0)
		}
	}
}

## `probe-text`: see the table at the top.
describe_copy! : Str, Probe.Spec => {}
describe_copy! = |w, spec| {
	if FakeBase.exists!("${w}/fx/probe-text") and spec.dir.contains("/talon/tmp/") and spec.args.first() == Ok("check") {
		var $names = []
		match Path.list!(Path.utf8(spec.dir)) {
			Ok(paths) => for p in paths {
				name = match Path.filename(p) {
					Ok(f) => f.display()
					Err(_) => p.display()
				}
				$names = $names.append(
					match Path.is_dir!(p) {
						Ok(Bool.True) => "${name}/"
						_ => name
					},
				)
			}
			Err(_) => {}
		}
		names = $names.sort_with(|a, b| compare_text(a, b))
		FakeBase.log!(w, "  copy-entries ${Str.join_with(names, " ")}")
		file = spec.args.get(1) ?? ""
		all = FakeBase.read_or_empty!("${spec.dir}/${file}").split_on("\n")
		for line in header_lines(all) {
			FakeBase.log!(w, "  | ${line}")
		}
		var $rels = []
		match Path.list!(Path.utf8(spec.dir)) {
			Ok(paths) => for p in paths {
				name = match Path.filename(p) {
					Ok(f) => f.display()
					Err(_) => p.display()
				}
				match Path.is_dir!(p) {
					Ok(Bool.True) => match Path.list!(p) {
						Ok(inner) => for q in inner {
							inner_name = match Path.filename(q) {
								Ok(f) => f.display()
								Err(_) => q.display()
							}
							$rels = $rels.append("${name}/${inner_name}")
						}
						Err(_) => {}
					}
					_ => {
						$rels = $rels.append(name)
					}
				}
			}
			Err(_) => {}
		}
		for rel in $rels.keep_if(|r| r.ends_with(".roc") and r != file).sort_with(|a, b| compare_text(a, b)) {
			for line in FakeBase.read_or_empty!("${spec.dir}/${rel}").split_on("\n").keep_if(|l| l.starts_with("import \"")) {
				FakeBase.log!(w, "  ~ ${rel}: ${line}")
			}
		}
	}
}

## The lines from the first to the first one that starts with `}`, that one included.
header_lines : List(Str) -> List(Str)
header_lines = |all| match all.find_first_index(|l| l.starts_with("}")) {
	Ok(i) => all.take_first(i + 1)
	Err(_) => all
}

compare_text : Str, Str -> [Before, Same, After]
compare_text = |a, b| bytes_before(Str.to_utf8(a), Str.to_utf8(b))

bytes_before : List(U8), List(U8) -> [Before, Same, After]
bytes_before = |a, b| match (a, b) {
	([], []) => Same
	([], _) => Before
	(_, []) => After
	([x, .. as ra], [y, .. as rb]) => if x < y Before else if x > y After else bytes_before(ra, rb)
}

## `hooks`: see the table at the top. `n` is the number of `probes` calls so far.
run_hooks! : Str, U64 => {}
run_hooks! = |w, n| {
	for rule in FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/hooks")).map(|l| l.split_on("\t")) {
		match rule {
			["after-probes", count, file, from, to] => if U64.from_str(count) == Ok(n) {
				path = "${w}/${file}"
				text = FakeBase.read_or_empty!(path)
				_ = Path.write_utf8!(Path.utf8(path), text.replace_first(from.replace_each("\\n", "\n"), to.replace_each("\\n", "\n")))
				FakeBase.log!(w, "hook ${file}")
			}
			_ => {}
		}
	}
}

ended_of : Str -> [Exited(I32), Signaled(I32), NotStarted(Str)]
ended_of = |code| if code.starts_with("signal:") {
	Signaled(I32.from_str(code.drop_prefix("signal:")) ?? 9)
} else if code.starts_with("notstarted:") {
	NotStarted(code.drop_prefix("notstarted:"))
} else {
	Exited(I32.from_str(code) ?? 99)
}

probe_ended : Str -> [Exited(I32), Signaled(I32), TimedOut, NotStarted(Str)]
probe_ended = |code| if code == "timeout" {
	TimedOut
} else if code.starts_with("signal:") {
	Signaled(I32.from_str(code.drop_prefix("signal:")) ?? 9)
} else if code.starts_with("notstarted:") {
	NotStarted(code.drop_prefix("notstarted:"))
} else {
	Exited(I32.from_str(code) ?? 99)
}

default_probe : Probe.Spec -> Probe.Output
default_probe = |spec| match spec.args {
	["build", _, output] => { ended: Exited(0), stdout: "0 errors and 0 warnings found in 0ms while successfully building:\n\n    ${output.drop_prefix("--output=")}\n", stderr: "" }
	[_, file, ..] => { ended: Exited(0), stdout: "No errors found in 0ms for ${file}\n", stderr: "" }
	_ => { ended: Exited(0), stdout: "", stderr: "" }
}

## The argument after `flag` in the arguments of a job, or the empty text (slice 021: the `{out}` and `{dir}` of a rule of `jobs`).
word_after : List(Str), Str -> Str
word_after = |argv, flag| match argv.find_first_index(|word| word == flag) {
	Ok(i) => argv.get(i + 1) ?? ""
	Err(_) => ""
}
