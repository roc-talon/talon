import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# the old proposal of Q381: no R-TP9 row 2 on the claimed row
mutate(sys.argv[1], 'ReconcileCron.roc', 'other = if (s.u == s.f) [] else transfer(s.u).append(', 'other = if (s.u == s.f) [] else [].append(')
