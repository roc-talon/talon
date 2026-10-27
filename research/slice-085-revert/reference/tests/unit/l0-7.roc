app [main!] { lib: "../../cli/lib/main.roc" }

# l0 driver 7 of 8: `roc test` runs the `expect`s of the unit modules that it imports. Each unit module of this dir is imported by exactly one driver (`scripts/test.sh` checks it).

import CacheviewTest
import ClockTest
import GcTest
import ListingTest
import ModeTest
import PathcmdTest
import PickmovesTest
import ProberangeTest
import RefTest
import RunscriptTest
import ScanTest
import UpdateTest
import XCmdTest

main! = |_args| Ok({})
