# Ids and texts for the slice 110 tests, with python only (hashlib), not with Roc: name_id (R-IK2), nightly id (R-IK4), base58, version keys (R-IK5).
import hashlib, datetime
A = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
def b58(b):
    n = int.from_bytes(b, 'big'); s = ''
    while n: n, r = divmod(n, 58); s = A[r] + s
    return '1' * (len(b) - len(b.lstrip(b'\0'))) + s
def name_id(kind, b):
    v = int.from_bytes(hashlib.sha256(bytes([kind]) + b).digest()[:8], 'big')
    return v - (1 << 64) if v >= 1 << 63 else v
def nightly_id(tag):
    _, y, m, d, sha = tag.split('-')
    days = (datetime.date(int(y), int(m), int(d)) - datetime.date(1970, 1, 1)).days
    return days * (1 << 28) + int(sha, 16)
def key(M, m, p): return (M << 48) | (m << 32) | (p << 16) | 0xFFFF
def stored(k): return k - (1 << 63) if k < (1 << 63) else k - (1 << 63)
def stored_signed(k):  # key XOR 2^63 as a signed I64
    v = k ^ (1 << 63)
    return v - (1 << 64) if v >= 1 << 63 else v
