app [main!] { lib: "../../cli/lib/main.roc" }

# l0 driver 1 of 8: `roc test` runs the `expect`s of the unit modules that it imports. Each unit module of this dir is imported by exactly one driver (`scripts/test.sh` checks it).

import IdentTest
import LaunchTest
import ManageTest
import NetTest
import OutdatedTest
import PinsTest
import ProjectTest
import ProjectsTest
import TempTest
import UpgradeTest

main! = |_args| Ok({})
