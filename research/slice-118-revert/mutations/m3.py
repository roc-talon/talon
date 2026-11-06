import sys
p=sys.argv[1]+"/WebhookRoutes.roc"
s=open(p).read()
a='\t\tsecret = Env.secret!("GITHUB_WEBHOOK_SECRET").map_err(|e| Fault(Str.inspect(e)))?\n\t\tkey = secret.reveal().to_utf8()\n\t\tif key.is_empty() {\n\t\t\treturn Err(Fault("the secret GITHUB_WEBHOOK_SECRET is empty"))\n\t\t}\n'
assert a in s
b='\t\tkey = match Env.secret!("GITHUB_WEBHOOK_SECRET") {\n\t\t\tOk(secret) => secret.reveal().to_utf8()\n\t\t\tErr(_) => []\n\t\t}\n'
open(p,"w").write(s.replace(a,b,1))
