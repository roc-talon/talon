SELECT rn.value AS name, rc.checked_at, COALESCE(rc.app_installed, 0) AS app_installed
FROM (SELECT DISTINCT rl.repo FROM releases rl, json_each(?1) g
  WHERE rl.form = (g.value ->> '$.form') AND rl.repo IS NOT NULL) x
JOIN names rn ON rn.id = x.repo LEFT JOIN repo_checks rc ON rc.repo = x.repo ORDER BY rn.value
