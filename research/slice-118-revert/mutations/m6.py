import sys
p=sys.argv[1]+"/lib/Webhook.roc"
s=open(p).read()
old='["published", "released", "edited", "prereleased", "unpublished", "deleted"].contains(a)'
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'["created", "published", "released", "edited", "prereleased", "unpublished", "deleted"].contains(a)',1))
