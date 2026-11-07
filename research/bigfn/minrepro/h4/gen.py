# Smallest form: tags with no payload, and an arm body that is a match of M strings, each arm an echo! call. N = argv[1] tags, M = argv[2] lines.
import sys, os
N = int(sys.argv[1]) if len(sys.argv) > 1 else 6
M = int(sys.argv[2]) if len(sys.argv) > 2 else 20
tags = [chr(ord('A') + i) for i in range(N)]
body = 'match s {\n' + ''.join(f'\t\t"k{i}" => echo!("line {i:02d} of the arm body")\n' for i in range(M)) + '\t\t_ => {}\n\t}'
def prog(arms):
    return f'''main! = |args| {{
	s = args.first().map_ok(|a| a.to_str()) ?? ""
	e = match args.len() {{
''' + ''.join(f'\t\t{i} => {x}\n' for i, x in enumerate(tags)) + f'''\t\t_ => Z
	}}
	match e {{
{arms}
	}}
	Ok({{}})
}}
'''
ind = lambda s: s.replace('\n', '\n\t')
forms = {
    'or': '\t\t' + ' | '.join(tags) + ' => ' + ind(body) + '\n\t\tZ => {}',
    'arms': '\n'.join(f'\t\t{x} => ' + ind(body) for x in tags) + '\n\t\tZ => {}',
    'one': '\t\tZ => {}\n\t\t_ => ' + ind(body),
}
d = os.path.dirname(os.path.abspath(__file__))
for k, v in forms.items():
    os.makedirs(f'{d}/{k}', exist_ok=True)
    open(f'{d}/{k}/main.roc', 'w').write(prog(v))
