app [main!] { lib: "../../cli/lib/main.roc", records: "../../packages/records/main.roc" }

# l0 driver 1 of 8: `roc test` runs the `expect`s of the unit modules that it imports. Each unit module of this dir is imported by exactly one driver (`scripts/test.sh` checks it).

import FullnameTest
import IdentTest
import LaunchTest
import LogsnapshotTest
import ManageTest
import NetTest
import OutdatedTest
import PatchedTest
import PinsTest
import ProjectTest
import ProjectsTest
import TalonUpdateTest
import TempTest
import ToolTest
import UnknownvaluesTest
import UpgradeTest

main! = |_args| Ok({})
