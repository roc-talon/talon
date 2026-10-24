import Fail
import Fx

## The time of a run (R-EV18, R-EV22). `Fx.clock!` gives the real time. `TALON_NOW` fixes the time for
## the decisions about the age of data. Locks and temp files use the real time (R-EV22).
Clock :: [].{

	## An RFC 3339 UTC time with a `Z` and whole seconds, for example `2026-10-15T12:00:00Z`,
	## as seconds since the Unix epoch.
	parse_utc : Str -> Try(U64, [BadTime])
	parse_utc = |text| {
		bytes = text.to_utf8()
		# `YYYY-MM-DDTHH:MM:SSZ`: 20 bytes, with the fixed marks at these places.
		marks_ok = bytes.len() == 20
			and bytes.sublist({ start: 4, len: 1 }) == [45]
				and bytes.sublist({ start: 7, len: 1 }) == [45]
					and bytes.sublist({ start: 10, len: 1 }) == [84]
						and bytes.sublist({ start: 13, len: 1 }) == [58]
							and bytes.sublist({ start: 16, len: 1 }) == [58]
								and bytes.sublist({ start: 19, len: 1 }) == [90]
		if marks_ok {
			field = |start, len| number(bytes.sublist({ start, len }))
			match (field(0, 4), field(5, 2), field(8, 2), field(11, 2), field(14, 2), field(17, 2)) {
				(Ok(y), Ok(mo), Ok(d), Ok(h), Ok(mi), Ok(sec)) =>
					if y >= 1970 and mo >= 1 and mo <= 12 and d >= 1 and d <= days_in_month(y, mo) and h < 24 and mi < 60 and sec < 60 {
						Ok((days_since_epoch(y, mo, d) * 86400 + h * 3600 + mi * 60 + sec).to_u64_wrap())
					} else {
						Err(BadTime)
					}
				_ => Err(BadTime)
			}
		} else {
			Err(BadTime)
		}
	}

	## The reverse of `parse_utc` (slice 003): seconds since the epoch as `YYYY-MM-DDTHH:MM:SSZ`. `1792152000` is `2026-10-16T12:00:00Z`.
	## It is for the times that a message shows (R-DI12, R-DI13).
	format_utc : U64 -> Str
	format_utc = |seconds| {
		secs = seconds.to_i64_wrap()
		date = civil_from_days(secs // 86400)
		in_day = secs % 86400
		"${pad(date.year, 4)}-${pad(date.month, 2)}-${pad(date.day, 2)}T${pad(in_day // 3600, 2)}:${pad(in_day // 60 % 60, 2)}:${pad(in_day % 60, 2)}Z"
	}

	## `TALON_NOW` when it is set, else the real time. A `TALON_NOW` that does not parse is `BadTime`
	## with its text (a usage failure, exit 2, Q5: the command that calls `now` makes it).
	now : { talon_now : Try(Str, [NotSet]), real : U64 } -> Try(U64, [BadTime(Str)])
	now = |facts| match facts.talon_now {
		Ok(text) => Clock.parse_utc(text).map_err(|BadTime| BadTime(text))
		Err(NotSet) => Ok(facts.real)
	}

	## R-EV22: the time of a run for a command. One `Fx.clock!` call, also when `TALON_NOW` is set. `env` is the environment (`Fx.env_all!`). A bad `TALON_NOW` is a failure of kind `Usage` (exit 2, Q5): `TALON_NOW is not a UTC time: <text>`.
	now! : Fx, List((Str, Str)) => Try(U64, Fail)
	now! = |fx, env| {
		talon_now = match env.find_first(|(name, _)| name == "TALON_NOW") {
			Ok((_, text)) => Ok(text)
			Err(_) => Err(NotSet)
		}
		match Clock.now({ talon_now, real: fx.clock!() }) {
			Ok(time) => Ok(time)
			Err(BadTime(text)) => Err(Fail.new(Usage, "TALON_NOW is not a UTC time: ${text}"))
		}
	}
}

# Decimal digits only. A sign or a space is not a digit.
number : List(U8) -> Try(I64, [BadTime])
number = |digits| if digits.all(|b| b >= 48 and b <= 57) {
	Ok(digits.fold(0, |n, b| n * 10 + (b - 48).to_i64()))
} else {
	Err(BadTime)
}

days_in_month : I64, I64 -> I64
days_in_month = |year, month| match month {
	2 => if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) 29 else 28
	4 | 6 | 9 | 11 => 30
	_ => 31
}

# Days from 1970-01-01 to a valid date at or after it (the civil-from-days method of H. Hinnant).
days_since_epoch : I64, I64, I64 -> I64
days_since_epoch = |year, month, day| {
	y = if month <= 2 year - 1 else year
	era = y // 400
	year_of_era = y - era * 400
	shifted = if month > 2 month - 3 else month + 9
	day_of_year = (153 * shifted + 2) // 5 + day - 1
	day_of_era = year_of_era * 365 + year_of_era // 4 - year_of_era // 100 + day_of_year
	era * 146097 + day_of_era - 719468
}

# The reverse of `days_since_epoch` (the civil-from-days method of H. Hinnant).
civil_from_days : I64 -> { year : I64, month : I64, day : I64 }
civil_from_days = |days| {
	z = days + 719468
	era = z // 146097
	day_of_era = z - era * 146097
	year_of_era = (day_of_era - day_of_era // 1460 + day_of_era // 36524 - day_of_era // 146096) // 365
	day_of_year = day_of_era - (365 * year_of_era + year_of_era // 4 - year_of_era // 100)
	shifted = (5 * day_of_year + 2) // 153
	month = if shifted < 10 shifted + 3 else shifted - 9
	{
		year: year_of_era + era * 400 + (if month <= 2 1 else 0),
		month,
		day: day_of_year - (153 * shifted + 2) // 5 + 1,
	}
}

# A number with leading zeros, at least `width` digits.
pad : I64, U64 -> Str
pad = |n, width| {
	text = n.to_str()
	size = text.to_utf8().len()
	if size >= width text else "${"0".repeat(width - size)}${text}"
}
