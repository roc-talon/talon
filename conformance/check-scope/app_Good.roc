app [main!] {
    pf: platform "PF",
    pkg: "pkg/main.roc",
}

import pf.Stdout
import pkg.Good

main! = |_args| {
    Stdout.line!("hi")?
    Ok({})
}
