import records.Release
import records.Tlog
import records.Toolchain
import Clock
import Fail
import Fx
import Help
import LogKey
import LogProof
import RegistryCache
import Locked
import Registry
import Roots
import Text

## The log check of the releases that a command writes (CLI slice 261c, DESIGN-CLI 7.6 R-LV1 to R-LV12). Command code over `Fx`; the decisions are `LogKey.choose` and `LogProof`.
## `InstallFlow.finish!` calls `run!` just before `settle!`. Calls, in order (slice 261 section 14.3):
##
## | # | Call | When |
## | --- | --- | --- |
## | 1 | `read_files!` of the kept checkpoint `<data>/log/<origin>/checkpoint` | Always |
## | 2 | `http_get!` of `<base>/log/checkpoint`, up to 4 times, `sleep!` between (R-LV9) | The kept checkpoint is missing or too small |
## | 3 | `read_files!` of the tile copies, one call | Always |
## | 4 | `http_get_bytes!` of each tile with no copy, one at a time | A tile has no copy |
## | 5 | `list_dirs!` of the dir of the kept checkpoint | T4 only (the date) |
## | 6 | `write_atomic!` of the new tile copies, then the new checkpoint | The checks pass, also with `--dry-run` (Q261c-2) |
LogCheck :: [].{

	## The facts of one check. `checks` are the releases (`LogProof.to_check`), `config` is `log-key` of `config.toml`, `env` the environment of the process.
	Facts : { roots : Roots, base : Str, offline : Bool, env : List((Str, Str)), config : Try({ text : Str, path : Str, line : U64 }, [Unset]), checks : List(LogProof.Check) }

	## The header values that the edits write (alias, full name, URL). The name is the name of the variable of the alias, else the repository of the row of the URL, else its group.
	after_of : { ops : List(Locked.Op), names : List((Str, Str)), rows : List(Release.Row) } -> List({ alias : Str, name : Str, url : Str })
	after_of = |x| x.ops.keep_oks(
		|op| {
			(alias, url) = match op {
				Set(v) => (v.alias, v.url)
				Replace(v) => (v.alias, v.url)
				Add(v) => (v.alias, v.url)
				_ => return Err(NotValue)
			}
			named = x.names.find_first(|(a, _)| a == alias)
			row = x.rows.find_first(|r| r.url == url)
			name = match (named, row) {
				(Ok((_, n)), _) => n
				(Err(_), Ok(r)) => r.repo ?? r.group
				(Err(_), Err(_)) => ""
			}
			Ok({ alias, name, url })
		},
	)

	## Slice 261d (Q261d-1, Q261d-2): the check of one tool release (`tln tool install`, `tln x`, the take-over of an x entry). `base` is the registry of the list (`Err(None)`: a `direct` list, no check),
	## `url` the URL of the release that the command writes, `rows` the R-AP1 rows of the run. No row with that URL: no check.
	Tool : { roots : Roots, base : Try(Str, [None]), offline : Bool, env : List((Str, Str)), config : Try({ text : Str, path : Str, line : U64 }, [Unset]), name : Str, url : Str, rows : List(Release.Row) }

	tool! : Fx, LogCheck.Tool => Try({}, Fail)
	tool! = |fx, t| match (t.base, t.rows.find_first(|r| r.url == t.url)) {
		(Ok(origin), Ok(row)) => LogCheck.run!(fx, { roots: t.roots, base: origin, offline: t.offline, env: t.env, config: t.config, checks: [LogProof.tool_check({ name: t.name, row })] })
		_ => Ok({})
	}

	## Slice 261d (R-LV1, R-SE11): the check of a compiler of a registry list, before the prompt and the download. `row` is the toolchain row of the pick.
	Compiler : { roots : Roots, base : Str, offline : Bool, env : List((Str, Str)), config : Try({ text : Str, path : Str, line : U64 }, [Unset]), row : Toolchain.Row }

	compiler! : Fx, LogCheck.Compiler => Try({}, Fail)
	compiler! = |fx, c| LogCheck.run!(fx, { roots: c.roots, base: c.base, offline: c.offline, env: c.env, config: c.config, checks: [LogProof.compiler_check(c.row)] })

	## No check and no key: no call (R-LV12: nothing on success).
	run! : Fx, LogCheck.Facts => Try({}, Fail)
	run! = |fx, facts| match facts.checks {
		[] => Ok({})
		[first, ..] => {
			env = match facts.env.find_first(|(name, _)| name == "TALON_LOG_KEY") {
				Ok((_, value)) => Ok(value)
				Err(_) => Err(Unset)
			}
			match LogKey.choose({ base: facts.base, env, config: facts.config })? {
				Err(NoKey) => Ok({})
				Ok(chosen) => prove!(fx, facts, chosen, first)
			}
		}
	}
}

