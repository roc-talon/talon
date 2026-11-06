CREATE TABLE IF NOT EXISTS names (id INTEGER PRIMARY KEY, kind INTEGER NOT NULL, value ANY NOT NULL, UNIQUE (kind, value)) STRICT;
INSERT OR IGNORE INTO names VALUES ('-2687166099708853831', 2, 'github.com/roc-lang/unicode/releases/download/{v}/');
