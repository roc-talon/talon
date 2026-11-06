import sys; sys.path.insert(0, __import__('os').path.dirname(__file__))
from lib import edit
edit(sys.argv[1], 'GithubRead.roc', r'''held = cache.get!(load!)?''', r'''held = load!()?''')
