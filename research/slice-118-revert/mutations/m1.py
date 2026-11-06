import sys
p=sys.argv[1]+"/WebhookRoutes.roc"
s=open(p).read()
old='WebCrypto.hmac_sha256(key, bytes)'
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'WebCrypto.hmac_sha256(key, bytes.keep_if(|b| b != 32 and b != 10))',1))
