## The real `Fx` as a package (slice 223): the compat bot (`bot/main.roc`) shares it with `tln` (`cli/main.roc`).
## An app cannot import a file outside its own directory, but it can use a package. This file is the package header only: its source root is `cli/`, so it exposes `RealFx` and the files that `RealFx` imports (`RealBase`, `RealDb`, `RealFiles`, `RealJobs`, `RealLocks`) stay here, once.
package
	[RealFx]
	{
		http: "https://github.com/roc-lang/http/releases/download/1.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
		lib: "lib/main.roc",
		pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.26.0/GddgvsGjiNXrHFW6au5i5dUDbTs8FinQdrgE2Gqmw53t.tar.zst",
	}
