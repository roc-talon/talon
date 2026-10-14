#!/usr/bin/env python3
# Q16: print the format and the run-time library imports of one binary.
# Output: <format>\t<interp or ->\t<imports, comma separated, or "none">
import struct, subprocess, sys

def elf(path):
    dyn = subprocess.run(["readelf", "-dW", path], capture_output=True, text=True).stdout
    need = [l.split("[")[1].split("]")[0] for l in dyn.splitlines() if "(NEEDED)" in l]
    hdr = subprocess.run(["readelf", "-lW", path], capture_output=True, text=True).stdout
    interp = [l.split(":", 1)[1].strip(" ]") for l in hdr.splitlines() if "Requesting program interpreter" in l]
    return "elf", (interp[0] if interp else "-"), need

def macho(b):
    ncmds = struct.unpack_from("<I", b, 16)[0]
    off, libs = 32, []
    for _ in range(ncmds):
        cmd, size = struct.unpack_from("<II", b, off)
        if cmd in (0xC, 0x80000018, 0x8000001F, 0x80000023):  # LOAD, WEAK, REEXPORT, LAZY
            name_off = struct.unpack_from("<I", b, off + 8)[0]
            libs.append(b[off + name_off:off + size].split(b"\0")[0].decode())
        off += size
    return "macho", "-", libs

def pe(b):
    pe_off = struct.unpack_from("<I", b, 0x3C)[0]
    nsec, = struct.unpack_from("<H", b, pe_off + 6)
    opt_size, = struct.unpack_from("<H", b, pe_off + 20)
    opt = pe_off + 24
    dd = opt + (112 if struct.unpack_from("<H", b, opt)[0] == 0x20B else 96)
    imp_rva, = struct.unpack_from("<I", b, dd + 8)
    secs = [struct.unpack_from("<8sIIII", b, opt + opt_size + 40 * i) for i in range(nsec)]
    def fo(rva):
        for _, vsize, va, rsize, raw in secs:
            if va <= rva < va + max(vsize, rsize):
                return rva - va + raw
    libs, d = [], fo(imp_rva) if imp_rva else None
    while d is not None:
        name_rva = struct.unpack_from("<I", b, d + 12)[0]
        if name_rva == 0:
            break
        n = fo(name_rva)
        libs.append(b[n:b.index(b"\0", n)].decode())
        d += 20
    return "pe", "-", libs

def wasm(b):
    def leb(i):
        r = s = 0
        while True:
            x = b[i]; i += 1; r |= (x & 0x7F) << s; s += 7
            if x < 0x80:
                return r, i
    i, mods = 8, set()
    while i < len(b):
        sid = b[i]; size, i = leb(i + 1); end = i + size
        if sid == 2:
            n, i = leb(i)
            for _ in range(n):
                l, i = leb(i); mods.add(b[i:i + l].decode()); i += l
                l, i = leb(i); i += l
                kind = b[i]; i += 1
                if kind == 0: _, i = leb(i)
                elif kind == 1: i += 1; f = b[i]; _, i = leb(i + 1); i = leb(i)[1] if f & 1 else i
                elif kind == 2: f = b[i]; _, i = leb(i + 1); i = leb(i)[1] if f & 1 else i
                else: i += 2
        i = end
    return "wasm", "-", sorted(mods)

path = sys.argv[1]
b = open(path, "rb").read()
if b[:4] == b"\x7fELF": r = elf(path)
elif b[:4] == b"\xcf\xfa\xed\xfe": r = macho(b)
elif b[:2] == b"MZ": r = pe(b)
elif b[:4] == b"\0asm": r = wasm(b)
else: r = ("unknown", "-", [])
print(f"{r[0]}\t{r[1]}\t{','.join(r[2]) or 'none'}")
