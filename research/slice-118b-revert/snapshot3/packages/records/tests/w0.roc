app [main!] { records: "../main.roc" }

# W0 driver: `roc test` runs the `expect`s of the unit modules that it imports. Each unit module of this dir is imported by exactly one driver.

import IdTest
import CodeTest
import CompatTest
import CompatHintTest
import AnswerTest
import ProblemTest
import WireTest

main! = |_args| Ok({})
