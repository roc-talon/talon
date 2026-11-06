import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# the claimed row: rename before transfer (R-TP19 Order, Q381)
mutate(sys.argv[1], 'ReconcileCron.roc', 'other.concat(transfer(s.f)).concat([mark, marked, insert, named, checks, revive, revived, found, found_event])', '[mark, marked].concat(other).concat(transfer(s.f)).concat([insert, named, checks, revive, revived, found, found_event])')
