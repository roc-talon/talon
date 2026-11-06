import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
mutate(sys.argv[1], "ReconcileCron.roc", ".map_err(|e| fail(\"the send of the candidates failed: ${Str.inspect(e)}\"))?", ".map_err(|e| fail(\"the send of the candidates failed: ${Str.inspect(e)}\")) ?? {}")
