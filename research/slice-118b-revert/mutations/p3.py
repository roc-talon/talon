import sys
p=sys.argv[1]+"/IndexQueue.roc"
s=open(p).read()
old='''repository_id = ?1 AND state <> 2)", (job.repository_id, now))'''
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'''repository_id = ?1)", (job.repository_id, now))''',1))
