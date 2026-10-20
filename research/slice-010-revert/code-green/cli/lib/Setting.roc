## The priority of a setting (CLI 6.1, R-LY4, R-EV1): a flag has priority over an environment variable, a variable over the
## `talon.toml` of the project, and the `talon.toml` over `config.toml` (the user settings).
Setting :: [].{

	## The first value that is set, in the order: `flag`, `env`, `project`, `user`. `Err(Unset)` when none is set.
	pick : { flag : Try(a, [Unset]), env : Try(a, [Unset]), project : Try(a, [Unset]), user : Try(a, [Unset]) } -> Try(a, [Unset])
	pick = |layers| match layers.flag {
		Ok(value) => Ok(value)
		Err(Unset) => match layers.env {
			Ok(value) => Ok(value)
			Err(Unset) => match layers.project {
				Ok(value) => Ok(value)
				Err(Unset) => layers.user
			}
		}
	}
}
