app [main!] { pkg: "../package/main.roc" }

import pkg.Pair

main! = |_args| Ok({})

# T-PAIR1: name and value of a good pair
expect {
	p = Pair.parse("port=8080")?
	p.name() == "port" and p.value() == 8080
}

# T-PAIR2: a missing value is an error
expect Pair.parse("port=").is_err()
