import sys
p=sys.argv[1]+"/IndexQueue.roc"
s=open(p).read()
old='''UPDATE releases SET withdrawn = NULL, withdrawn_at = NULL WHERE log_index = ?1'''
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'''UPDATE releases SET withdrawn = NULL WHERE log_index = ?1''',1))
