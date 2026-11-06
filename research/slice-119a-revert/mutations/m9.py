import sys; sys.path.insert(0, __import__('os').path.dirname(__file__))
from lib import edit
edit(sys.argv[1], 'GithubRead.roc', r'''GithubApp.token_url(installation)''', r'''GithubApp.token_url(app_id)''')
