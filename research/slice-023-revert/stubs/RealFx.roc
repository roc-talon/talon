import pf.Cmd
import pf.Http
import pf.Env
import pf.Path
import pf.Stderr
import pf.Stdin
import pf.Stdout
import http.Request
import http.Response
import lib.Fx
import lib.Temp
import RealBase
import RealFiles
import RealJobs
import RealLocks

## The real `Fx` on basic-cli (TESTING.md 2.3). It has no Talon logic (TW4): each call is
## one platform effect, or one small child process. L3 tests it with `cli/fxprobe.roc`.
RealFx :: [].{

	## The real `Fx`. `args` are the arguments that `main!` got, as text.
	## It is effectful (slice 002): the real `Fx` can draw a token of the process (`Random.seed_u64!`) for the locks (R-CC12).
	make! : List(Str) => Fx
	make! = |args| {
		token = Temp.hex(RealBase.draw!())
		real_fx(args, token)
	}
}

real_fx : List(Str), Str => Fx
real_fx = |args, token| Fx.{
	args!: || args,
	env_all!: RealBase.env_all!,
	cwd!: cwd!,
	tty!: tty!,
	clock!: RealBase.clock!,
	read_files!: RealFiles.read_files!,
	write_atomic!: RealFiles.write_atomic!,
	out!: |text| {
		_ = Stdout.write!(text)
	},
	err!: |text| {
		_ = Stderr.write!(text)
	},
	ask!: ask!,
	list_dirs!: RealFiles.list_dirs!,
	delete!: RealFiles.delete!,
	canonical!: RealFiles.canonical!,
	lock!: |item, mode| RealLocks.take_lock!(token, item, mode),
	unlock!: RealLocks.release_lock!,
	http_get!: http_get!,
	programs!: programs!,
	spawn_all!: |batch| RealJobs.run_jobs!(token, batch),
	rename!: rename!,
	make_dirs!: make_dirs!,
	random!: RealBase.draw!,
	probes!: |specs| RealJobs.probes!(token, specs),
	copy_tree!: RealFiles.copy_tree!,
	platform!: platform!,
	sha256_file!: RealFiles.sha256_file!,
	path_roc!: RealFiles.path_roc!,
	program_name!: program_name!,
	exec!: exec!,
}

## Slice 023, R-HF9: the program name (basic-cli `Env.program_name!`). Stub: the empty text, so no run is a proxy.
program_name! : () => Str
program_name! = || ""

## Slice 023, R-HF6, R-E1: one child with the terminal of the process (basic-cli `Cmd.run!` with inherited stdio), the exit code or 128 + the signal. Stub.
exec! : { argv : List(Str), env : List((Str, Str)) } => Try(I32, [NotStarted(Str)])
exec! = |_run| crash "todo"

cwd! : () => Str
cwd! = || match Env.cwd!() {
	Ok(path) => path.display()
	Err(_) => ""
}

## R-HF1. Until basic-cli has `isatty`: one child with inherited stdin and stderr. `test -t` gives
## 0 for a terminal. The child writes `<stdin> <stderr>` to the captured stdout, as two exit codes.
## On Windows Talon takes both as a terminal (R-HF1, CLI 4, R-NR1).
tty! : () => { stdin : Bool, stderr : Bool }
tty! = || {
	match Env.platform!().os {
		WINDOWS => { stdin: Bool.True, stderr: Bool.True }
		_ => {
			cmd = Cmd.new_str("sh")
				.args_str(["-c", "test -t 0; i=$?; test -t 2; echo $i $?"])
				.stdin(Inherit)
				.stderr(Inherit)
				.stdout(Capture)
			match cmd.run!() {
				Ok(out) => {
					text = Str.from_utf8_lossy(out.stdout_bytes).trim()
					{ stdin: text.starts_with("0 "), stderr: text.ends_with(" 0") }
				}
				Err(_) => { stdin: Bool.False, stderr: Bool.False }
			}
		}
	}
}

ask! : Str => Try(Str, [EndOfInput])
ask! = |prompt| {
	_ = Stderr.write!(prompt)
	match Stdin.line!() {
		Ok(line) => Ok(line)
		Err(_) => Err(EndOfInput)
	}
}

## Slice 003. One GET with a timeout of 20 s (R-CC12). The headers are the pairs of the request. No Talon logic: the pure code of
## `Github` and `Net` decides what the answer means.
http_get! : { url : Str, headers : List((Str, Str)) } => Try({ status : U16, headers : List((Str, Str)), body : Str }, [Timeout, Failed(Str)])
http_get! = |req| {
	base = Request.from_method(GET).with_uri(req.url).with_timeout(TimeoutMilliseconds(20000))
	request = req.headers.fold(base, |r, (name, value)| r.add_header(name, value))
	match Http.send!(request) {
		Ok(response) => match Str.from_utf8(Response.body(response)) {
			Ok(body) => Ok({
				status: Response.status(response),
				headers: Response.headers(response).map(|h| (h.name, h.value)),
				body,
			})
			Err(_) => Err(Failed("bad body"))
		}
		Err(InvalidUrl(_)) => Err(Failed("invalid URL"))
		Err(HttpErr(Timeout)) => Err(Timeout)
		Err(HttpErr(NetworkError)) => Err(Failed("network error"))
		Err(HttpErr(BadBody)) => Err(Failed("bad body"))
		Err(HttpErr(Other(bytes))) => Err(Failed(Str.from_utf8_lossy(bytes)))
	}
}

## Whether each program is on `PATH` (basic-cli `Cmd.check_available!`).
programs! : List(Str) => List(Bool)
programs! = |names| {
	var $found = []
	for name in names {
		$found = $found.append(Cmd.check_available!(name))
	}
	$found
}

## `rename`. `Exists` is `AlreadyExists`, and also "directory not empty" (the system gives it for a directory that is the target).
rename! : { from : Str, to : Str } => Try({}, [NotFound, Exists, Denied, Other(Str)])
rename! = |move| match Path.rename!(Path.utf8(move.from), Path.utf8(move.to)) {
	Ok(_) => Ok({})
	Err(PathErr(AlreadyExists, _)) => Err(Exists)
	Err(PathErr(NotFound, _)) => Err(NotFound)
	Err(PathErr(PermissionDenied, _)) => Err(Denied)
	Err(PathErr(Other(text), _)) => if text.contains("not empty") or text.contains("exists") Err(Exists) else Err(Other(text))
	Err(PathErr(other, _)) => Err(Other(Str.inspect(other)))
}

make_dirs! : List(Str) => Try({}, [Denied, Other(Str)])
make_dirs! = |dirs| {
	var $failure = Ok({})
	for dir in dirs {
		if $failure == Ok({}) {
			$failure = match Path.create_all!(Path.utf8(dir)) {
				Ok(_) => Ok({})
				Err(PathErr(PermissionDenied, _)) => Err(Denied)
				Err(PathErr(err, _)) => Err(Other(Str.inspect(err)))
			}
		}
	}
	$failure
}

# R-CV8: the system of this machine, with the names of `Fx` (`X86` and `ARM` have no compiler asset: `Other`).
platform! : () => { os : [Linux, Macos, Windows, Other(Str)], arch : [X64, Arm64, Other(Str)] }
platform! = || {
	found = Env.platform!()
	{
		os: match found.os {
			LINUX => Linux
			MACOS => Macos
			WINDOWS => Windows
			OTHER(name) => Other(name)
		},
		arch: match found.arch {
			X64 => X64
			AARCH64 => Arm64
			X86 => Other("x86")
			ARM => Other("arm")
			OTHER(name) => Other(name)
		},
	}
}
