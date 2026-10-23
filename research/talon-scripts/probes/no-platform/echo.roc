app [main!] {}

main! = |args| {
	dbg args
	Stdout.line!("hello")
	Ok({})
}
