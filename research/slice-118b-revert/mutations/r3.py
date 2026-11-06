import sys
p=sys.argv[1]+"/lib/Webhook.roc"
s=open(p).read()
old='\t\t\t\tOk("repo-missing") => Err(NoChange)\n'
assert s.count(old)==1, "mutation anchor missing"
open(p,"w").write(s.replace(old,'',1))
