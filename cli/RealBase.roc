import pf.Cmd
import pf.Env
import pf.IOErr
import pf.OsStr
import pf.Random
import pf.Utc

## Small calls that the other `Real*` modules share (the clock, the environment, a random number, the text of an IO error). No Talon logic (TW4).
RealBase :: [].{

	env_all! : () => List((Str, Str))
	env_all! = || Env.dict!().map(|(name, value)| (name.display(), value.display()))

	clock! : () => U64
	clock! = || seconds(Utc.now!())

	## The whole seconds since 1970 of a time (basic-cli `Utc`). A time before 1970 is 0.
	seconds : Utc -> U64
	seconds = |time| (time.to_nanos_since_epoch() // 1_000_000_000).to_u64_try() ?? 0

	## A command of basic-cli from the program, the arguments and the environment pairs, all as text.
	command : Str, List(Str), List((Str, Str)) -> Cmd.Command
	command = |program, args, env| Cmd.new(OsStr.from_str(program)).args(args.map(OsStr.from_str)).envs(env.map(|(name, value)| (OsStr.from_str(name), OsStr.from_str(value))))

	## The text of a child that did not start, as basic-cli 0.25 gave it: the IO error (`NotFound`). `run!` puts it in `IO(..)`.
	start_err : [CmdErr(Cmd.Err), Interrupted] -> Str
	start_err = |err| match err {
		CmdErr(StartFailed(io, _)) => Str.inspect(io)
		CmdErr(IOErr(io)) => Str.inspect(io)
		other => Str.inspect(other)
	}

	run_err : [CmdErr(Cmd.Err), Interrupted] -> Str
	run_err = |err| match err {
		CmdErr(StartFailed(io, _)) => "IO(${Str.inspect(io)})"
		CmdErr(IOErr(io)) => "IO(${Str.inspect(io)})"
		other => Str.inspect(other)
	}

	file_err : IOErr -> [NotFound, Denied, Other(Str)]
	file_err = |err| match err {
		NotFound => NotFound
		PermissionDenied => Denied
		other => Other(Str.inspect(other))
	}

	# A random number for a temp name or a token (TW2). When the system has no random source, the clock is used.
	draw! : () => U64
	draw! = || match Random.seed_u64!() {
		Ok(n) => n
		Err(_) => (Utc.now!().to_nanos_since_epoch() // 1000).to_u64_wrap()
	}
}
