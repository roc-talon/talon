import sys
p=sys.argv[1]+"/lib/Webhook.roc"
s=open(p).read()
old='''		Err(GiveUp) => Done
	}'''
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'''		Err(GiveUp) => Retry(3_600_000)
	}''',1))
