import sys
p=sys.argv[1]+"/IndexQueue.roc"
s=open(p).read()
old='\t\t\t\t\t\t_ = mark_installed!(job, Nothing)\n'
assert s.count(old)==1, "mutation anchor missing"
open(p,"w").write(s.replace(old,'',1))
