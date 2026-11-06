app [main!] { base58: "https://github.com/Karakatiza666/roc-base58/releases/download/0.1.0/BgUuQGqWY94NikfEx4rBkWkgxYhngMim3ZEnD8wpM4NS.tar.zst", header: "https://github.com/Karakatiza666/roc-app-header/releases/download/0.1.0/HDQnwrX2Bcm8Jsf8RMC9ZdbVGwPiqD2nCLP7Zf1osfgU.tar.zst", jwt: "https://github.com/Karakatiza666/roc-jwt/releases/download/0.0.1/C35APf1eow8zsCV6yrDpXLr3wxrMQVPdtoTQSGAM9dDh.tar.zst", lib: "../../lib/main.roc", records: "../../../packages/records/main.roc", semver: "https://github.com/Karakatiza666/roc-semver/releases/download/0.2.0/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i.tar.zst", tar: "https://github.com/Karakatiza666/roc-tar/releases/download/0.0.1/FGAUE1Pds7Fvd48GkrAYd9rRUpztew8bgUZjUrKPGyo7.tar.zst" }

# W0 driver: `roc test` runs the `expect`s of the unit modules that it imports. Each unit module of this dir is imported by exactly one driver.

import ClientTest
import ClosureQueryTest
import HintsTest
import IdentityTest
import IngestTest
import IngestLimitsTest
import CompatTest
import CompatReadsTest
import OidcTest
import ArchiveReadTest
import ProblemTest
import ReadsTest
import RouteTest
import ShortsTest
import ToolchainsTest
import VersionTest

main! = |_args| Ok({})
