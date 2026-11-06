app [main!] { lib: "../../lib/main.roc", semver: "https://github.com/Karakatiza666/roc-semver/releases/download/0.2.0/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i.tar.zst" }

# W0 driver: `roc test` runs the `expect`s of the unit modules that it imports. Each unit module of this dir is imported by exactly one driver.

import OidcTest
import ProblemTest
import RouteTest
import VersionTest

main! = |_args| Ok({})
