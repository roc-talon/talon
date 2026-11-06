SELECT MIN(j.key) AS idx FROM json_each(?2) j WHERE NOT EXISTS (SELECT 1 FROM artifacts a WHERE a.artifact = j.value)
GROUP BY j.value ORDER BY idx
