app [main!] { records: "../../packages/records/main.roc" }

# Slice 206 (Q392): the reason text that records.Index.decode_releases gives for the damaged copy of the L3 case ix6-damaged-copy.
import records.Index

main! = |_args| {
	match Index.decode_releases("{\"releases\":") {
		Ok(_) => echo!("decoded\n")
		Err(BadJson(why)) => echo!("${why}\n")
	}
	Ok({})
}
