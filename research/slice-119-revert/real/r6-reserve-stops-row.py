import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
mutate(sys.argv[1], "ReconcileCron.roc", "\t\tfirst = reserve_of(res)\n", "\t\tfirst = reserve_of(res)\n\t\tif first.is_ok() {\n\t\t\treturn Ok(first)\n\t\t}\n")
