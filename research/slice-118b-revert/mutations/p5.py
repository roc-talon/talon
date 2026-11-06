import sys
p=sys.argv[1]+"/IndexQueue.roc"
s=open(p).read()
old='''if problem.http_status() >= 500 {'''
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'''if problem.http_status() >= 400 {''',1))
