import sys
p=sys.argv[1]+"/lib/Webhook.roc"
s=open(p).read()
old='''releases/download/${input.read.tag}/${one}")'''
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'''releases/download/${input.read.tag}/${one}".with_ascii_lowercased())''',1))
