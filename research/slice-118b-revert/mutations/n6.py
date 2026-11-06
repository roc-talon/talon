import sys
p=sys.argv[1]+"/IndexQueue.roc"
s=open(p).read()
old='''UPDATE repo_checks SET app_installed = 1 WHERE repo IN (SELECT repo FROM repos WHERE repository_id = ?1)'''
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'''UPDATE repo_checks SET app_installed = 1 WHERE repo IN (SELECT repo FROM repos WHERE repository_id = ?1 AND state <> 2)''',1))
