app [main!] { pkg: "../package/main.roc" }

import pkg.Hex

main! = |_args| Ok({})

# T-HEX1: encode gives two lowercase digits per byte
expect Hex.encode([0, 15, 255]) == "000fff"

# T-HEX2: decode accepts both cases
expect Hex.decode("00fFaB") == Ok([0, 255, 171])

# T-HEX3: odd length is an error
expect Hex.decode("abc") == Err(BadHex)

# T-HEX4: a non-hex digit is an error
expect Hex.decode("zz") == Err(BadHex)
