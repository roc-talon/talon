import sys
d = sys.argv[1]
f = d + '/IngestRoutes.roc'
s = open(f).read()
old = '''			Err(Changed) => return changed_response!(row, target.name)
		}
		release_text'''
new = '''			Err(Changed) => Identity.decide({ repo: name_id(target), row: Err(None), seen: { repository_id: repo.id, owner_id: repo.owner_id }, now }) ?? crash "x"
		}
		release_text'''
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
