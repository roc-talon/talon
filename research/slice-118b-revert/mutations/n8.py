import sys
p=sys.argv[1]+"/IndexQueue.roc"
s=open(p).read()
old='''now + Reads.interval_ms(Bool.True)'''
assert old in s, "mutation anchor missing"
open(p,"w").write(s.replace(old,'''now + Reads.interval_ms(Bool.False)''',1))
