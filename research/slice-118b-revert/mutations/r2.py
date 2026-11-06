import sys
p=sys.argv[1]+"/lib/Webhook.roc"
s=open(p).read()
old='(Withdrawn(_), Ok(_)) => Err(NoChange)'
assert s.count(old)==1, "mutation anchor missing"
open(p,"w").write(s.replace(old,'(Withdrawn(value), Ok(_)) => Ok({ log_index: row.log_index, to: Ok(value) })',1))
