Problem :: { kind : Problem.Kind, detail : Str }.{

	is_eq : _

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

	new : Problem.Kind, Str -> Problem
	new = |kind, detail| Problem.{ kind, detail }

	type_uri : Problem.Kind -> Str
	type_uri = |kind| match kind {
		BadRequest => "/errors/bad-request"
		Unauthenticated => "/errors/unauthenticated"
		Forbidden => "/errors/forbidden"
		RepositoryChanged => "/errors/repository-changed"
		NotFound => "/errors/not-found"
		MethodNotAllowed => "/errors/method-not-allowed"
		LabelConflict => "/errors/label-conflict"
		IdCollision => "/errors/id-collision"
		UnsupportedClient => "/errors/unsupported-client"
		TooLarge => "/errors/too-large"
		UnsupportedMediaType => "/errors/unsupported-media-type"
		NotACandidate => "/errors/not-a-candidate"
		SuccessorMismatch => "/errors/successor-mismatch"
		SweepIncomplete => "/errors/sweep-incomplete"
		RateLimited => "/errors/rate-limited"
		Internal => "/errors/internal"
		Upstream => "/errors/upstream"
	}

	status : Problem.Kind -> U16
	status = |kind| match kind {
		BadRequest => 400
		Unauthenticated => 401
		Forbidden => 403
		RepositoryChanged => 403
		NotFound => 404
		MethodNotAllowed => 405
		LabelConflict => 409
		IdCollision => 409
		UnsupportedClient => 400
		TooLarge => 413
		UnsupportedMediaType => 415
		NotACandidate => 422
		SuccessorMismatch => 422
		SweepIncomplete => 422
		RateLimited => 429
		Internal => 500
		Upstream => 502
	}

	http_status : Problem -> U16
	http_status = |p| Problem.status(p.kind)

	title : Problem.Kind -> Str
	title = |kind| match kind {
		BadRequest => "Bad request"
		Unauthenticated => "Unauthenticated"
		Forbidden => "Forbidden"
		RepositoryChanged => "Repository changed"
		NotFound => "Not found"
		MethodNotAllowed => "Method not allowed"
		LabelConflict => "Label conflict"
		IdCollision => "Id collision"
		UnsupportedClient => "Unsupported client"
		TooLarge => "Too large"
		UnsupportedMediaType => "Unsupported media type"
		NotACandidate => "Not a candidate"
		SuccessorMismatch => "Successor mismatch"
		SweepIncomplete => "Sweep incomplete"
		RateLimited => "Rate limited"
		Internal => "Internal error"
		Upstream => "Upstream error"
	}

	to_json : Problem -> Str
	to_json = |p| Json.to_str({ type: Problem.type_uri(p.kind), title: Problem.title(p.kind), status: Problem.status(p.kind), detail: p.detail })
}