# What the steps share.
Run : { base : Str, offline : Bool, roots : Roots, key : { key : LogKey.VerifierKey, source : LogKey.Source }, checks : List(LogProof.Check), first : LogProof.Check, need : U64, dir : Str }

prove! : Fx, LogCheck.Facts, { key : LogKey.VerifierKey, source : LogKey.Source }, LogProof.Check => Try({}, Fail)
prove! = |fx, facts, key, first| {
	name = facts.base.replace_each("://", "_").replace_each(":", "_")
	run = {
		base: facts.base,
		offline: facts.offline,
		roots: facts.roots,
		key,
		checks: facts.checks,
		first,
		need: facts.checks.fold(0, |most, c| U64.max(most, c.log_index)),
		dir: Text.join(facts.roots.data, "log/${name}"),
	}
	kept_path = Text.join(run.dir, "checkpoint")
	kept_text = fx.read_files!([kept_path])
	kept = kept_of(key.key, kept_text)
	# R-LV6, Q261-8: the kept checkpoint is used when its size covers every log index.
	current = match kept {
		Ok(found) if found.cp.size >= run.need => { cp: found.cp, text: Err(None) }
		_ => {
			if run.offline {
				open = run.checks.find_first(|c| c.log_index > (kept.map_ok(|f| f.cp.size) ?? 0)) ?? run.first
				return Err(stop(run, Offline, Ok(open), Err(None)))
			}
			read_checkpoint!(fx, run, 1)?
		}
	}
	size = current.cp.size
	# R-LV10: the consistency tiles only when this command read a new checkpoint.
	kept_size = match (current.text, kept) {
		(Ok(_), Ok(found)) => Ok(found.cp.size)
		_ => Err(None)
	}
	tiles = LogProof.tiles_of({ kept: kept_size, size, indexes: run.checks.map(|c| c.log_index) })
	copies = fx.read_files!(tiles.map(|t| tile_path(run, t)))
	var $have = []
	var $new_tiles = []
	for (tile, copy) in tiles.map2(copies, |t, c| (t, c)) {
		from_copy = match copy {
			Ok(text) => LogProof.copy_bytes(tile, text).map_err(|_| None)
			Err(_) => Err(None)
		}
		match from_copy {
			Ok(bytes) => {
				$have = $have.append({ tile, bytes })
			}
			Err(None) => {
				if run.offline {
					return Err(stop(run, Offline, Ok(run.first), Err(None)))
				}
				fetched = fx.http_get_bytes!({ url: "${run.base}/log/${Tlog.path(tile)}", headers: Registry.headers({ version: Help.version, body: None }) })
				match bytes_answer(fetched) {
					Ok(bytes) => {
						$have = $have.append({ tile, bytes })
						$new_tiles = $new_tiles.append({ tile, bytes })
					}
					Err(why) => return Err(stop(run, TileMissing({ tile: Tlog.path(tile), cause: why }), Err(None), Ok(size)))
				}
			}
		}
	}
	have = $have
	# R-LV10, Q261-7: the new checkpoint must contain the kept one.
	match kept_size {
		Ok(old) => match kept {
			Ok(found) => match Tlog.check_consistency(found.cp, current.cp, have) {
				Ok({}) => {}
				Err(_) => {
					date = Str.from_utf8(Clock.format_utc(kept_mtime!(fx, run.dir)).to_utf8().take_first(10)) ?? ""
					return Err(stop(run, NotConsistent({ kept: old, date, path: kept_path }), Err(None), Ok(size)))
				}
			}
			Err(None) => {}
		}
		Err(None) => {}
	}
	# R-LV2, R-LV3: for each release, in the order of `log_index`, the entry, the URL and the inclusion.
	for c in run.checks {
		match prove_one(current.cp, have, c) {
			Ok({}) => {}
			Err(why) => return Err(stop(run, why, Ok(c), Ok(size)))
		}
	}
	# R-LV7, R-IX8: the copies are written after each proof passed.
	tile_writes = $new_tiles.keep_oks(|t| LogProof.copy_text(t).map_ok(|text| { path: tile_path(run, t.tile), content: text }))
	cp_writes = match current.text {
		Ok(text) => [{ path: kept_path, content: text }]
		Err(None) => []
	}
	writes = tile_writes.concat(cp_writes)
	if writes.is_empty() {
		Ok({})
	} else {
		match fx.write_atomic!(writes) {
			Ok(_) => Ok({})
			Err(failed) => Err(Fail.new(Environment, "cannot write ${failed.path}"))
		}
	}
}

