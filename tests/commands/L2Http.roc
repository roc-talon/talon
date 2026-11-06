import lib.Fx
import L2Util

## The entry `http` of the L2 test app (slice 200): the `Fx` calls `http_send!`, `http_all!` and `sleep!` with the fake `Fx`. It tests the fake and the route form
## (TESTING 3.1), and it is the model for the entries of the registry client slices. Each line of `fx/runs` is one run:
##
## | Line | Runs | Prints |
## | --- | --- | --- |
## | `send <GET, POST, PUT or DELETE> <url> [h:<Name>=<value>]... [timeout=<s>] [body=<text>]` | `http_send!`. `body=` is last and holds the rest of the line (`\n` is a new line, `\\` is a backslash). The default timeout is 20. | `status <n>`, `header <Name>: <value>` for each header, `body <text>`. Or `err <Timeout or Failed(text)>`. |
## | `all <limit> <METHOD>:<url>...` | `http_all!` with one request for each word (no header, no body, timeout 20) and the `tmp_dir` `<w>/home/.cache/roc/talon/tmp` (slice 200, R-DA8). `all 0 ...` has limit 0 (Design Q226). | `result <i> status <n> body <text>` or `result <i> err <the error>`, in the order of the list |
## | `sleep <ms>` | `sleep!` | `slept <ms>` |
##
## It prints `== <line>` first. Exit code 0.
L2Http :: [].{

	entry! : Fx, Str => I32
	entry! = |fx, w| {
		for line in L2Util.file_lines!("${w}/fx/runs").keep_if(|l| !l.starts_with("#")) {
			fx.out!("== ${line}\n")
			(head, body) = match line.split_first(" body=") {
				Ok({ before, after }) => (before, after.replace_each("\\n", "\n").replace_each("\\\\", "\\"))
				Err(_) => (line, "")
			}
			match L2Util.words(head) {
				["send", method, url, .. as rest] => {
					headers = rest.keep_oks(
						|word| if word.starts_with("h:") {
							match word.drop_prefix("h:").split_first("=") {
								Ok({ before, after }) => Ok((before, after))
								Err(_) => Err(NotHeader)
							}
						} else {
							Err(NotHeader)
						},
					)
					timeout_s = match rest.find_first(|word| word.starts_with("timeout=")) {
						Ok(word) => U64.from_str(word.drop_prefix("timeout=")) ?? 20
						Err(_) => 20
					}
					match fx.http_send!({ method: method_of(method), url, headers, body, timeout_s }) {
						Ok(answer) => {
							fx.out!("status ${answer.status.to_str()}\n")
							for (name, value) in answer.headers {
								fx.out!("header ${name}: ${value}\n")
							}
							fx.out!("body ${answer.body}\n")
						}
						Err(err) => fx.out!("err ${Str.inspect(err)}\n")
					}
				}
				["all", limit, .. as items] => {
					requests = items.map(
						|item| match item.split_first(":") {
							Ok({ before, after }) => { method: method_of(before), url: after, headers: [], body: "", timeout_s: 20 }
							Err(_) => { method: Get, url: item, headers: [], body: "", timeout_s: 20 }
						},
					)
					results = fx.http_all!({ requests, limit: U64.from_str(limit) ?? 1, tmp_dir: "${w}/home/.cache/roc/talon/tmp" })
					for (i, result) in results.map_with_index(|r, i| (i, r)) {
						match result {
							Ok(answer) => fx.out!("result ${i.to_str()} status ${answer.status.to_str()} body ${answer.body}\n")
							Err(err) => fx.out!("result ${i.to_str()} err ${Str.inspect(err)}\n")
						}
					}
				}
				["sleep", ms] => {
					fx.sleep!(U64.from_str(ms) ?? 0)
					fx.out!("slept ${ms}\n")
				}
				_ => fx.out!("bad line\n")
			}
		}
		0
	}
}

method_of : Str -> [Get, Post, Put, Delete]
method_of = |text| match text {
	"POST" => Post
	"PUT" => Put
	"DELETE" => Delete
	_ => Get
}
