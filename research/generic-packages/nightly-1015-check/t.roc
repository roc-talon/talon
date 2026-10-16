app [main!] { pkg: "../layout-probe/package/main.roc" }

import pkg.Hex

main! = |_args| Ok({})

expect Hex.encode([238]) == "ee"
expect Hex.decode("ee") == Ok([238])
expect Hex.decode("e0") == Ok([224])
expect Hex.decode("0e") == Ok([14])
expect Hex.decode("ff") == Ok([255])
expect Hex.decode("dd") == Ok([221])
expect Hex.decode(Hex.encode([238])) == Ok([238])
