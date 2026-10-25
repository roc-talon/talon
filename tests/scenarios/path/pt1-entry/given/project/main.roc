app [main!] {
	pf: platform "https://github.com/acme/pf/releases/download/0.2.0/4utYEGSc7npGGN2p7BZFCDEAaHhPRKNo6K9Z191TRVnw.tar.zst",
	json: "https://github.com/acme/json/releases/download/2.1.0/76Vvu267CgMUytVQiAX5vtQrFYw4Y9YBE7hiHM3ZPycS.tar.zst",
	lib: "../shared/lib/main.roc",
	odd: "https://example.com/pkg/{v}/x.tar.zst",
}

main! = |_args| Ok({})
