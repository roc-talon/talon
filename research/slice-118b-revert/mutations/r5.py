import sys
p=sys.argv[1]+"/IndexQueue.roc"
s=open(p).read()
old='if (problem.http_status() < 500) refused!'
assert s.count(old)==1, "mutation anchor missing"
open(p,"w").write(s.replace(old,'if (problem.http_status() < 600) refused!',1))
