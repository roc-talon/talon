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

	## Slice 006. One child process for each probe, the stdin closed, the stdout and the stderr kept as text, a timeout
	## that kills the child (`TimedOut`). The heartbeat of the held locks goes on while the probes run (R-CC12), as in `run_jobs!`.
	## Slice 031 (R-PP6, R-PP7, R-PP5): the probes take slots from a pool of `round.pool` slots. A probe takes `spec.weight` slots (at least 1, at most the pool: a weight above the pool takes the whole pool). The probes start in the order of the list (FIFO): the next probe waits until its slots are free, and no probe behind it starts before it. A probe that hangs keeps its slots until its timeout kills it. The L3 case `fx/pl1-probe-pool` checks it.
	probes! : Str, { pool : U64, specs : List(Probe.Spec) } => List(Probe.Output)
	probes! = |token, round| {
		specs = round.specs
		total = specs.len()
		pool = if round.pool == 0 1 else round.pool
		var $next = 0
		var $used = 0
		var $running = no_probing
		var $done = no_outputs
		var $polls = 0
		while $next < total or !$running.is_empty() {
			# FIFO: the next probe waits until its slots are free, and none behind it starts before it.
			var $waiting = Bool.False
			while $next < total and !$waiting {
				match specs.get($next) {
					Ok(spec) => {
						need = slots_of(spec, pool)
						if $used + need > pool {
							$waiting = Bool.True
						} else {
							match start_probe!(spec) {
								Ok(child) => {
									$used = $used + need
									$running = $running.append({ index: $next, child, deadline: Utc.now!() + spec.timeout.to_u128() * 1_000_000_000, need })
								}
								Err(text) => {
									$done = $done.append(($next, { ended: NotStarted(text), stdout: "", stderr: "" }))
								}
							}
							$next = $next + 1
						}
					}
					Err(_) => {
						$next = total
					}
				}
			}
			var $still = no_probing
			now = Utc.now!()
			for entry in $running {
				match entry.child.try_wait!() {
					Ok([out]) => {
						entry.child.close!() |> ignore
						$used = $used - entry.need
						$done = $done.append((entry.index, probe_output(out)))
					}
					Ok(_) => if now >= entry.deadline {
						entry.child.kill!() |> ignore
						entry.child.close!() |> ignore
						$used = $used - entry.need
						$done = $done.append((entry.index, { ended: TimedOut, stdout: "", stderr: "" }))
					} else {
						$still = $still.append(entry)
					}
					Err(err) => {
						entry.child.close!() |> ignore
						$used = $used - entry.need
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

Probing : { index : U64, child : Cmd.Child, deadline : U128, need : U64 }

# R-PP6, D10: the slots of a probe, at least 1 and at most the pool (a weight above the pool takes the whole pool).
slots_of : Probe.Spec, U64 -> U64
slots_of = |spec, pool| if spec.weight == 0 1 else if spec.weight > pool pool else spec.weight

no_probing : List(Probing)
no_probing = []

no_outputs : List((U64, Probe.Output))
no_outputs = []

# `roc` on PATH (R-PH6) in the dir of the probe. `manage_tree`: a kill also ends the children of roc (the linker).
start_probe! : Probe.Spec => Try(Cmd.Child, Str)
start_probe! = |spec| {
	cmd = Cmd.new_str(spec.program)
		.args_str(spec.args)
		.envs_str(spec.env)
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
