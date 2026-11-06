# Revert check of the code agent of slice 111: one mutation of worker/lib/ArchiveRead.roc by its name.
import sys
p = 'worker/lib/ArchiveRead.roc'
m = {
 'm1-type-byte': ('offset + 156 - base', 'offset + 155 - base'),
 'm2-no-replay': ('Err(_) if bytes.len() > 512 =>', 'Err(_) if bytes.len() > 999999999999 =>'),
 'm3-no-file-above': ('Ok(under) => return Err(UnderFile({ path: under, file: path }))', 'Ok(_) => {}'),
 'm4-no-fold': ('Str.join_with(parts(path), "/").with_ascii_lowercased()', 'Str.join_with(parts(path), "/")'),
 'm5-no-b58-len': ('Ok(raw) if raw.len() == 32 => Ok(dep)', 'Ok(_) => Ok(dep)'),
 'm6-order': ('''		if (actual != hash) {
			return Err(HashMismatch({ expected: hash, actual }))
		}
		match state.refused {
			Ok(refusal) => return Err(refusal)
			Err(None) => {}
		}''', '''		match state.refused {
			Ok(refusal) => return Err(refusal)
			Err(None) => {}
		}
		if (actual != hash) {
			return Err(HashMismatch({ expected: hash, actual }))
		}'''),
 'm7-count-ge': ('if (total > max_packed_bytes)', 'if (total >= max_packed_bytes)'),
 'm8-target-dir': ('(parts(path).len() > 2 or path.ends_with("/"))', '(parts(path).len() > 2)'),
}
a, b = m[sys.argv[1]]
s = open(p).read()
assert s.count(a) == 1, sys.argv[1]
open(p, 'w').write(s.replace(a, b))
