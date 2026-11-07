# Writes or/main.roc (the arm `A | B | ... =>`, N tags) and wild/main.roc (the same body in a `_` arm).
# The arm body is a match of M strings; each arm calls echo!. Usage: gen.py N M
import sys, os
N = int(sys.argv[1]) if len(sys.argv) > 1 else 6
M = int(sys.argv[2]) if len(sys.argv) > 2 else 20
tags = [chr(ord('A') + i) for i in range(N)]
body = 'match s {\n' + ''.join(f'\t\t\t"k{i}" => echo!("line {i:02d} of the arm body")\n' for i in range(M)) + '\t\t\t_ => {}\n\t\t}'
def prog(arms):
    return '''main! = |args| {
	s = args.first().map_ok(|a| a.to_str()) ?? ""
	e = match args.len() {
''' + ''.join(f'\t\t{i} => {x}\n' for i, x in enumerate(tags)) + f'''\t\t_ => Z
	}}
	match e {{
{arms}
	}}
	Ok({{}})
}}
'''
forms = {
    'or': '\t\t' + ' | '.join(tags) + ' => ' + body + '\n\t\tZ => {}',
    'wild': '\t\tZ => {}\n\t\t_ => ' + body,
}
d = os.path.dirname(os.path.abspath(__file__))
for k, v in forms.items():
    os.makedirs(f'{d}/{k}', exist_ok=True)
    open(f'{d}/{k}/main.roc', 'w').write(prog(v))
