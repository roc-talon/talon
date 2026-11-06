## The problem details of an error answer (Registry 4.2, R-AP21). The client reads them, and the Worker can write them. Pure.
## `worker/lib/Problem.roc` (slice 101) holds its own copy for now. A later slice moves the Worker to this module.
Problem :: [].{

	## The 17 types of R-AP21, in the order of the table.
	Kind : [
		BadRequest,
		Unauthenticated,
		Forbidden,
		RepositoryChanged,
		NotFound,
		MethodNotAllowed,
		LabelConflict,
		IdCollision,
		UnsupportedClient,
		TooLarge,
		UnsupportedMediaType,
		NotACandidate,
		SuccessorMismatch,
		SweepIncomplete,
		RateLimited,
		Internal,
		Upstream,
	]

	## The members of R-AP21 that only some types have: `issues_url` (repository-changed, R-TP12), `minimum` (unsupported-client, R-AP45), `field` and `limit` (too-large, R-AP46).
	Extra : [None, IssuesUrl(Str), Minimum(Str), Limit({ field : Str, limit : U64 })]

	## The body of an error answer: `type_text` (the `type` as read, also a type that is not in the table: R-AP52), `title`, `status`, `detail`, and the extra member. `kind_from_uri(type_text)` gives the kind.
	Body : { type_text : Str, title : Str, status : U16, detail : Str, extra : Problem.Extra }

	## `/errors/<kebab name>` (R-AP21).
	type_uri : Problem.Kind -> Str
	type_uri = |k| row(k).1

	## The table of R-AP21: kind, type, status.
	row : Problem.Kind -> (Problem.Kind, Str, U16)
	row = |k| match k {
		BadRequest => (k, "/errors/bad-request", 400)
		Unauthenticated => (k, "/errors/unauthenticated", 401)
		Forbidden => (k, "/errors/forbidden", 403)
		RepositoryChanged => (k, "/errors/repository-changed", 403)
		NotFound => (k, "/errors/not-found", 404)
		MethodNotAllowed => (k, "/errors/method-not-allowed", 405)
		LabelConflict => (k, "/errors/label-conflict", 409)
		IdCollision => (k, "/errors/id-collision", 409)
		UnsupportedClient => (k, "/errors/unsupported-client", 400)
		TooLarge => (k, "/errors/too-large", 413)
		UnsupportedMediaType => (k, "/errors/unsupported-media-type", 415)
		NotACandidate => (k, "/errors/not-a-candidate", 422)
		SuccessorMismatch => (k, "/errors/successor-mismatch", 422)
		SweepIncomplete => (k, "/errors/sweep-incomplete", 422)
		RateLimited => (k, "/errors/rate-limited", 429)
		Internal => (k, "/errors/internal", 500)
		Upstream => (k, "/errors/upstream", 502)
	}

	## The kind of a `type` value. An unknown `type` is `Err(UnknownType)`: a client must not crash on a type of a later registry.
	kind_from_uri : Str -> Try(Problem.Kind, [UnknownType])
	kind_from_uri = |u| {
		kinds : List(Problem.Kind)
		kinds = [BadRequest, Unauthenticated, Forbidden, RepositoryChanged, NotFound, MethodNotAllowed, LabelConflict, IdCollision, UnsupportedClient, TooLarge, UnsupportedMediaType, NotACandidate, SuccessorMismatch, SweepIncomplete, RateLimited, Internal, Upstream]
		kinds.find_first(|k| type_uri(k) == u).map_err(|_| UnknownType)
	}

	## The status of the table of R-AP21.
	status : Problem.Kind -> U16
	status = |k| row(k).2

	## A body with no `type`, no `status` or that is not JSON is `BadJson` (R-AP52). An unknown `type` is kept.
	## The wire form: the members that only some types have are left out when absent.
	Wire : {
		type : Str,
		title : Try(Str, [Missing]),
		status : U16,
		detail : Try(Str, [Missing]),
		issues_url : Try(Str, [Missing]),
		minimum : Try(Str, [Missing]),
		field : Try(Str, [Missing]),
		limit : Try(U64, [Missing]),
	}

	## R-AP74 row 2, RFC 9457 3.1 (Design Q250): `type` and `status` are strict. Each other member is read as missing when it is `null` or has a wrong type.
	StrictWire : { type : Str, status : U16 }

	decode : Str -> Try(Problem.Body, [BadJson(Str)])
	decode = |text| {
		strict : Try(Problem.StrictWire, _)
		strict = Json.parse(text)
		str_title : Try({ title : Try(Str, [Missing]) }, _)
		str_title = Json.parse(text)
		str_detail : Try({ detail : Try(Str, [Missing]) }, _)
		str_detail = Json.parse(text)
		str_url : Try({ issues_url : Try(Str, [Missing]) }, _)
		str_url = Json.parse(text)
		str_min : Try({ minimum : Try(Str, [Missing]) }, _)
		str_min = Json.parse(text)
		str_field : Try({ field : Try(Str, [Missing]) }, _)
		str_field = Json.parse(text)
		num_limit : Try({ limit : Try(U64, [Missing]) }, _)
		num_limit = Json.parse(text)
		match strict {
			Err(e) => Err(BadJson(Str.inspect(e)))
			Ok(w) => {
				title = match str_title {
					Ok(v) => v.title
					Err(_) => Err(Missing)
				}
				detail = match str_detail {
					Ok(v) => v.detail
					Err(_) => Err(Missing)
				}
				url = match str_url {
					Ok(v) => v.issues_url
					Err(_) => Err(Missing)
				}
				min = match str_min {
					Ok(v) => v.minimum
					Err(_) => Err(Missing)
				}
				field = match str_field {
					Ok(v) => v.field
					Err(_) => Err(Missing)
				}
				limit = match num_limit {
					Ok(v) => v.limit
					Err(_) => Err(Missing)
				}
				extra = match (url, min, field, limit) {
					(Ok(u), _, _, _) => IssuesUrl(u)
					(_, Ok(m), _, _) => Minimum(m)
					(_, _, Ok(f), Ok(l)) => Limit({ field: f, limit: l })
					_ => None
				}
				Ok({ type_text: w.type, title: title ?? "", status: w.status, detail: detail ?? "", extra })
			}
		}
	}

	encode : Problem.Body -> Str
	encode = |body| {
		base : Problem.Wire
		base = { type: body.type_text, title: Ok(body.title), status: body.status, detail: Ok(body.detail), issues_url: Err(Missing), minimum: Err(Missing), field: Err(Missing), limit: Err(Missing) }
		Json.to_str(
			match body.extra {
				None => base
				IssuesUrl(url) => { ..base, issues_url: Ok(url) }
				Minimum(min) => { ..base, minimum: Ok(min) }
				Limit({ field, limit }) => { ..base, field: Ok(field), limit: Ok(limit) }
			},
		)
	}
}
