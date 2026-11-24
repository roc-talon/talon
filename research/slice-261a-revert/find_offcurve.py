# For the mutant "non-point-a-valid": find an off-curve key A whose mutant point P = (x0, y) has x0^2 = -y^2. Then 2P has y = 0 under the
# doubling law (it does not use d), every even multiple has T = 0, so each addition of the Straus loop is exact on the curve of P, and
# [k](-P) depends only on k mod 8. With S = 0 and R the encoding for k mod 8 = 0 (the identity), a message with k mod 8 = 0 verifies under
# the mutant. The original rejects A (no x). Uses the replica of search.py.
import hashlib
from search_lib import *
def sqrt(a):
    a %= p
    x = pow(a, (p + 3) // 8, p)
    if x * x % p == a: return x
    x = x * sqrtm1 % p
    return x if x * x % p == a else None
L = 2**252 + 27742317777372353535851937790883648493
found = []
for c in (sqrtm1, p - sqrtm1):
    # c d Y^2 + (c - 1) Y + 1 = 0
    A2, B1, C0 = c * d % p, (c - 1) % p, 1
    disc = (B1 * B1 - 4 * A2 * C0) % p
    r = sqrt(disc)
    if r is None: continue
    for Y in ((-B1 + r) * pow(2 * A2, p - 2, p) % p, (-B1 - r) * pow(2 * A2, p - 2, p) % p):
        y = sqrt(Y)
        if y is None: continue
        for yy in (y, p - y):
            for sign in (0, 1):
                P, on = decode_mut(yy, sign)
                if on: continue
                if (P[0] * P[0] + yy * yy) % p == 0: found.append((yy, sign, P))
print("candidates", len(found))
yy, sign, P = found[0]
Abytes = (yy | (sign << 255)).to_bytes(32, "little")
negP = ((p - P[0]) % p, P[1], P[2], (p - P[3]) % p)
encs = set(enc(mul_k(k, negP)).hex() for k in range(8))
print("distinct results for k = 0..7:", len(encs))
R = enc(mul_k(8, negP))
print("R for k = 8:", R.hex())
for m in range(256):
    k = int.from_bytes(hashlib.sha512(R + Abytes + bytes([m])).digest(), "little") % L
    if enc(mul_k(k, negP)) == R:
        print("A", Abytes.hex()); print("R", R.hex()); print("message", m, "k mod 8", k % 8); break
