# Writes or/, arms/, one/ main.roc: the or-pattern arm, one arm for each tag, and a `_` arm. N = argv[1] tags.
import sys, os
N = int(sys.argv[1]) if len(sys.argv) > 1 else 6
tags = [chr(ord('A') + i) for i in range(N)]
body = '''match t {
''' + "\n".join(f'\t\t"k{i}" => "marker text number {i:02d} for the copy count"' for i in range(40)) + '''
		_ => "the default answer"
	}'''
def prog(arms):
    return f'''Ev : [{', '.join(f'{x}(Str)' for x in tags)}, Z]

ev_of : Str -> Ev
ev_of = |t| match t {{
''' + ''.join(f'\t"{x.lower()}" => {x}(t)\n' for x in tags) + f'''\t_ => Z
}}

pick : Ev, Str -> Str
pick = |e, t| match e {{
{arms}
}}

main! = |args| {{
	t = args.first() ?? "a"
	s = t.to_str()
	echo!(pick(ev_of(s), s))
	Ok({{}})
}}
'''
forms = {
    'or': '\t' + ' | '.join(f'{x}(_)' for x in tags) + ' => ' + body + '\n\tZ => "none"',
    'arms': '\n'.join(f'\t{x}(_) => ' + body for x in tags) + '\n\tZ => "none"',
    'one': '\tZ => "none"\n\t_ => ' + body,
}
d = os.path.dirname(os.path.abspath(__file__))
for k, v in forms.items():
    os.makedirs(f'{d}/{k}', exist_ok=True)
    open(f'{d}/{k}/main.roc', 'w').write(prog(v))
