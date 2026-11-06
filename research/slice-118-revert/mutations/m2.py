import sys
p=sys.argv[1]+"/WebhookRoutes.roc"
s=open(p).read()
old='if (!WebCrypto.timing_safe_equal!(WebCrypto.hmac_sha256(key, bytes), sig))'
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'if (WebCrypto.hmac_sha256(key, bytes) != sig)',1))
