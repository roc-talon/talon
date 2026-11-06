import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# found before the transfer on the row of F (R-TP19 Order)
mutate(sys.argv[1], 'ReconcileCron.roc', 'other.concat(transfer(s.f)).concat([mark, marked, insert, named, checks, revive, revived, found, found_event])', 'other.concat([mark, marked, insert, named, checks, revive, revived, found, found_event]).concat(transfer(s.f))')
