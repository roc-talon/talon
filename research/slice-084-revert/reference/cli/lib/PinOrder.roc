import Clock
import Selector
import Text
import semver.Semver

## The order and the identity of compiler ids (slice 039s: split from `Pin`; rules R-NS1, R-CV1, Q9). A compiler id is a nightly tag or a release version. Pure. `Pin.order`, `Pin.same_id`, `Pin.is_nightly` and `Pin.admits` use it.
PinOrder :: [].{

	## Is the id a nightly tag (`nightly-` and 3 parts, the form of Design 2)? A release is not.
	is_nightly : Str -> Bool
	is_nightly = |id| Selector.parse(id, Bool.False) == Ok(Nightly(id))

	## R-CV1 (slice 022): are the 2 ids one compiler? Equal texts, or two nightlies with the same date and the same sha (the two tag forms: `nightly-2026-July-23-abc1234` and `nightly-2026-07-23-abc1234`).
	same_id : Str, Str -> Bool
	same_id = |a, b| a == b or (
		match (nightly_key(a), nightly_key(b)) {
			(Ok(x), Ok(y)) => x == y
			_ => Bool.False
		}
	)

	# Q9: a lower bound admits an id of its own kind (a nightly or a release) that `order_of` does not put before it.
	at_least : Str, Str, List({ id : Str, published_at : U64 }) -> Bool
	at_least = |bound, id, times| {
		both_nightly = is_nightly(bound) and is_nightly(id)
		both_release = is_release(bound) and is_release(id)
		(both_nightly or both_release) and order_of(id, bound, times) != Before
	}

	# R-NS1: the key is the day, then the kind, then the time of 2 nightlies, then the text.
	order_of : Str, Str, List({ id : Str, published_at : U64 }) -> [Before, Same, After]
	order_of = |a, b, times| match (id_kind(a), id_kind(b)) {
		(Other, _) | (_, Other) => Same
		_ => if same_id(a, b) {
			Same
		} else {
			day_a = day_of(a, times)
			day_b = day_of(b, times)
			match (day_a, day_b) {
				(Ok(x), Ok(y)) => match compare_dates(x, y) {
					Same => same_day(a, b, times)
					other => other
				}
				(Err(_), Ok(_)) => Before
				(Ok(_), Err(_)) => After
				(Err(_), Err(_)) => by_version(a, b)
			}
		}
	}

	id_kind : Str -> [Nightly, Release, Other]
	id_kind = |id| if is_nightly(id) Nightly else if is_release(id) Release else Other

	# The day as `[year, month, day]`: the date of a tag, or the UTC day of the `published_at` of a release.
	day_of : Str, List({ id : Str, published_at : U64 }) -> Try(List(U64), [NoDay])
	day_of = |id, times| match nightly_key(id) {
		Ok(key) => Ok(key.date)
		Err(_) => match published(id, times) {
			Ok(at) => {
				parts = Clock.format_utc(at).split_first("T").map_ok(|s| s.before.split_on("-").keep_oks(U64.from_str))
				match parts {
					Ok([y, m, d]) => Ok([y, m, d])
					_ => Err(NoDay)
				}
			}
			Err(_) => Err(NoDay)
		}
	}

	published : Str, List({ id : Str, published_at : U64 }) -> Try(U64, [NoTime])
	published = |id, times| match times.find_first(|row| same_id(row.id, id)) {
		Ok(row) => Ok(row.published_at)
		Err(_) => Err(NoTime)
	}

	# Both ids have one day. A release is newer than a nightly. Two nightlies: the times when both are known and differ, else the sha text.
	same_day : Str, Str, List({ id : Str, published_at : U64 }) -> [Before, Same, After]
	same_day = |a, b, times| match (id_kind(a), id_kind(b)) {
		(Nightly, Release) => Before
		(Release, Nightly) => After
		(Release, _) => by_version(a, b)
		_ => match (published(a, times), published(b, times)) {
			(Ok(x), Ok(y)) if x != y => if x < y Before else After
			_ => match (nightly_key(a), nightly_key(b)) {
				(Ok(x), Ok(y)) => Text.compare(x.sha, y.sha)
				_ => Same
			}
		}
	}

	by_version : Str, Str -> [Before, Same, After]
	by_version = |a, b| match (Semver.parse(a), Semver.parse(b)) {
		(Ok(x), Ok(y)) => x.order_relative_to(y)
		_ => Same
	}

	NightlyKey : { date : List(U64), sha : Str }

	compare_dates : List(U64), List(U64) -> [Before, Same, After]
	compare_dates = |a, b| match (a, b) {
		([x, .. as xs], [y, .. as ys]) => if x < y Before else if x > y After else compare_dates(xs, ys)
		_ => Same
	}

	# `nightly-<year>-<month or name>-<day>-<sha>` as the date numbers and the sha text.
	nightly_key : Str -> Try(NightlyKey, [NotNightly])
	nightly_key = |id| match id.split_on("-") {
		["nightly", year, month, day, sha] if is_nightly(id) => {
			numbers = [U64.from_str(year), month_number(month), U64.from_str(day)]
			match numbers {
				[Ok(y), Ok(m), Ok(d)] => Ok({ date: [y, m, d], sha })
				_ => Err(NotNightly)
			}
		}
		_ => Err(NotNightly)
	}

	month_number : Str -> Try(U64, [NotMonth])
	month_number = |text| match U64.from_str(text) {
		Ok(n) => Ok(n)
		Err(_) => match months.find_first(|(name, _)| name == text) {
			Ok((_, n)) => Ok(n)
			Err(_) => Err(NotMonth)
		}
	}

	months : List((Str, U64))
	months = [("January", 1), ("February", 2), ("March", 3), ("April", 4), ("May", 5), ("June", 6), ("July", 7), ("August", 8), ("September", 9), ("October", 10), ("November", 11), ("December", 12)]

	is_release : Str -> Bool
	is_release = |text| match Semver.parse(text) {
		Ok(v) => v.pre_release().is_empty()
		Err(_) => Bool.False
	}
}
