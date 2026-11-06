SELECT rl.log_index, h.hx AS hash, fn.value AS form, CAST(rl.version AS TEXT) AS version, rl.version_text, rl.url, rl.tag, rl.roc_version,
  rn.value AS repo, rl.published_at, rl.yanked, rl.withdrawn
FROM h JOIN releases rl ON rl.artifact = h.artifact JOIN names fn ON fn.id = rl.form LEFT JOIN names rn ON rn.id = rl.repo
ORDER BY rl.log_index
