import pf.Path
import lib.Answer
import lib.Fail
import lib.Fx
import lib.Mode
import lib.Prompt
import L2Util

## The entry `prompt` of the L2 test app (slice 066, split from `main.roc`). The table in `main.roc` says what it does.
L2Prompt :: [].{

	entry! : Fx, Str => I32
	entry! = |fx, w| {
		env = Dict.from_list(fx.env_all!())
		text = match Path.read_utf8!(Path.utf8("${w}/fx/prompts")) {
			Ok(t) => t
			Err(_) => ""
		}
		specs = text.split_on("\n").keep_if(|l| !l.trim().is_empty())
		json = env.get("TEST_JSON") == Ok("1")
		mode = Mode.from_env({ env, json })
		match run_prompts!(fx, mode, specs) {
			Ok(_) => {
				# A command writes its result after its prompts. A stop writes nothing (R-NM5).
				_ = fx.write_atomic!([{ path: "${fx.cwd!()}/result.txt", content: "done\n" }])
				0
			}
			Err(fail) => {
				fx.err!("${fail.line()}\n")
				fail.kind.code()
			}
		}
	}

	run_prompts! : Fx, Mode, List(Str) => Try({}, Fail)
	run_prompts! = |fx, mode, specs| match specs {
		[] => Ok({})
		[line, .. as rest] => {
			(facts, prompt) = parse_line(line)
			done = Prompt.ask!(fx, prompt, { mode, yes: facts.yes, quiet: facts.quiet, flag: facts.flag })?
			fx.out!("${prompt.id}: ${show(done.answer)}\n")
			run_prompts!(fx, done.mode, rest)
		}
	}

	show : Answer -> Str
	show = |answer| match answer {
		Yes => "yes"
		No => "no"
		Option(n) => "option ${n.to_str()}"
	}

	parse_answer : Str -> Answer
	parse_answer = |text| match text {
		"yes" => Yes
		"no" => No
		other => Option(U64.from_str(other) ?? 1)
	}

	## A line of `fx/prompts`: `<flags> | <spec>`.
	## Flags: `--yes`, `--quiet`, `--answer=<yes|no|n>`.
	## Spec: `id=<id> kind=<default|consent|required:<flag>,<flag>> shape=<yesno|options:<n>> default=<yes|no|n> question=<words> subject=<words>`. In `question` and `subject`, `_` is a space.
	parse_line : Str -> ({ yes : Bool, quiet : Bool, flag : Try(Answer, [NoFlag]) }, Prompt)
	parse_line = |line| {
		(flag_part, spec_part) = match line.split_on("|") {
			[a, b] => (a, b)
			_ => ("", line)
		}
		flags = L2Util.words(flag_part)
		spec = L2Util.words(spec_part).map(
			|w| match w.split_on("=") {
				[k, .. as v] => (k, Str.join_with(v, "="))
				[] => ("", "")
			},
		)
		field = |name| match spec.find_first(|(k, _)| k == name) {
			Ok((_, v)) => v
			Err(_) => ""
		}
		answer_flag = match flags.find_first(|f| f.starts_with("--answer=")) {
			Ok(f) => Ok(parse_answer(f.drop_prefix("--answer=")))
			Err(_) => Err(NoFlag)
		}
		id = field("id")
		kind_text = field("kind")
		prompt : Prompt
		prompt = {
			id,
			kind: if kind_text == "consent" Consent else if kind_text.starts_with("required:") Required(kind_text.drop_prefix("required:").split_on(",")) else Default,
			shape: if field("shape").starts_with("options:") Options(U64.from_str(field("shape").drop_prefix("options:")) ?? 1) else YesNo,
			default: parse_answer(field("default")),
			question: field("question").replace_each("_", " "),
			subject: field("subject").replace_each("_", " "),
			answer_line: |a| "answer ${id}: ${show(a)}",
		}
		(
			{ yes: flags.contains("--yes"), quiet: flags.contains("--quiet"), flag: answer_flag },
			prompt,
		)
	}
}
