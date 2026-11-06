import sys; sys.path.insert(0, __import__("os").path.dirname(__file__)); from _mut import mutate
# a duplicate id of two pages is not merged
mutate(sys.argv[1], "lib/Reconcile.roc", "pages.join_map(|p| p).fold([], |acc, item| if (acc.any(|x| x.id == item.id)) acc else acc.append(item))", "pages.join_map(|p| p)")
