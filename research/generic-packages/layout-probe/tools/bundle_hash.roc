# Prints base58(BLAKE3(bundle.tar.zst)). run.sh copies this file and the
# bundle into one directory, because the embed path is fixed.
import "bundle.tar.zst" as data : List(U8)

alphabet : List(U8)
alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".to_utf8()

# Divide a big-endian base-256 number by 58: gives the quotient and the remainder.
div58 : List(U8) -> { q : List(U8), r : U64 }
div58 = |num| {
	var $q = []
	var $r = 0.U64
	for b in num {
		acc = $r * 256 + b.to_u64()
		d = acc // 58
		if !($q.is_empty() and d == 0) {
			$q = $q.append(d.to_u8_wrap())
		}
		$r = acc % 58
	}
	{ q: $q, r: $r }
}

base58 : List(U8) -> Str
base58 = |bytes| {
	var $zeros = 0
	for b in bytes {
		if b != 0 {
			break
		}
		$zeros = $zeros + 1
	}
	zeros = $zeros
	var $num = bytes.drop_first(zeros)
	var $out = []
	while !$num.is_empty() {
		step = div58($num)
		$out = $out.append(alphabet.get(step.r) ?? '?')
		$num = step.q
	}
	ones = List.repeat('1', zeros)
	Str.from_utf8(ones.concat($out.rev())) ?? ""
}

main! = |_args| {
	echo!("${base58(Crypto.BLAKE3.hash(data).to_bytes())}\n")
	Ok({})
}
