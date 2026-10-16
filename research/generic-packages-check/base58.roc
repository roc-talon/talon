app [main!] {
	b58: "https://github.com/Karakatiza666/roc-base58/releases/download/0.1.0/BgUuQGqWY94NikfEx4rBkWkgxYhngMim3ZEnD8wpM4NS.tar.zst",
}

import b58.Base58

main! = |_args| Ok({})

expect Base58.encode([0, 0, 1]) == "112"
expect Base58.decode("2g") == Ok([0x61])
expect Base58.decode("2l") == Err(InvalidChar(1))
