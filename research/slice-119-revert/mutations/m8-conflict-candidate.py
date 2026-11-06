import sys; sys.path.insert(0, __import__('os').path.dirname(__file__)); from _mut import mutate
mutate(sys.argv[1], "lib/Reconcile.roc", "if item.release.draft or item.release.prerelease or input.rows.any(|r| r.tag == item.tag) {", "if item.release.draft or item.release.prerelease or input.rows.any(|r| r.tag == item.tag and item.release.assets.contains(\"${r.hash}.tar.zst\")) {")
