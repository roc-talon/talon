# For the mutant "r-first-31-bytes": the zero key A (order 4), S = 0, R = 31 zero bytes then 0x80. Then -[k]A is A (its bytes are 32 zeros)
# when k mod 4 = 3, and the first 31 bytes match R. Find the smallest one-byte message with k mod 4 = 3.
import hashlib
L = 2**252 + 27742317777372353535851937790883648493
A = bytes(32); R = bytes(31) + b"\x80"
for m in range(256):
    k = int.from_bytes(hashlib.sha512(R + A + bytes([m])).digest(), "little") % L
    if k % 4 == 3: print("message", m, "k mod 4", k % 4); break
