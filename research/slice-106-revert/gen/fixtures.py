# Independent expected values for the slice 106 tests (python, no Roc code). Used by gen_w2.py and printed for ReadsTest.roc.
import hashlib, json
ALPHA='123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
def b58(b):
    n=int.from_bytes(b,'big');s=''
    while n: n,r=divmod(n,58);s=ALPHA[r]+s
    return '1'*(len(b)-len(b.lstrip(b'\0')))+s
def nid(kind,data):
    return int.from_bytes(hashlib.sha256(bytes([kind])+data).digest()[:8],'big',signed=True)
def stored(k):
    v=k^(1<<63)
    return v-(1<<64) if v>=(1<<63) else v
def key(M,m,p): return (M<<48)|(m<<32)|(p<<16)|0xFFFF
def etag(body): return '"'+hashlib.sha256(body).hexdigest()[:32]+'"'
def js(o): return json.dumps(o,separators=(',',':'),sort_keys=True,ensure_ascii=False)
H1=bytes(range(32)); H2=bytes(255-i for i in range(32)); H3=bytes([7]*32); H4=bytes([9]*32); H5=bytes([200-i for i in range(32)])
G1='github.com/roc-lang/unicode/releases/download/{v}/'
G1B='github.com/roc-lang/unicode/releases/download/v{v}/'
GX='example.com/pkg/{v}/'
G2='github.com/roc-lang/other/releases/download/{v}/'
R1='roc-lang/unicode'; R2='roc-lang/other'; R3='roc-lang/moved'
def url(form,ver,h):
    return 'https://'+form.replace('{v}',ver)+b58(h)+'.tar.zst'
