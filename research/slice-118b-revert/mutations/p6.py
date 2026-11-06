import sys
p=sys.argv[1]+"/lib/Webhook.roc"
s=open(p).read()
old='''				Ok(_) => Err(NoChange)
			}
			Final'''
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'''				Ok(_) => Ok({ log_index: row.log_index, to: Ok(value) })
			}
			Final''',1))
