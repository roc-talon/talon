# ref.sh: puts the reference body of Client.rate_key (Design Q168, Q185) in the copy of worker/lib/Client.roc, if it is still the stub of slice 116b.
import sys, os
here = os.path.dirname(os.path.abspath(__file__))
p = os.path.join(sys.argv[1], 'lib', 'Client.roc')
s = open(p).read()
stub = '\trate_key = |_ip| crash "todo"\n'
if stub in s:
    s = s.replace(stub, open(os.path.join(here, 'client-rate-key.roc.txt')).read())
    open(p, 'w').write(s)
