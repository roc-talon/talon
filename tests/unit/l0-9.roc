app [main!] { bot: "../../bot/lib/main.roc", lib: "../../cli/lib/main.roc", records: "../../packages/records/main.roc" }

# l0 driver 9: `roc test` runs the `expect`s of the unit modules that it imports. It has its own header for the package of the compat bot (slice 223). Each unit module of this dir is imported by exactly one driver (`scripts/test.sh` checks it).

import BotTest
import ChannelTest
import ChannelidTest
import ChannelreleaseTest
import ChannelswitchTest
import ChannelreadTest
import GcindexTest
import NewerhintTest
import TlngateTest
import TlngatepureTest

main! = |_args| Ok({})
