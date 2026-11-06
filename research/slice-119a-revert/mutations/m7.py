import sys; sys.path.insert(0, __import__('os').path.dirname(__file__))
from lib import edit
edit(sys.argv[1], 'HintRoutes.roc', r'''res = GithubRead.send!(Request.get(Hints.tags_url)) ? |_| NoTags''', r'''res = Http.send!(Request.get(Hints.tags_url).with_header("user-agent", "talon-registry")) ? |_| NoTags''')
