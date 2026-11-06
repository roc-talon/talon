app [main!] { lib: "../../cli/lib/main.roc" }

# l0 driver 8 of 8: `roc test` runs the `expect`s of the unit modules that it imports. Each unit module of this dir is imported by exactly one driver (`scripts/test.sh` checks it).

import AddTest
import AliasTest
import BuildskipTest
import ClosuregapsTest
import ClosureindexTest
import ClosurerequestTest
import DbTest
import OracleprobeTest
import PickTest
import QueuesendTest
import RebaseTest
import RegistryTest
import RootsTest
import SharequeueTest
import ShareTest
import ToolchainTest
import ToolsplanTest

main! = |_args| Ok({})
