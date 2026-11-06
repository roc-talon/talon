import sys
p=sys.argv[1]+"/lib/Webhook.roc"
s=open(p).read()
old='["created", "deleted", "suspend", "unsuspend"].contains(a)'
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'["created", "deleted", "unsuspend"].contains(a)',1))
