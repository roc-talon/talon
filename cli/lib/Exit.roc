import Fail

## The exit code of a run (R-E1, R-E2).
Exit :: [].{

	## No failure and no child: 0. A child and no failure: the code of the child (R-E1).
	## Failures: the lowest code of them (R-E2). Failures of kind `Done` do not count.
	choose : { failures : List(Fail), child : Try(I32, [NoChild]) } -> I32
	choose = |run| {
		codes = run.failures.map(|f| f.kind.code()).keep_if(|c| c != 0)
		match codes.min() {
			Ok(lowest) => lowest
			Err(ListWasEmpty) => run.child ?? 0
		}
	}

	## R-HF6, R-RUN7: the code of a child: its exit code, or 128 + the signal number (slice 087).
	of_child : [Exited(I32), Signaled(I32)] -> I32
	of_child = |ended| match ended {
		Exited(code) => code
		Signaled(n) => 128 + n
	}
}
