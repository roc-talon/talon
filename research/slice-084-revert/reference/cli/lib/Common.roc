import Args
import Exit
import Fail
import Fx
import Out

## Helpers that every command shares: the `Fx` that it shows, the failure line, and `TALON_NIGHTLY`. They live here (not in `Install`) so that `Ladder` and `RocInstall` can use them
## with no import cycle (slice 025: `Ladder` imports `RocInstall`, and `Install` imports `Resolve`, which imports `Ladder`).
Common :: [].{

	# The `Fx` that the steps get: only `out!` changes (the table in the doc of `Install`).
	shown_fx : Fx, Args -> Fx
	shown_fx = |fx, args| if args.quiet {
		{ ..fx, out!: |_text| {} }
	} else if args.json {
		{ ..fx, out!: |text| fx.err!(text) }
	} else {
		fx
	}

	# R-EV4: `TALON_NIGHTLY` is `0` or `false`, `1` or `true`.
	nightly_of : List((Str, Str)) -> Try(Bool, [Unset])
	nightly_of = |env| match env.find_first(|(name, _)| name == "TALON_NIGHTLY") {
		Ok((_, "0")) | Ok((_, "false")) => Ok(Bool.False)
		Ok((_, "1")) | Ok((_, "true")) => Ok(Bool.True)
		_ => Err(Unset)
	}

	# A failure: the line on stderr, the envelope on stdout with `--json`, and the code of the kind.
	failed! : Fx, Args, Fail => I32
	failed! = |fx, args, fail| {
		shown = Out.fail({ command: args.typed, json: args.json, fail })
		if !shown.stdout.is_empty() fx.out!(shown.stdout)
		fx.err!(shown.stderr)
		Exit.choose({ failures: [fail], child: Err(NoChild) })
	}
}
