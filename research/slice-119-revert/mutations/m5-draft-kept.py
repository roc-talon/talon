import sys; sys.path.insert(0, __import__('os').path.dirname(__file__)); from _mut import mutate
mutate(sys.argv[1], "lib/Reconcile.roc", "\t\t\t\t\t\tif item.release.draft {\n\t\t\t\t\t\t\tWithdrawn(\"deleted\")", "\t\t\t\t\t\tif item.release.draft {\n\t\t\t\t\t\t\tFinal({ assets: item.release.assets, candidate: Bool.False })")
