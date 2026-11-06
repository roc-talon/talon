import sys
p=sys.argv[1]+"/lib/Webhook.roc"
s=open(p).read()
old='3 => Ok(900_000)'
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'3 => Ok(600_000)',1))
