import sys
p=sys.argv[1]+"/IndexQueue.roc"
s=open(p).read()
old='Added({ repo, now }) => [flag, Sql.stmt("UPDATE repo_checks SET next_check_at = ?2 WHERE repo = ?1", (repo, now + Reads.interval_ms(Bool.True)))]'
assert s.count(old)==1, "mutation anchor missing"
open(p,"w").write(s.replace(old,'Added({ repo, now }) => [flag]',1))
