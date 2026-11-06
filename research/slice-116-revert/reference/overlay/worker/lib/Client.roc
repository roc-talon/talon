## REFERENCE (private) of worker/lib/Client.roc, slice 116b.
import semver.Semver
import Problem
import Route

Client :: [].{

	is_write : Route.Id -> Bool
	is_write = |id| match id {
		PostCompat => Bool.True
		PostRelease => Bool.True
		PutToolchain(_) => Bool.True
		_ => Bool.False
	}

	# The version of `tln/<v>`, or Err when the agent is no tln agent or <v> is no semver.
	client_version : Try(Str, [NotFound]) -> Try(Semver, [NoClient])
	client_version = |ua| match ua {
		Ok(text) => {
			product = match text.split_on(" ") {
				[first, ..] => first
				[] => ""
			}
			if (product.starts_with("tln/")) Semver.parse(product.drop_prefix("tln/")).map_err(|_| NoClient) else Err(NoClient)
		}
		Err(NotFound) => Err(NoClient)
	}

	check : { user_agent : Try(Str, [NotFound]), write : Bool, min : Str, min_write : Str } -> Try({}, { problem : Problem, minimum : Str })
	check = |x| {
		v = match client_version(x.user_agent) {
			Ok(found) => found
			Err(NoClient) => return Ok({})
		}
		settings = if (x.write) [x.min, x.min_write] else [x.min]
		refused = settings.keep_oks(
			|text| match Semver.parse(text) {
				Ok(s) => match v.order_relative_to(s) {
					Before => Ok(s)
					_ => Err(NotRefused)
				}
				Err(_) => Err(NotRefused)
			},
		)
		largest = refused.fold(Err(None), |acc, s| match acc {
			Err(None) => Ok(s)
			Ok(best) => match s.order_relative_to(best) {
				After => Ok(s)
				_ => Ok(best)
			}
		})
		match largest {
			Err(None) => Ok({})
			Ok(s) => {
				minimum = s.to_str()
				Err({ problem: Problem.new(UnsupportedClient, "tln ${v.to_str()} is older than the minimum version ${minimum} that this registry accepts: update tln"), minimum })
			}
		}
	}

	refusal_json : { problem : Problem, minimum : Str } -> Str
	refusal_json = |x| "${x.problem.to_json().drop_suffix("}")},\"minimum\":${Json.to_str(x.minimum)}}"

	rate_key : Try(Str, [NotFound]) -> Str
	rate_key = |ip| match ip {
		Err(NotFound) => "unknown"
		Ok(text) => if (text.contains(":")) v6_key(text.with_ascii_lowercased()) else v4_key(text)
	}

	v4_parts : Str -> Try(List(U8), [Bad])
	v4_parts = |text| {
		parts = text.split_on(".")
		if parts.len() != 4 {
			Err(Bad)
		} else {
			parts.map_try(|p| U8.from_str(p).map_err(|_| Bad))
		}
	}

	v4_key : Str -> Str
	v4_key = |text| match v4_parts(text) {
		Ok(_) => text
		Err(_) => "unknown"
	}

	hex_group : Str -> Try(U16, [Bad])
	hex_group = |g| {
		bytes = g.to_utf8()
		if bytes.is_empty() or bytes.len() > 4 {
			Err(Bad)
		} else {
			bytes.fold(
				Ok(0),
				|acc, b| match acc {
					Err(Bad) => Err(Bad)
					Ok(n) =>
						if b >= '0' and b <= '9' {
							Ok(n * 16 + (b - '0').to_u16())
						} else if b >= 'a' and b <= 'f' {
							Ok(n * 16 + (b - 'a' + 10).to_u16())
						} else {
							Err(Bad)
						}
				},
			)
		}
	}

	groups_of : Str -> Try(List(U16), [Bad])
	groups_of = |text| if (text == "") Ok([]) else text.split_on(":").map_try(hex_group)

	# The 8 groups of an IPv6 text (lower case), the dotted tail turned into 2 groups.
	v6_groups : Str -> Try(List(U16), [Bad])
	v6_groups = |text| {
		halves = text.split_on("::")
		(left_text, right_text, compressed) = match halves {
			[one] => (one, "", Bool.False)
			[l, r] => (l, r, Bool.True)
			_ => return Err(Bad)
		}
		left = groups_of(left_text)?
		right_all = match right_text.split_on(":").last() {
			Ok(last) if last.contains(".") => {
				v4 = v4_parts(last)?
				head = right_text.drop_suffix(last)
				tail = match v4 {
					[a, b, c, d] => [a.to_u16() * 256 + b.to_u16(), c.to_u16() * 256 + d.to_u16()]
					_ => return Err(Bad)
				}
				groups_of(head.drop_suffix(":"))?.concat(tail)
			}
			_ => groups_of(right_text)?
		}
		total = left.len() + right_all.len()
		if compressed and total < 8 {
			Ok(left.concat(List.repeat(0, 8 - total)).concat(right_all))
		} else if !compressed and total == 8 {
			Ok(left.concat(right_all))
		} else {
			Err(Bad)
		}
	}

	hex_short : U16 -> Str
	hex_short = |n| {
		full = hex4(n)
		bytes = full.to_utf8()
		var $skip = 0.U64
		for c in bytes {
			if c == '0' and $skip < 3 and $skip == bytes.take_first($skip + 1).len() - 1 and bytes.take_first($skip + 1).all(|x| x == '0') {
				$skip = $skip + 1
			}
		}
		Str.from_utf8_lossy(bytes.drop_first($skip))
	}

	hex4 : U16 -> Str
	hex4 = |n| {
		digit = |d| if (d < 10) Str.from_utf8_lossy([d + '0']) else Str.from_utf8_lossy([d - 10 + 'a'])
		"${digit((n // 4096).to_u8_wrap())}${digit(((n // 256) % 16).to_u8_wrap())}${digit(((n // 16) % 16).to_u8_wrap())}${digit((n % 16).to_u8_wrap())}"
	}

	v6_key : Str -> Str
	v6_key = |text| match v6_groups(text) {
		Err(_) => "unknown"
		Ok(groups) =>
			if groups.take_first(6) == [0, 0, 0, 0, 0, 0xFFFF] {
				match groups {
					[_, _, _, _, _, _, hi, lo] => "${(hi // 256).to_str()}.${(hi % 256).to_str()}.${(lo // 256).to_str()}.${(lo % 256).to_str()}"
					_ => "unknown"
				}
			} else {
				"${Str.join_with(groups.take_first(4).map(hex_short), ":")}::/64"
			}
	}

	rate_problem : () -> Problem
	rate_problem = || Problem.new(RateLimited, "too many user hint requests from this address: try again in a minute")

	limit_retry_after : U64
	limit_retry_after = 60
}
