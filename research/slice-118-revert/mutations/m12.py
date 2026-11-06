import sys
p=sys.argv[1]+"/WebhookRoutes.roc"
s=open(p).read()
old='body_limit = 1048576'
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'body_limit = 262144',1))
