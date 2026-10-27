import lib.Clock

ClockTest :: [].{}

# R-EV18: TALON_NOW is an RFC 3339 UTC time with a Z. It gives seconds since the epoch.
# Other text is BadTime.
expect {
	parsed = [
		Clock.parse_utc("2026-10-15T12:00:00Z"),
		Clock.parse_utc("1970-01-01T00:00:00Z"),
		Clock.parse_utc("2000-01-01T00:00:00Z"),
		Clock.parse_utc("2024-02-29T00:00:00Z"),
		Clock.parse_utc("2026-12-31T23:59:59Z"),
		Clock.parse_utc(""),
		Clock.parse_utc("yesterday"),
		Clock.parse_utc("2026-13-01T00:00:00Z"),
		Clock.parse_utc("2026-02-30T00:00:00Z"),
		Clock.parse_utc("2026-10-15"),
		Clock.parse_utc("2026-10-15T12:00:00"),
	]
	dbg parsed
	parsed == [
		Ok(1792065600),
		Ok(0),
		Ok(946684800),
		Ok(1709164800),
		Ok(1798761599),
		Err(BadTime),
		Err(BadTime),
		Err(BadTime),
		Err(BadTime),
		Err(BadTime),
		Err(BadTime),
	]
}

# R-EV22: the time for a decision about age is TALON_NOW when it is set, else the real time.
expect {
	times = [
		Clock.now({ talon_now: Ok("2026-10-15T12:00:00Z"), real: 1800000000 }),
		Clock.now({ talon_now: Err(NotSet), real: 1800000000 }),
		Clock.now({ talon_now: Ok("garbage"), real: 1800000000 }),
	]
	dbg times
	times == [Ok(1792065600), Ok(1800000000), Err(BadTime("garbage"))]
}
