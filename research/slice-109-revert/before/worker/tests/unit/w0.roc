app [main!] { base58: "https://github.com/Karakatiza666/roc-base58/releases/download/0.1.0/BgUuQGqWY94NikfEx4rBkWkgxYhngMim3ZEnD8wpM4NS.tar.zst", lib: "../../lib/main.roc", records: "../../../packages/records/main.roc", semver: "https://github.com/Karakatiza666/roc-semver/releases/download/0.2.0/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i.tar.zst" }

# W0 driver: `roc test` runs the `expect`s of the unit modules that it imports. Each unit module of this dir is imported by exactly one driver.

import OidcTest
import ProblemTest
import ReadsTest
import RouteTest
import VersionTest

main! = |_args| Ok({})
