import sys
p=sys.argv[1]+"/lib/Webhook.roc"
s=open(p).read()
old='''assets.contains("${row.hash}.tar.zst")'''
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'''assets.any(|a| a.starts_with(row.hash))''',1))
