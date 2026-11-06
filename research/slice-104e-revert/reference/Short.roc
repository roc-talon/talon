import Nullable

## Private reference of slice 104e (not for the code agent).
Short :: [].{

	State : [Active, Missing, Moved]
	Item : { name : Str, first_log_index : U64, state : Short.State, moved_from : Try(Str, [None]) }
	Entry : { short : Str, matches : List(Short.Item) }
	Matches : { matches : List(Short.Entry) }
	Hit : { name : Str, first_log_index : U64, state : Short.State }
	Packages : { found : List(Short.Hit) }

	ItemWire : { name : Str, first_log_index : U64, state : Str, moved_from : Try(Nullable(Str), [Missing]) }
	EntryWire : { short : Str, matches : List(Short.ItemWire) }
	MatchesWire : { matches : List(Short.EntryWire) }
	HitWire : { name : Str, first_log_index : U64, state : Str }

	state_text : Short.State -> Str
	state_text = |s| match s {
		Active => "active"
		Missing => "missing"
		Moved => "moved"
	}

	state_of : Str -> Try(Short.State, [BadJson(Str)])
	state_of = |t| match t {
		"active" => Ok(Active)
		"missing" => Ok(Missing)
		"moved" => Ok(Moved)
		other => Err(BadJson("unknown state ${other}"))
	}

	list_of : List(Str) -> Str
	list_of = |items| "[${Str.join_with(items, ",")}]"

	item_text : Short.Item -> Str
	item_text = |i| {
		from = match i.moved_from {
			Ok(old) => ",\"moved_from\":${Json.to_str(old)}"
			Err(None) => ""
		}
		"{\"first_log_index\":${i.first_log_index.to_str()}${from},\"name\":${Json.to_str(i.name)},\"state\":${Json.to_str(state_text(i.state))}}"
	}

	encode_matches : Short.Matches -> Str
	encode_matches = |m| "{\"matches\":${list_of(m.matches.map(|e| "{\"matches\":${list_of(e.matches.map(item_text))},\"short\":${Json.to_str(e.short)}}"))}}"

	decode_matches : Str -> Try(Short.Matches, [BadJson(Str)])
	decode_matches = |text| {
		parsed : Try(Short.MatchesWire, _)
		parsed = Json.parse(text)
		match parsed {
			Err(e) => Err(BadJson(Str.inspect(e)))
			Ok(w) => {
				entries = w.matches.map_try(
					|e| {
						items = e.matches.map_try(|i| Ok({ name: i.name, first_log_index: i.first_log_index, state: state_of(i.state)?, moved_from: Nullable.read_opt(i.moved_from) }))?
						Ok({ short: e.short, matches: items })
					},
				)?
				Ok({ matches: entries })
			}
		}
	}

	encode_packages : Short.Packages -> Str
	encode_packages = |p| "{\"packages\":${list_of(p.found.map(|h| "{\"first_log_index\":${h.first_log_index.to_str()},\"name\":${Json.to_str(h.name)},\"state\":${Json.to_str(state_text(h.state))}}"))}}"

	decode_packages : Str -> Try(Short.Packages, [BadJson(Str)])
	decode_packages = |text| {
		parsed : Try(Dict(Str, List(Short.HitWire)), _)
		parsed = Json.parse(text)
		match parsed {
			Err(e) => Err(BadJson(Str.inspect(e)))
			Ok(d) => match d.get("packages") {
				Err(_) => Err(BadJson("missing packages"))
				Ok(hits) => Ok({ found: hits.map_try(|h| Ok({ name: h.name, first_log_index: h.first_log_index, state: state_of(h.state)? }))? })
			}
		}
	}
}
