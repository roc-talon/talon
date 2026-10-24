import Db
import JsonDoc
import Probe
import ProbeRange
import Units

## The words and the JSON parts that `ProbeCmd.text` and `ProbeCmd.data` share (slice 037, TW24: the texts are a proposal). Pure. Split from `ProbeCmd` (module size).
ProbeShow :: [].{

	## `<name> <version>`, `the platform <name> <version>`, and the hash for a bundle file (it has no version).
	label_of : Units.Node -> Str
	label_of = |node| if node.version.is_empty() {
		node.name
	} else if node.is_platform {
		"the platform ${node.name} ${node.version}"
	} else {
		"${node.name} ${node.version}"
	}

	plural : U64, Str -> Str
	plural = |n, word| if n == 1 "1 ${word}" else "${n.to_str()} ${word}s"

	real_word : ProbeRange.End -> Str
	real_word = |end| if end.real "real" else "unknown"

	place_text : Probe.File -> Str
	place_text = |file| match file {
		App(path) => path
		Package({ hash, path }) => "package ${hash} ${path}"
		NoFile => "no file"
	}

	## The end of a probe for the text: the word, and for a fail the count and a line for each error.
	end_text : { class : Probe.Class, errors : List(Probe.Err) } -> Str
	end_text = |done| match done.class {
		Pass => "passed\n"
		Hang => "hang\n"
		Crash(text) => "crash (${text})\n"
		NoFact(text) => "no result (${text})\n"
		Fail(n) => "failed, ${plural(n, "error")}\n${Str.join_with(done.errors.map(|e| "  ${place_text(e.file)}: ${e.title}\n"), "")}"
	}

	outcome_of : { class : Probe.Class, errors : List(Probe.Err) } -> Str
	outcome_of = |done| match done.class {
		Pass => "pass"
		Fail(_) => "fail"
		Hang => "hang"
		Crash(_) => "crash"
		NoFact(_) => "nofact"
	}

	done_doc : { class : Probe.Class, errors : List(Probe.Err) } -> JsonDoc
	done_doc = |done| JsonDoc.Obj([
		("outcome", Text(outcome_of(done))),
		("errors", Arr(done.errors.map(|e| Obj([("place", Text(place_text(e.file))), ("title", Text(e.title))])))),
	])

	end_doc : ProbeRange.End -> JsonDoc
	end_doc = |end| JsonDoc.Obj([("id", Text(end.id)), ("real", Flag(end.real))])
}
