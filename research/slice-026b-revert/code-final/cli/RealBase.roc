import pf.Env
import pf.IOErr
import pf.Random
import pf.Utc

## Small calls that the other `Real*` modules share (the clock, the environment, a random number, the text of an IO error). No Talon logic (TW4).
RealBase :: [].{

	env_all! : () => List((Str, Str))
	env_all! = || Env.dict!().map(|(name, value)| (name.display(), value.display()))

	clock! : () => U64
	clock! = || (Utc.now!() // 1_000_000_000).to_u64_wrap()

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
		Err(_) => (Utc.now!() // 1000).to_u64_wrap()
	}
}
