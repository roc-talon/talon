import sys
p=sys.argv[1]+"/lib/Webhook.roc"
s=open(p).read()
old='4 => Ok(3_600_000)\n\t\t_ => Err(GiveUp)'
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'4 => Err(GiveUp)\n\t\t_ => Err(GiveUp)',1))
