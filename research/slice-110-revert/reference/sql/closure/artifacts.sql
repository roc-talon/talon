SELECT h.hx AS hash, a.kind, a.exposes AS exposed_json, pn.value AS platform_hash, a.roc_pin, a.size
FROM h JOIN artifacts a ON a.artifact = h.artifact LEFT JOIN names pn ON pn.id = a.platform ORDER BY h.hx
