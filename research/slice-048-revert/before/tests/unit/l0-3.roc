app [main!] { lib: "../../cli/lib/main.roc" }

# l0 driver 3 of 8: `roc test` runs the `expect`s of the unit modules that it imports. Each unit module of this dir is imported by exactly one driver (`scripts/test.sh` checks it).

import BuildtargetTest
import DiffTest
import DownloadTest
import EpochsTest
import FrozenTest
import GitTest
import InitTest
import IntentTest
import LockTest
import NightliesTest
import NightlyplanTest
import RangesTest
import TalonfileTest

main! = |_args| Ok({})
