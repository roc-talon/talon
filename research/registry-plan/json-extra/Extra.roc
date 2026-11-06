## R-AP44 probe: the Worker ignores a request field that it does not know. Does the derived Json parser skip an
## unknown key, and a nested unknown object? Does it refuse a body field that the design forbids (R-MX5 `source`)?
Extra := [].{}

Row : { hash : Str, nightly : Str }

parse_row : Str -> Try(Row, _)
parse_row = |t| Json.parse(t)

expect parse_row("{\"hash\":\"h\",\"nightly\":\"n\",\"future\":{\"a\":[1,2]}}") == Ok({ hash: "h", nightly: "n" })
expect parse_row("{\"hash\":\"h\",\"nightly\":\"n\",\"source\":\"bot\"}").is_ok()
