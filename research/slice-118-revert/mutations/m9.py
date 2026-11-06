import sys
p=sys.argv[1]+"/IndexQueue.roc"
s=open(p).read()
old='Err(GiveUp) => m.retry!()'
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'Err(GiveUp) => m.ack!()',1))
