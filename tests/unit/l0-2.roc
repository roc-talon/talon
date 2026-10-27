app [main!] { lib: "../../cli/lib/main.roc" }

# l0 driver 2 of 8: `roc test` runs the `expect`s of the unit modules that it imports. Each unit module of this dir is imported by exactly one driver (`scripts/test.sh` checks it).

import AgecompilerTest
import ExplainTest
import GithubTest
import LockedTest
import MembersTest
import OracleTest
import PathrocTest
import PickerTest
import RemovalTest
import SelectorTest
import UnitsTest
import VarsTest

main! = |_args| Ok({})