# The checkpoint of the log, read up to 4 times (R-LV9). `text` is the checkpoint as served.
read_checkpoint! : Fx, Run, U64 => Try({ cp : Tlog.Checkpoint, text : Try(Str, [None]) }, Fail)
read_checkpoint! = |fx, run, n| {
	reply = fx.http_get!({ url: "${run.base}/log/checkpoint", headers: Registry.headers({ version: Help.version, body: None }) })
	text = text_answer(reply).map_err(|cause| stop(run, NoAnswer(cause), Ok(run.first), Err(None)))?
	cp = LogProof.open_checkpoint(run.key.key, text).map_err(|_| stop(run, BadSignature(run.key), Err(None), Err(None)))?
	match LogProof.after_read({ read: n, size: cp.size, need: run.need }) {
		Covers => Ok({ cp, text: Ok(text) })
		Again(ms) => {
			fx.sleep!(ms)
			read_checkpoint!(fx, run, n + 1)
		}
		Behind => {
			behind = run.checks.find_first(|c| c.log_index > cp.size) ?? run.first
			Err(stop(run, Behind, Ok(behind), Ok(cp.size)))
		}
	}
}

# R-LV2, R-LV3: the entry at the log index is the row, the URL is made from it, and the tiles prove the entry in the signed tree.
prove_one : Tlog.Checkpoint, List(Tlog.TileBytes), LogProof.Check -> Try({}, LogProof.Why)
prove_one = |cp, have, c| {
	at = if (c.log_index == 0) 0 else c.log_index - 1
	tile = Tlog.entry_tile(at, cp.size).map_err(|_| NotIncluded)?
	found = have.find_first(|t| t.tile == tile).map_err(|_| NotIncluded)?
	entry = Tlog.entry_at(at, found).map_err(|_| NotIncluded)?
	leaf = Tlog.parse_entry(entry).map_err(|_| EntryDiffers(Str.from_utf8(entry.drop_last(1)) ?? ""))?
	LogProof.check_leaf(c, leaf).map_err(
		|why| match why {
			EntryDiffers => EntryDiffers("${leaf.grp} ${leaf.version} ${leaf.hash}")
			UrlDiffers => UrlDiffers
		},
	)?
	Tlog.check_inclusion(at, cp, entry, have).map_err(|_| NotIncluded)
}

# The failure of a check (T1 to T7).
stop : Run, LogProof.Why, Try(LogProof.Check, [None]), Try(U64, [None]) -> Fail
stop = |run, why, release, size| LogProof.fail({ base: run.base, release, size }, why)

# R-IX8: `<index>/registry/<origin dir>/log/<tile path>`.
tile_path : Run, Tlog.Tile -> Str
tile_path = |run, tile| Text.join(RegistryCache.origin_dir({ roots: run.roots, origin: run.base }), "log/${Tlog.path(tile)}")

# Design P2: the modification time of the kept checkpoint in seconds (0 when the listing does not give it).
kept_mtime! : Fx, Str => U64
kept_mtime! = |fx, dir| match fx.list_dirs!([dir]) {
	[Ok(entries)] => match entries.find_first(|e| e.name == "checkpoint") {
		Ok(e) => e.mtime
		Err(_) => 0
	}
	_ => 0
}

# The kept checkpoint when it reads and its signature is valid (a copy that does not verify is as no copy).
kept_of : LogKey.VerifierKey, List(Try(Str, [NotFound, Denied, Other(Str)])) -> Try({ cp : Tlog.Checkpoint, text : Str }, [None])
kept_of = |key, read| match read {
	[Ok(text)] => match LogProof.open_checkpoint(key, text) {
		Ok(cp) => Ok({ cp, text })
		Err(_) => Err(None)
	}
	_ => Err(None)
}

# R-RG9 row 5: the words of the cause of a read with no answer.
text_answer : Try({ status : U16, headers : List((Str, Str)), body : Str }, [Timeout, Failed(Str)]) -> Try(Str, Str)
text_answer = |reply| match reply {
	Ok(r) if r.status == 200 => Ok(r.body)
	Ok(r) => Err("status ${r.status.to_str()}")
	Err(Timeout) => Err("timeout")
	Err(Failed(text)) => Err(text)
}

bytes_answer : Try({ status : U16, headers : List((Str, Str)), body : List(U8) }, [Timeout, Failed(Str)]) -> Try(List(U8), Str)
bytes_answer = |reply| match reply {
	Ok(r) if r.status == 200 => Ok(r.body)
	Ok(r) => Err("status ${r.status.to_str()}")
	Err(Timeout) => Err("timeout")
	Err(Failed(text)) => Err(text)
}
