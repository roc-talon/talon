## Private reference of slice 247 (test agent). Not for the code agent (TW18).
Move :: [].{

	Request : { name : Str }

	Check : [Index, Kind, Exposes(List(Str)), Chain]

	encode_request : Move.Request -> Str
	encode_request = |r| Json.to_str(r)

	decode_request : Str -> Try(Move.Request, [BadJson(Str)])
	decode_request = |text| {
		parsed : Try(Move.Request, _)
		parsed = Json.parse(text)
		parsed.map_err(|e| BadJson(Str.inspect(e)))
	}

	detail : Str, Move.Check -> Str
	detail = |name, check| match check {
		Index => "the successor ${name} fails the Index check: it needs a github.com name with a repos row in the state active and at least one release that is a candidate"
		Kind => "the successor ${name} fails the Kind check: the newest candidate of the successor is not the same kind as the newest release of the old name"
		Exposes(missing) => "the successor ${name} fails the exposes check: the newest candidate of the successor does not expose the modules ${Str.join_with(missing, ", ")}"
		Chain => "the successor ${name} fails the Chain check: the successor chain from the successor comes back to the old name"
	}

	check_of : Str -> Try({ name : Str, check : Move.Check }, [NotACheck])
	check_of = |text| {
		rest = text.drop_prefix("the successor ")
		if rest == text {
			return Err(NotACheck)
		}
		match rest.split_first(" fails the ") {
			Ok({ before: name, after }) => {
				exposes_head = "exposes check: the newest candidate of the successor does not expose the modules "
				if after == "Index check: it needs a github.com name with a repos row in the state active and at least one release that is a candidate" {
					Ok({ name, check: Index })
				} else if after == "Kind check: the newest candidate of the successor is not the same kind as the newest release of the old name" {
					Ok({ name, check: Kind })
				} else if after == "Chain check: the successor chain from the successor comes back to the old name" {
					Ok({ name, check: Chain })
				} else if after.starts_with(exposes_head) and after.drop_prefix(exposes_head) != "" {
					Ok({ name, check: Exposes(after.drop_prefix(exposes_head).split_on(", ")) })
				} else {
					Err(NotACheck)
				}
			}
			Err(_) => Err(NotACheck)
		}
	}
}
