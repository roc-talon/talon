import sys
p=sys.argv[1]+"/lib/Webhook.roc"
s=open(p).read()
old='("installation", "deleted") => Ok(AppInstalled({ repository_ids: m.repository_ids, installed: Bool.False }))'
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'("installation", "deleted") => Ok(AppInstalled({ repository_ids: m.repository_ids, installed: Bool.True }))',1))
