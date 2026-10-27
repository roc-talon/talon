app [main!] { lib: "../../cli/lib/main.roc" }

# l0 driver 4 of 8: `roc test` runs the `expect`s of the unit modules that it imports. Each unit module of this dir is imported by exactly one driver (`scripts/test.sh` checks it).

import ConsentTest
import EvidenceTest
import GuardTest
import KindTest
import LadderTest
import OracledomainTest
import PinTest
import ProbeTest
import SetupTest
import ToolSourceTest
import UsesTest

main! = |_args| Ok({})
