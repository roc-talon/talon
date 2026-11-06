import sys; sys.path.insert(0, __import__('os').path.dirname(__file__))
from lib import edit
edit(sys.argv[1], 'lib/GithubApp.roc', r'''(s + 540).to_str()''', r'''(s + 600).to_str()''')
