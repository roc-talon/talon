import sys
f = sys.argv[1] + '/IngestRoutes.roc'
s = open(f).read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a)
    s = s.replace(a, b)
rep('Ok(repo) if repo.public => {', 'Ok(repo) => {')
rep('''					Err(Changed) => return changed_response!(row, target.name)
				}
				stmts''', '''					Err(Changed) => return changed_response!(row, target.name)
				}
				if !repo.public {
					return Err(Refuse(Ingest.not_public))
				}
				stmts''')
rep('''			Err(Changed) => return changed_response!(row, target.name)
		}
		release_text''', '''			Err(Changed) => return changed_response!(row, target.name)
		}
		if !repo.public {
			return Err(Refuse(Ingest.not_public))
		}
		release_text''')
open(f, 'w').write(s)
