app [main!] {
    pf: platform "PF",
    pkg: "pkg/main.roc",
}

import pf.Stdout
import pkg.Bad

main! = |_args| {
    Stdout.line!("hi")?
    Ok({})
}
