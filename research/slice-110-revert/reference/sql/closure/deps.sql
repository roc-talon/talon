SELECT h.hx AS owner, dp.alias, dn.value AS hash, fn.value AS form, CAST(dp.version AS TEXT) AS version, dp.version_text, dp.url
FROM h JOIN deps dp ON dp.artifact = h.artifact JOIN names dn ON dn.id = dp.dep LEFT JOIN names fn ON fn.id = dp.form
ORDER BY h.hx, dp.alias
