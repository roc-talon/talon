app [main!] { pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.24.0/AEjfyaMFFbh8FJrkkHJy68riVNPr3Qp6c6PawWQjBwMH.tar.zst", parser: "https://github.com/lukewilliamboswell/roc-parser/releases/download/2.0.0/7CLzCK6qUz7zmj6nvBxMEFu11HPwQTnCovKiyWzDSLTW.tar.zst" }

import pf.Stdout
import parser.Utf8

main! = |args| {
    match Utf8.parse_str(Utf8.digits, args.len().to_str()) {
        Ok(n) => Stdout.line!("digits: ${n.to_str()}")?
        Err(_) => Stdout.line!("no digits")?
    }
    Ok({})
}
