import sys; sys.path.insert(0, __import__('os').path.dirname(__file__)); from _mut import mutate
# Design Q377: a reserve on the visibility read ends the row before its list read (the rejected reading).
mutate(sys.argv[1], "ReconcileCron.roc", "\t\tr1 = reserve_of(vis)\n", "\t\tr1 = reserve_of(vis)\n\t\tif r1.is_ok() {\n\t\t\treturn { result: Ok({}), reserve: r1 }\n\t\t}\n")
