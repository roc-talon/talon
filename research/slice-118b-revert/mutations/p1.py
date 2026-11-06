import sys
p=sys.argv[1]+"/lib/Webhook.roc"
s=open(p).read()
old='''if there and candidate and value != "repo-missing"'''
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'''if there and value != "repo-missing"''',1))
