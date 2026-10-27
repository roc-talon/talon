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
}
