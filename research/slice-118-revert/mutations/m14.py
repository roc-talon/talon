import sys
p=sys.argv[1]+"/IndexQueue.roc"
s=open(p).read()
old='WHERE repo IN (SELECT repo FROM repos WHERE repository_id IN (SELECT CAST(value AS INTEGER) FROM json_each(?2)))'
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'WHERE repo IN (SELECT MIN(repo) FROM repos WHERE repository_id IN (SELECT CAST(value AS INTEGER) FROM json_each(?2)) GROUP BY repository_id)',1))
