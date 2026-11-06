import sys
p=sys.argv[1]+"/IndexQueue.roc"
s=open(p).read()
old='''				Log.warn!("index label conflict", { repository_id: job.repository_id, release_id: job.release_id, group: target.form, version: target.version.to_str() })
				Ok({})
			}
			Answer'''
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'''				Ok({})
			}
			Answer''',1))
