import sys
p=sys.argv[1]+"/IndexQueue.roc"
s=open(p).read()
old='if job.action == "deleted" {'
assert s.count(old)==1, "mutation anchor missing"
open(p,"w").write(s.replace(old,'if job.action == "never" {',1))
