import sys
p=sys.argv[1]+"/IndexQueue.roc"
s=open(p).read()
old='WHERE repository_id = ?1 AND state <> 2)", (id, Time.now_ms!())'
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'WHERE repository_id = ?1)", (id, Time.now_ms!())',1))
