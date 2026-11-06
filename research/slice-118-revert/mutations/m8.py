import sys
p=sys.argv[1]+"/lib/Webhook.roc"
s=open(p).read()
old='Ok(r) => if (r.public) Ok(Stale) else Ok(Withdraw)'
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'Ok(_) => Ok(Withdraw)',1))
