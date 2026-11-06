import sys; sys.path.insert(0, __import__('os').path.dirname(__file__))
from lib import edit
edit(sys.argv[1], 'lib/GithubApp.roc', r'''iat = if (s < 60) 0 else s - 60''', r'''iat = s''')
