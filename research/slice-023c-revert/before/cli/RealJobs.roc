import pf.Cmd
import pf.Path
import pf.Sleep
import pf.Utc
import lib.Probe
import RealLocks

## Slice 003, R-DA5, R-HF4, R-CC12: runs the children of the jobs, at most `limit` at the same time, and polls them with `try_wait!`.
## The poll loop writes the heartbeat of the locks that the process holds, as `lock!` does (R-CC12 point 3).
RealJobs :: [].{

	run_jobs! : Str, { jobs : List(Job), limit : U64 } => List(JobResult)
	run_jobs! = |token, batch| {
		total = batch.jobs.len()
		limit = if batch.limit == 0 1 else batch.limit
		var $next = 0
		var $running = no_running
		var $done = no_results
		var $polls = 0
		while $next < total or !$running.is_empty() {
			while $next < total and $running.len() < limit {
				match batch.jobs.get($next) {
					Ok(job) => match start_job!(job) {
						Ok(child) => {
							$running = $running.append({ index: $next, child })
						}
						Err(text) => {
							$done = $done.append(($next, not_started(text)))
						}
					}
					Err(_) => {}
				}
				$next = $next + 1
			}
			var $still = no_running
			for entry in $running {
				match entry.child.try_wait!() {
					Ok([out]) => {
						entry.child.close!() |> ignore
						$done = $done.append((entry.index, job_result(out)))
					}
					Ok(_) => {
						$still = $still.append(entry)
					}
					Err(err) => {
						entry.child.close!() |> ignore
						$done = $done.append((entry.index, not_started(Str.inspect(err))))
					}
				}
			}
			$running = $still
			if !$running.is_empty() {
				# 100 polls of 20 ms: the heartbeat of 2 s
				if $polls % 100 == 0 {
					RealLocks.heartbeat!(token)
				}
				Sleep.millis!(20)
				$polls = $polls + 1
			}
		}
		finished = $done
		batch.jobs.map_with_index(
			|_, i| match finished.find_first(|(index, _)| index == i) {
				Ok((_, result)) => result
				Err(_) => not_started("not run")
			},
		)
	}

	## Slice 006. One child process for each probe, all started together (P0), the stdin closed, the stdout and the stderr kept as text, a timeout
	## that kills the child (`TimedOut`). The heartbeat of the held locks goes on while the probes run (R-CC12), as in `run_jobs!`. The L3 case `fx/pr1-real-fx-probes` checks it.
	probes! : Str, List(Probe.Spec) => List(Probe.Output)
	probes! = |token, specs| {
		var $running = no_probing
		var $done = no_outputs
		for (index, spec) in specs.map_with_index(|spec, i| (i, spec)) {
			match start_probe!(spec) {
				Ok(child) => {
					$running = $running.append({ index, child, deadline: Utc.now!() + spec.timeout.to_u128() * 1_000_000_000 })
				}
				Err(text) => {
					$done = $done.append((index, { ended: NotStarted(text), stdout: "", stderr: "" }))
				}
			}
		}
		var $polls = 0
		while !$running.is_empty() {
			var $still = no_probing
			now = Utc.now!()
			for entry in $running {
				match entry.child.try_wait!() {
					Ok([out]) => {
						entry.child.close!() |> ignore
						$done = $done.append((entry.index, probe_output(out)))
					}
					Ok(_) => if now >= entry.deadline {
						entry.child.kill!() |> ignore
						entry.child.close!() |> ignore
						$done = $done.append((entry.index, { ended: TimedOut, stdout: "", stderr: "" }))
					} else {
						$still = $still.append(entry)
					}
					Err(err) => {
						entry.child.close!() |> ignore
						$done = $done.append((entry.index, { ended: NotStarted(Str.inspect(err)), stdout: "", stderr: "" }))
					}
				}
			}
			$running = $still
			if !$running.is_empty() {
				# 100 polls of 20 ms: the heartbeat of 2 s
				if $polls % 100 == 0 {
					RealLocks.heartbeat!(token)
				}
				Sleep.millis!(20)
				$polls = $polls + 1
			}
		}
		finished = $done
		specs.map_with_index(
			|_, i| match finished.find_first(|(index, _)| index == i) {
				Ok((_, output)) => output
				Err(_) => { ended: NotStarted("not run"), stdout: "", stderr: "" }
			},
		)
	}
}

JobResult : { ended : [Exited(I32), Signaled(I32), NotStarted(Str)], stdout : Str, stderr_last : Str }

Job : { argv : List(Str), cwd : Try(Str, [Inherit]) }

Running : { index : U64, child : Cmd.Child }

no_running : List(Running)
no_running = []

no_results : List((U64, JobResult))
no_results = []

ignore : Try(a, b) -> {}
ignore = |_| {}

not_started : Str -> JobResult
not_started = |text| { ended: NotStarted(text), stdout: "", stderr_last: "" }

# One child: no stdin, its stdout and stderr are captured.
start_job! : Job => Try(Cmd.Child, Str)
start_job! = |job| match job.argv {
	[] => Err("empty command")
	[program, .. as rest] => {
		base = Cmd.new_str(program).args_str(rest).stdin(Null).stdout(Capture).stderr(Capture)
		cmd = match job.cwd {
			Ok(dir) => base.cwd(Path.utf8(dir))
			Err(Inherit) => base
		}
		match cmd.spawn!() {
			Ok(child) => Ok(child)
			Err(err) => Err(Str.inspect(err))
		}
	}
}

job_result : Cmd.RunOutput -> JobResult
job_result = |out| {
	lines = Str.from_utf8_lossy(out.stderr_bytes).split_on("\n").map(|line| line.trim()).keep_if(|line| !line.is_empty())
	{
		ended: match out.status {
			Exited(code) => Exited(code)
			Signaled(code) => Signaled(code)
		},
		stdout: Str.from_utf8_lossy(out.stdout_bytes),
		stderr_last: lines.last() ?? "",
	}
}

Probing : { index : U64, child : Cmd.Child, deadline : U128 }

no_probing : List(Probing)
no_probing = []

no_outputs : List((U64, Probe.Output))
no_outputs = []

# `roc` on PATH (R-PH6) in the dir of the probe. `manage_tree`: a kill also ends the children of roc (the linker).
start_probe! : Probe.Spec => Try(Cmd.Child, Str)
start_probe! = |spec| {
	cmd = Cmd.new_str("roc")
		.args_str(spec.args)
		.cwd(Path.utf8(spec.dir))
		.stdin(Null)
		.stdout(Capture)
		.stderr(Capture)
		.manage_tree(Bool.True)
	match cmd.spawn!() {
		Ok(child) => Ok(child)
		Err(err) => Err(Str.inspect(err))
	}
}

probe_output : Cmd.RunOutput -> Probe.Output
probe_output = |out| {
	ended: match out.status {
		Exited(code) => Exited(code)
		Signaled(code) => Signaled(code)
	},
	stdout: Str.from_utf8_lossy(out.stdout_bytes),
	stderr: Str.from_utf8_lossy(out.stderr_bytes),
}
