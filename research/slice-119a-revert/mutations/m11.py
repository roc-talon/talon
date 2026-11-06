import sys; sys.path.insert(0, __import__('os').path.dirname(__file__))
from lib import edit
edit(sys.argv[1], 'lib/GithubApp.roc', r'''uses_token = |url| url.starts_with(api_prefix)''', r'''uses_token = |url| url.starts_with("https://")''')
