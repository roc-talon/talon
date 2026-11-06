import sys
p=sys.argv[1]+"/lib/Webhook.roc"
s=open(p).read()
old='if (there and candidate) Ok'
assert s.count(old)==1, "mutation anchor missing"
open(p,"w").write(s.replace(old,'if (there) Ok',1))
