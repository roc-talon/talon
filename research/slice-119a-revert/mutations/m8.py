import sys; sys.path.insert(0, __import__('os').path.dirname(__file__))
from lib import edit
edit(sys.argv[1], 'lib/GithubApp.roc', r'''NoSetting(n) => Fault("the setting ${n} is not set")''', r'''NoSetting(n) => Upstream("the setting ${n} is not set")''')
