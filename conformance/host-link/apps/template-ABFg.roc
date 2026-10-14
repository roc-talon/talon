app [main!] { pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/x/ABFgWwu8SwPJfp7tzxDoTL41b1jFeHEac3RxUFSt1WWp.tar.zst" }

import pf.Stdout

main! = |_args| {
    Stdout.line!("hi")?
    Ok({})
}
