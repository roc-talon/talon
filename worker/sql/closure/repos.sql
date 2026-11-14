SELECT rn.value AS name, p.state AS state, sn.value AS successor, p.state_at AS state_at,
(SELECT e.action FROM repo_events e WHERE e.repo = p.repo AND e.action IN (1, 3) ORDER BY e.seq DESC LIMIT 1) AS owner_action, (SELECT e.time FROM repo_events e WHERE e.repo = p.repo AND e.action IN (1, 3) ORDER BY e.seq DESC LIMIT 1) AS owner_at
FROM repos p JOIN names rn ON rn.id = p.repo LEFT JOIN names sn ON sn.id = p.successor
WHERE p.repo IN (SELECT repo FROM rel) ORDER BY rn.value
