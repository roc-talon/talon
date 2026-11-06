import sys; sys.path.insert(0, __import__('os').path.dirname(__file__))
from lib import edit
edit(sys.argv[1], 'lib/GithubApp.roc', r'''now_ms.plus_saturated(keep_margin_ms) < t.expires_ms''', r'''now_ms < t.expires_ms''')
