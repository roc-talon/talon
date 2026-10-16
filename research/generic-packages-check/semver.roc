app [main!] { semver: "https://github.com/Karakatiza666/roc-semver/releases/download/0.1.0/KFKmXaroJeaPkQmAaqm83fTP9yhnEkTQwE97a5BtFSX.tar.zst" }

import semver.Semver
import semver.VersionReq

main! = |_args| Ok({})

expect {
	version = Semver.parse("1.4.0")?
	req = VersionReq.parse("^1.2")?
	req.matches(version)
}

expect Semver.new(1, 0, 0).order_relative_to(Semver.new(1, 2, 0)) == Before

# What a bare version matches
expect {
	req = VersionReq.parse("1.2.3")?
	[req.matches(Semver.parse("1.2.4")?), req.matches(Semver.parse("1.3.0")?), req.matches(Semver.parse("2.0.0")?)] == [Bool.False, Bool.False, Bool.False] and req.matches(Semver.parse("1.2.3")?)
}
