app [main!] { lib: "../../cli/lib/main.roc" }

# l0 driver 6 of 8: `roc test` runs the `expect`s of the unit modules that it imports. Each unit module of this dir is imported by exactly one driver (`scripts/test.sh` checks it).

import BinrecordTest
import CleanTest
import ClosureTest
import CommonTest
import FetchTest
import LookupTest
import OptsTest
import OraclefreeTest
import OutTest
import ProxyTest
import ResolvebaseTest
import TalonRemoveTest
import VerifyTest
import ZigTest

main! = |_args| Ok({})
