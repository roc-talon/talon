import Problem

Route :: [].{
	Id : [PostClosure]
	Input : { method : Str, segments : List(Str), content_type : Try(Str, [NotFound]), has_body : Bool }
	Decision : [Handle(Route.Id), Refuse(Problem), NotAllowed(Problem, List(Str))]

	split_semi : Str -> List(Str)
	split_semi = |s| {
		var $parts = []
		var $cur = []
		var $q = Bool.False
		for b in s.to_utf8() {
			if b == 34 {
				$q = !$q
				$cur = $cur.append(b)
			} else if b == 59 and !$q {
				$parts = $parts.append(Str.from_utf8_lossy($cur))
				$cur = []
			} else {
				$cur = $cur.append(b)
			}
		}
		$parts.append(Str.from_utf8_lossy($cur))
	}

	param_ok : Str -> Bool
	param_ok = |p| match p.split_first("=") {
		Ok({ before, after }) => if before.trim().with_ascii_lowercased() == "charset" {
			v = after.trim()
			unq = if (v.starts_with("\"") and v.ends_with("\"") and v.count_utf8_bytes() >= 2) v.drop_prefix("\"").drop_suffix("\"") else v
			unq.with_ascii_lowercased() == "utf-8"
		} else Bool.True
		Err(_) => Bool.True
	}

	media_ok : Str -> Bool
	media_ok = |ct| match Route.split_semi(ct) {
		[first, .. as params] => first.trim().with_ascii_lowercased() == "application/json" and params.all(Route.param_ok)
		[] => Bool.False
	}

	decide : Route.Input -> Route.Decision
	decide = |input| {
		path = "/${Str.join_with(input.segments, "/")}"
		if input.segments != ["v1", "closure"] {
			Refuse(Problem.new(NotFound, "no route for ${input.method} ${path}"))
		} else if input.method != "POST" {
			NotAllowed(Problem.new(MethodNotAllowed, "${input.method} is not allowed on ${path}"), ["POST"])
		} else if input.has_body {
			match input.content_type {
				Err(NotFound) => Refuse(Problem.new(UnsupportedMediaType, "the request body must be application/json, but the request has no Content-Type"))
				Ok(ct) => if (Route.media_ok(ct)) Handle(PostClosure) else Refuse(Problem.new(UnsupportedMediaType, "the request body must be application/json, got ${ct}"))
			}
		} else Handle(PostClosure)
	}
}
