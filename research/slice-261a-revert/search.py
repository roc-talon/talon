# A replica (Python ints) of package/Ed25519.roc with the mutant "non-point-a-valid": a y with no x gives x0 as if it were a root.
# Looks for an off-curve key A whose [k](-A) (the Straus loop with s = 0) has an encoding that does not depend on k.
import random, hashlib, collections
p = 2**255 - 19
d = (-121665 * pow(121666, p - 2, p)) % p
d2 = 2 * d % p
sqrtm1 = pow(2, (p - 1) // 4, p)
def decode_mut(y, sign):
    u = (y * y - 1) % p; v = (d * y * y + 1) % p
    x0 = u * pow(v, 3, p) * pow(u * pow(v, 7, p), (p - 5) // 8, p) % p
    vxx = v * x0 * x0 % p
    on = vxx == u or vxx == (-u) % p
    if vxx == (-u) % p and vxx != u: x0 = x0 * sqrtm1 % p
    x = (p - x0) % p if (x0 & 1) != sign else x0
    return (x, y, 1, x * y % p), on
def add(P, Q):
    a = (P[1] - P[0]) * (Q[1] - Q[0]) % p; b = (P[1] + P[0]) * (Q[1] + Q[0]) % p
    c = P[3] * d2 * Q[3] % p; zz = P[2] * Q[2] % p; dd = 2 * zz % p
    e = (b - a) % p; f = (dd - c) % p; g = (dd + c) % p; h = (b + a) % p
    return (e * f % p, g * h % p, f * g % p, e * h % p)
def dbl(P):
    a = P[0] * P[0] % p; b = P[1] * P[1] % p; zz = P[2] * P[2] % p; c = 2 * zz % p
    h = (a + b) % p; e = (h - (P[0] + P[1]) ** 2) % p; g = (a - b) % p; f = (c + g) % p
    return (e * f % p, g * h % p, f * g % p, e * h % p)
def enc(P):
    zi = pow(P[2], p - 2, p); x = P[0] * zi % p; y = P[1] * zi % p
    return (y | ((x & 1) << 255)).to_bytes(32, "little")
def mul_k(k, P):  # s = 0: only P is added
    acc = (0, 1, 1, 0)
    for i in range(252, -1, -1):
        acc = dbl(acc)
        if (k >> i) & 1: acc = add(acc, P)
    return acc
random.seed(1)
for y in range(2, 400):
    for sign in (0, 1):
        A, on = decode_mut(y, sign)
        if on: continue
        negA = ((p - A[0]) % p, A[1], A[2], (p - A[3]) % p)
        outs = collections.Counter(enc(mul_k(random.getrandbits(253), negA)) for _ in range(12))
        top, n = outs.most_common(1)[0]
        if n >= 4: print("y", y, "sign", sign, "top", top.hex(), n)
print("done")
