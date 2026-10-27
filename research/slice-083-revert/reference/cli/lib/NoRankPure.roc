import Answer
import Consent
import Db
import Fail
import Pin
import Prompt
import Text
import Toolchain

## The pure part of `NoRank` (slice 072e): a leaf module, because `RocInstall` and `Start` need the pick, the gate and the prompt, and `NoRank` imports both. `NoRank.pick`, `NoRank.keys`, `NoRank.gate`
## and `NoRank.prompt` are the same functions. The rules and the tables are in the docs of `NoRank`.
NoRankPure :: [].{

	Scope : [Outside, Project(List(Str))]

	pick : { auto : List(Str), scope : NoRankPure.Scope, facts : List(Db.Fact) } -> Try(Str, [Empty])
	pick = |run| match run.auto.last() {
		Err(_) => Err(Empty)
		Ok(latest) => match run.scope {
			Outside => Ok(latest)
			Project(hashes) => {
				checks = run.facts.keep_if(|f| f.target == "any")
				known = hashes.keep_if(|hash| checks.any(|f| f.hash == hash))
				passes = |hash, id| checks.any(|f| f.hash == hash and f.outcome == Pass and Pin.same_id(f.nightly, id))
				suits = run.auto.keep_if(|id| known.all(|hash| passes(hash, id)))
				Ok(suits.last() ?? latest)
			}
		}
	}

	keys : { hashes : List(Str), auto : List(Str) } -> List(Db.Key)
	keys = |run| Text.sorted_unique(run.hashes).join_map(|hash| run.auto.map(|id| { hash, nightly: id, target: "any" }))

	gate : { auto : [Ask, Yes, No], yes : Bool, flag : Try(Answer, [NoFlag]), offline : Bool } -> [Go, Stop(Fail)]
	gate = |run| if run.offline {
		Stop(Fail.new(Consent, "no compiler is selected, and --offline stops the download. Run: tln roc install @latest when you are online, then tln roc default <id>."))
	} else if Consent.auto_refuses({ auto: run.auto, yes: run.yes, flag: run.flag }) {
		Stop(Fail.new(Consent, "no compiler is selected. TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install @latest, then tln roc default <id>, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes."))
	} else {
		Go
	}

	prompt : { id : Str, size : U64 } -> Prompt
	prompt = |facts| {
		name = facts.id
		size = Toolchain.size_text(facts.size)
		yes_line = "downloading ${name} (${size}), the default compiler"
		no_line = "no download of ${name}"
		Prompt.{
			id: "no-rank-download",
			kind: Required(["--allow-downloads", "TALON_AUTO_INSTALL=yes"]),
			shape: YesNo,
			default: No,
			question: "No compiler is selected. Download ${name}, ${size}? It becomes the default compiler.",
			subject: "the download of ${name}",
			answer_line: |answer| if answer == Yes yes_line else no_line,
		}
	}
}
