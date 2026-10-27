import pf.Path
import lib.Fail
import lib.Fx

## Helpers that the entries of the L2 test app share (slice 066, split from `main.roc`): the words of a line, the lines of a file in the case dir, and the report of a failure.
L2Util :: [].{

	words : Str -> List(Str)
	words = |text| text.split_on(" ").keep_if(|w| !w.is_empty())

	file_lines! : Str => List(Str)
	file_lines! = |path| match Path.read_utf8!(Path.utf8(path)) {
		Ok(text) => text.split_on("\n").keep_if(|l| !l.trim().is_empty())
		Err(_) => []
	}

	report! : Fx, Fail => {}
	report! = |fx, fail| {
		fx.out!("exit ${fail.kind.code().to_str()}\n")
		fx.err!("${fail.line()}\n")
	}
}
