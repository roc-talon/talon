import pf.Path
import pf.IOErr
import pf.Sleep
import lib.Item
import lib.Lock
import lib.Roots
import lib.Temp
import lib.Text
import RealBase

## R-CC3 and R-CC12: the lock is the directory `<item>.lock/` with the files `owner` and `beat`. The decisions are in `Lock`
## (`state`, `owner_text`, `owns`, `stale_name`). This file only makes the calls. A held lock has one line in the
## registry `<cache>/talon/tmp/<token>.locks` (Q8), so that a later `lock!` call of the same process can write `beat`
## again for it while it waits. The registry and its directory are deleted when the last lock of the process is released.
RealLocks :: [].{

	take_lock! : Str, Str, [Wait, NoWait] => [Held(Lock), Busy]
	take_lock! = |token, item, mode| {
		parent = Text.dir_of(item)
		if !parent.is_empty() {
			_ = Path.create_all!(Path.utf8(parent))
		}
		var $polls = 0
		var $outcome = attempt!(token, item, mode)
		while is_open($outcome) {
			if $outcome == Waiting {
				# 10 polls of 200 ms: the heartbeat of 2 s
				if $polls % 10 == 0 {
					RealLocks.heartbeat!(token)
				}
				_ = Sleep.millis!(200)
				$polls = $polls + 1
			}
			$outcome = attempt!(token, item, mode)
		}
		match $outcome {
			Held(lock) => Held(lock)
			_ => Busy
		}
	}

	# R-CC12: the directory is deleted only when `owner` has the token of this process.
	release_lock! : Lock => {}
	release_lock! = |lock| {
		dir = Lock.dir(lock.item)
		owner = match Path.read_utf8!(Path.utf8("${dir}/owner")) {
			Ok(text) => text
			Err(_) => ""
		}
		if Lock.owns({ owner, token: lock.token }) {
			_ = Path.delete_all!(Path.utf8(dir))
		}
		unregister!(lock.token, lock.item)
	}

	# R-CC12 point 3: `beat` is written again for each lock that this process holds and still owns.
	heartbeat! : Str => {}
	heartbeat! = |token| for item in held!(token) {
		dir = Lock.dir(item)
		owner = match Path.read_utf8!(Path.utf8("${dir}/owner")) {
			Ok(text) => text
			Err(_) => ""
		}
		if Lock.owns({ owner, token }) {
			_ = Path.write_utf8!(Path.utf8("${dir}/beat"), "${RealBase.clock!().to_str()}\n")
		}
	}
}

Outcome : [Held(Lock), Busy, Again, Waiting]

is_open : Outcome -> Bool
is_open = |outcome| match outcome {
	Again | Waiting => Bool.True
	_ => Bool.False
}

# One try. `Again`: the state changed, try now. `Waiting`: a live lock, and the mode is `Wait`.
attempt! : Str, Str, [Wait, NoWait] => Outcome
attempt! = |token, item, mode| {
	dir = Lock.dir(item)
	match Path.create_dir!(Path.utf8(dir)) {
		Ok(_) => {
			started = RealBase.clock!()
			_ = Path.write_utf8!(Path.utf8("${dir}/owner"), Lock.owner_text({ token, started }))
			_ = Path.write_utf8!(Path.utf8("${dir}/beat"), "${started.to_str()}\n")
			register!(token, item)
			Held(Lock.{ item, token })
		}
		Err(PathErr(AlreadyExists, _)) => contended!(item, mode)
		Err(PathErr(err, _)) => match mode {
			NoWait => Busy
			Wait => crash "cannot make the lock directory ${dir}: ${IOErr.to_str(err)}"
		}
	}
}

# The lock directory is there. A stale one is taken: rename it, delete it, try again (R-CC12).
contended! : Str, [Wait, NoWait] => Outcome
contended! = |item, mode| {
	dir = Lock.dir(item)
	beat = match modified_seconds!("${dir}/beat") {
		Ok(seconds) => Ok(seconds)
		Err(_) => Err(NoBeat)
	}
	live = match mode {
		NoWait => Busy
		Wait => Waiting
	}
	match modified_seconds!(dir) {
		Err(NotFound) => Again
		Err(_) => live
		Ok(made) => match Lock.state({ now: RealBase.clock!(), beat, dir: made }) {
			Live => live
			Stale => {
				gone = Path.utf8(Lock.stale_name({ item, hex: Temp.hex(RealBase.draw!()) }))
				match Path.rename!(Path.utf8(dir), gone) {
					Ok(_) => {
						_ = Path.delete_all!(gone)
						Again
					}
					Err(_) => live
				}
			}
		}
	}
}

modified_seconds! : Str => Try(U64, [NotFound, Denied, Other(Str)])
modified_seconds! = |path| match Path.time_modified!(Path.utf8(path)) {
	Ok(ns) => Ok(RealBase.seconds(ns))
	Err(PathErr(err, _)) => Err(RealBase.file_err(err))
}

# The registry file of this process (Q8). It is not there when HOME is not set: then no heartbeat.
registry_path! : Str => Try(Str, [NoRegistry])
registry_path! = |token| match Roots.from_env(RealBase.env_all!()) {
	Ok(roots) => Ok("${Roots.item(roots, Item.TalonTmp(token))}.locks")
	Err(_) => Err(NoRegistry)
}

held! : Str => List(Str)
held! = |token| match registry_path!(token) {
	Ok(path) => match Path.read_utf8!(Path.utf8(path)) {
		Ok(text) => text.split_on("\n").keep_if(|line| !line.is_empty())
		Err(_) => []
	}
	Err(NoRegistry) => []
}

register! : Str, Str => {}
register! = |token, item| match registry_path!(token) {
	Err(NoRegistry) => {}
	Ok(path) => {
		text = Str.join_with(held!(token).append(item), "\n")
		parent = Path.utf8(Text.dir_of(path))
		# Another process can delete the empty directory between the two calls: make it, and write again.
		match Path.write_utf8!(Path.utf8(path), "${text}\n") {
			Ok(_) => {}
			Err(_) => {
				_ = Path.create_all!(parent)
				_ = Path.write_utf8!(Path.utf8(path), "${text}\n")
			}
		}
	}
}

unregister! : Str, Str => {}
unregister! = |token, item| match registry_path!(token) {
	Err(NoRegistry) => {}
	Ok(path) => {
		rest = held!(token).keep_if(|line| line != item)
		if rest.is_empty() {
			_ = Path.delete!(Path.utf8(path))
			_ = Path.delete_empty!(Path.utf8(Text.dir_of(path)))
		} else {
			_ = Path.write_utf8!(Path.utf8(path), "${Str.join_with(rest, "\n")}\n")
		}
	}
}
