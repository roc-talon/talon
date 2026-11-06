import sys
p=sys.argv[1]+"/WebhookRoutes.roc"
s=open(p).read()
old='\t\tgiven = match req.header'
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'\t\t_ = Webhook.parse_event({ event: req.header("x-github-event") ?? "", body: bytes }).map_err(|p| Refuse(p))?\n\t\tgiven = match req.header',1))
