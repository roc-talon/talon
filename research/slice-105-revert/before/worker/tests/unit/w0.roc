app [main!] { lib: "../../lib/main.roc" }

# W0 driver: `roc test` runs the `expect`s of the unit modules that it imports. Each unit module of this dir is imported by exactly one driver.

import ProblemTest
import RouteTest

main! = |_args| Ok({})
