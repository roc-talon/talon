-- A row that the Worker cannot convert: exposes is not a JSON array (R-RE1). The answer is 500 internal (R-AP48 row 7), never a crash.
INSERT INTO names VALUES (7083968092038500324, 1, x'2121212121212121212121212121212121212121212121212121212121212121');
INSERT INTO artifacts VALUES (7083968092038500324, 1, 'not json', NULL, NULL, 1);
