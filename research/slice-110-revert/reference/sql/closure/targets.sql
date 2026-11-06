SELECT h.hx AS owner, tt.name FROM h JOIN artifact_targets at ON at.artifact = h.artifact JOIN targets tt ON tt.target = at.target
ORDER BY h.hx, tt.name
