import sys
p=sys.argv[1]+"/lib/Webhook.roc"
s=open(p).read()
old='''Withdraw(input.action) else Skip'''
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'''Withdraw(if (input.action == "edited") "prereleased" else input.action) else Skip''',1))
