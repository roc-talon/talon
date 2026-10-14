## A command program as data: each step is a command plus a continuation.
## The core builds a Program. A shell (or a test) runs it.
Program(a) := [
	Done(a),
	Read(Str, Try(Str, [NotFound]) -> Program(a)),
	Write(Str, Str, Program(a)),
	## A round of probes: results come back in the order of the list (PP3)
	Probes(List(Str), List([Pass, Fail(List(Str)), Hang]) -> Program(a)),
	Ask(Str, Bool -> Program(a)),
].{
	then : Program(a), (a -> Program(b)) -> Program(b)
	then = |prog, next|
		match prog {
			Done(v) => next(v)
			Read(path, k) => Read(path, |r| k(r).then(next))
			Write(path, text, rest) => Write(path, text, rest.then(next))
			Probes(list, k) => Probes(list, |rs| k(rs).then(next))
			Ask(q, k) => Ask(q, |yes| k(yes).then(next))
		}

	## Pure interpreter for tests: a fake file system, fake probe answers, fake prompt answers.
	## Returns the result, the final files and a log of the commands.
	run_fake : Program(a), Dict(Str, Str), (Str -> [Pass, Fail(List(Str)), Hang]), Bool -> { result : a, files : Dict(Str, Str), log : List(Str) }
	run_fake = |start, files0, probe, answer| {
		var $prog = start
		var $files = files0
		var $log = []
		while Bool.True {
			match $prog {
				Done(v) => { return { result: v, files: $files, log: $log } }
				Read(p, k) => {
					$log = $log.append("read ${p}")
					$prog = k($files.get(p).map_err(|_| NotFound))
				}
				Write(p, t, rest) => {
					$log = $log.append("write ${p}")
					$files = $files.insert(p, t)
					$prog = rest
				}
				Probes(list, k) => {
					$log = $log.append("probes ${Str.join_with(list, ",")}")
					$prog = k(list.map(probe))
				}
				Ask(q, k) => {
					$log = $log.append("ask ${q}")
					$prog = k(answer)
				}
			}
		}
		crash "unreachable"
	}
}
