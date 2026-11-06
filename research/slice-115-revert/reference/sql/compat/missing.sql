SELECT n.value AS hash FROM members m JOIN names n ON n.id = m.artifact
WHERE NOT EXISTS (SELECT 1 FROM compat c WHERE c.artifact = m.artifact AND c.nightly = ?1 AND c.target = ?2 AND c.source = 0)
ORDER BY n.value
