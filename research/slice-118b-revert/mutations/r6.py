import sys
p=sys.argv[1]+"/IndexQueue.roc"
s=open(p).read()
old='\t\twrite_changes!(session, job.repository_id, read, step)?\n'
assert s.count(old)==1, "mutation anchor missing"
open(p,"w").write(s.replace(old,'\t\tskip_write = match step {\n\t\t\tNoAsset => match Webhook.after_no_asset(attempts) {\n\t\t\t\tRetry(_) => Bool.True\n\t\t\t\tDone => Bool.False\n\t\t\t}\n\t\t\t_ => Bool.False\n\t\t}\n\t\tif !skip_write {\n\t\t\twrite_changes!(session, job.repository_id, read, step)?\n\t\t}\n',1))
