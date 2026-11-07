#!/usr/bin/env python3
# Usage: countnat.py BINARY TEXT. For a native (x86-64 ELF) build: prints the text size, the largest function,
# and the number of instructions in each function that point at the literal that holds TEXT (one per copy of the code that uses it).
import sys, subprocess, re
f, text = sys.argv[1], sys.argv[2].encode()
data = open(f, 'rb').read()
off = data.find(text)
if off < 0: sys.exit('text not in binary')
# a short literal can be built from immediates in the code: count the first 8 bytes of TEXT in each function too
syms = subprocess.run(['nm', '-S', f], capture_output=True, text=True).stdout
textsec = re.search(r'^\s*\d+\s+\.text\s+([0-9a-f]+)\s+([0-9a-f]+)\s+[0-9a-f]+\s+([0-9a-f]+)', subprocess.run(['objdump', '-h', f], capture_output=True, text=True).stdout, re.M)
tvma, tfoff = int(textsec.group(2), 16), int(textsec.group(3), 16)
imm = {}
for m in re.finditer(r'^([0-9a-f]+) ([0-9a-f]+) [tT] (\S+)$', syms, re.M):
    a, n, name = int(m.group(1), 16), int(m.group(2), 16), m.group(3)
    lo = a - tvma + tfoff
    c = data[lo:lo + n].count(text[:8])
    if c: imm[name] = (n, c)
# file offset to virtual address
secs = subprocess.run(['objdump', '-h', f], capture_output=True, text=True).stdout
addr = None
for m in re.finditer(r'^\s*\d+\s+(\S+)\s+([0-9a-f]+)\s+([0-9a-f]+)\s+[0-9a-f]+\s+([0-9a-f]+)', secs, re.M):
    name, size, vma, foff = m.group(1), int(m.group(2), 16), int(m.group(3), 16), int(m.group(4), 16)
    if foff <= off < foff + size: addr = vma + off - foff
dis = subprocess.run(['objdump', '-d', '--no-show-raw-insn', f], capture_output=True, text=True).stdout
fn, refs, sizes, start = None, {}, {}, {}
for line in dis.splitlines():
    m = re.match(r'^([0-9a-f]+) <(.*)>:$', line)
    if m: fn = m.group(2); start[fn] = int(m.group(1), 16); continue
    m = re.match(r'^\s+([0-9a-f]+):', line)
    if m and fn: sizes[fn] = int(m.group(1), 16) - start[fn]
    for a in re.findall(r'(?:# |\$0x)([0-9a-f]+)', line):
        a = int(a, 16)
        if addr - 64 <= a <= addr and fn: refs.setdefault(fn, {}).setdefault(a, 0); refs[fn][a] += 1
size = subprocess.run(['size', f], capture_output=True, text=True).stdout.split('\n')[1].split()[0]
big = max(sizes, key=sizes.get)
print(f'text {size} | largest fn {sizes[big]} {big[:50]}')
for name, (n, c) in imm.items(): print(f'  {name[:50]} {n} bytes: {c} copies of "{text.decode()}" (as immediates)')
best = max((a for r in refs.values() for a in r), default=None)
for fn, r in refs.items():
    if best in r: print(f'  {fn[:50]} {sizes.get(fn)} bytes: {r[best]} copies of "{text.decode()}"')
