app [main!] { lib: "../../cli/lib/main.roc" }

# l0 driver 5 of 8: `roc test` runs the `expect`s of the unit modules that it imports. Each unit module of this dir is imported by exactly one driver (`scripts/test.sh` checks it).

import ArgsTest
import CompilerTest
import FactsTest
import IndexTest
import LinkTest
import PickclosureTest
import ProbecmdTest
import PromptTest
import ReportTest
import ToolCompilerTest
import WhyTest
import XCacheTest

main! = |_args| Ok({})
