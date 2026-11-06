app [main!] { base58: "https://github.com/Karakatiza666/roc-base58/releases/download/0.1.0/BgUuQGqWY94NikfEx4rBkWkgxYhngMim3ZEnD8wpM4NS.tar.zst", lib: "../../worker/lib/main.roc", records: "../../packages/records/main.roc", semver: "https://github.com/Karakatiza666/roc-semver/releases/download/0.2.0/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i.tar.zst" }

import lib.Toolchains

one = { tag: "n", target: "linux_arm64", asset_name: "a\"b", sha256: "cb", published_at: 1792594866000, log_index: 7 }

x = Toolchains.put_body([one])

expect {
	dbg x
	Bool.True
}

main! = |_args| Ok({})
