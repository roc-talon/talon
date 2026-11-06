SELECT rn.value AS name, rp.state, sn.value AS successor, rp.state_at
FROM (SELECT DISTINCT rl.repo FROM h JOIN releases rl ON rl.artifact = h.artifact WHERE rl.repo IS NOT NULL) x
JOIN repos rp ON rp.repo = x.repo JOIN names rn ON rn.id = x.repo LEFT JOIN names sn ON sn.id = rp.successor ORDER BY rn.value
