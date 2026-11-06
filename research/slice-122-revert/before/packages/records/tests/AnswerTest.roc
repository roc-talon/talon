import records.Account
import records.Index
import records.Short
import records.Toolchain

AnswerTest :: [].{}

# W0 tests of Index.roc, Toolchain.roc, Short.roc and Account.roc (slice 104e, R-AP73). The fixtures below are the bodies that the Worker gives in the W2 cases of slices 106, 107 and 109 (made by research/slice-104e-revert/gen.py from worker/tests/cases/*/expect/responses.jsonl).
# A fixture is decoded and encoded again: the text must be the same bytes, so the ETag of the Worker does not change (R-AP53, R-AP54). ' stands for " in the hand-written JSON.

js : Str -> Str
js = |text| text.replace_each("'", "\"")

# Index.Releases: reads/ap1-body-etag-cache (slice 106) and reads/ap13-group-series-after.
releases_bodies : List(Str)
releases_bodies = [
	"{\"releases\":[{\"group\":\"github.com/roc-lang/unicode/releases/download/{v}/\",\"hash\":\"US517G5965aydkZ46HS38QLi7UQiSojurfbQfKCELFx\",\"log_index\":1,\"published_at\":1700000000000,\"repo\":\"roc-lang/unicode\",\"roc_version\":null,\"series\":\"0.25\",\"tag\":\"0.25.1\",\"url\":\"https://github.com/roc-lang/unicode/releases/download/0.25.1/US517G5965aydkZ46HS38QLi7UQiSojurfbQfKCELFx.tar.zst\",\"version\":\"0.25.1\",\"withdrawn\":null,\"yank_reason\":null,\"yanked\":false},{\"group\":\"github.com/roc-lang/unicode/releases/download/{v}/\",\"hash\":\"1thX6LZfHDZZKUs92febYZhYRcXddmzfzF2NvTkPNE\",\"log_index\":2,\"published_at\":1700000100000,\"repo\":\"roc-lang/unicode\",\"roc_version\":\"0.1.0\",\"series\":\"4\",\"tag\":\"4.2.0\",\"url\":\"https://github.com/roc-lang/unicode/releases/download/4.2.0/1thX6LZfHDZZKUs92febYZhYRcXddmzfzF2NvTkPNE.tar.zst\",\"version\":\"4.2.0\",\"withdrawn\":null,\"yank_reason\":null,\"yanked\":false},{\"group\":\"github.com/roc-lang/unicode/releases/download/v{v}/\",\"hash\":\"JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3\",\"log_index\":3,\"published_at\":1700000200000,\"repo\":\"roc-lang/unicode\",\"roc_version\":null,\"series\":\"4\",\"tag\":\"v4.1.0\",\"url\":\"https://github.com/roc-lang/unicode/releases/download/v4.1.0/JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3.tar.zst\",\"version\":\"4.1.0\",\"withdrawn\":null,\"yank_reason\":null,\"yanked\":false},{\"group\":\"github.com/roc-lang/unicode/releases/download/{v}/\",\"hash\":\"JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3\",\"log_index\":4,\"published_at\":1700000300000,\"repo\":\"roc-lang/unicode\",\"roc_version\":null,\"series\":\"4\",\"tag\":\"4.3.0\",\"url\":\"https://github.com/roc-lang/unicode/releases/download/4.3.0/JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3.tar.zst\",\"version\":\"4.3.0\",\"withdrawn\":\"edited\",\"yank_reason\":null,\"yanked\":false}],\"checked\":{\"checked_at\":1767222000000,\"name\":\"roc-lang/unicode\",\"stale\":false},\"repos\":[{\"name\":\"roc-lang/unicode\",\"state\":\"active\",\"state_at\":1699999000000,\"successor\":null}]}",
	"{\"releases\":[{\"group\":\"github.com/roc-lang/unicode/releases/download/{v}/\",\"hash\":\"US517G5965aydkZ46HS38QLi7UQiSojurfbQfKCELFx\",\"log_index\":1,\"published_at\":1700000000000,\"repo\":\"roc-lang/unicode\",\"roc_version\":null,\"series\":\"0.25\",\"tag\":\"0.25.1\",\"url\":\"https://github.com/roc-lang/unicode/releases/download/0.25.1/US517G5965aydkZ46HS38QLi7UQiSojurfbQfKCELFx.tar.zst\",\"version\":\"0.25.1\",\"withdrawn\":null,\"yank_reason\":null,\"yanked\":false},{\"group\":\"github.com/roc-lang/unicode/releases/download/{v}/\",\"hash\":\"1thX6LZfHDZZKUs92febYZhYRcXddmzfzF2NvTkPNE\",\"log_index\":2,\"published_at\":1700000100000,\"repo\":\"roc-lang/unicode\",\"roc_version\":\"0.1.0\",\"series\":\"4\",\"tag\":\"4.2.0\",\"url\":\"https://github.com/roc-lang/unicode/releases/download/4.2.0/1thX6LZfHDZZKUs92febYZhYRcXddmzfzF2NvTkPNE.tar.zst\",\"version\":\"4.2.0\",\"withdrawn\":null,\"yank_reason\":null,\"yanked\":false},{\"group\":\"github.com/roc-lang/unicode/releases/download/{v}/\",\"hash\":\"JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3\",\"log_index\":4,\"published_at\":1700000300000,\"repo\":\"roc-lang/unicode\",\"roc_version\":null,\"series\":\"4\",\"tag\":\"4.3.0\",\"url\":\"https://github.com/roc-lang/unicode/releases/download/4.3.0/JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3.tar.zst\",\"version\":\"4.3.0\",\"withdrawn\":\"edited\",\"yank_reason\":null,\"yanked\":false}],\"checked\":{\"checked_at\":1767222000000,\"name\":\"roc-lang/unicode\",\"stale\":false},\"repos\":[{\"name\":\"roc-lang/unicode\",\"state\":\"active\",\"state_at\":1699999000000,\"successor\":null}]}",
	"{\"releases\":[{\"group\":\"github.com/roc-lang/unicode/releases/download/{v}/\",\"hash\":\"1thX6LZfHDZZKUs92febYZhYRcXddmzfzF2NvTkPNE\",\"log_index\":2,\"published_at\":1700000100000,\"repo\":\"roc-lang/unicode\",\"roc_version\":\"0.1.0\",\"series\":\"4\",\"tag\":\"4.2.0\",\"url\":\"https://github.com/roc-lang/unicode/releases/download/4.2.0/1thX6LZfHDZZKUs92febYZhYRcXddmzfzF2NvTkPNE.tar.zst\",\"version\":\"4.2.0\",\"withdrawn\":null,\"yank_reason\":null,\"yanked\":false},{\"group\":\"github.com/roc-lang/unicode/releases/download/{v}/\",\"hash\":\"JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3\",\"log_index\":4,\"published_at\":1700000300000,\"repo\":\"roc-lang/unicode\",\"roc_version\":null,\"series\":\"4\",\"tag\":\"4.3.0\",\"url\":\"https://github.com/roc-lang/unicode/releases/download/4.3.0/JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3.tar.zst\",\"version\":\"4.3.0\",\"withdrawn\":\"edited\",\"yank_reason\":null,\"yanked\":false}],\"checked\":{\"checked_at\":1767222000000,\"name\":\"roc-lang/unicode\",\"stale\":false},\"repos\":[{\"name\":\"roc-lang/unicode\",\"state\":\"active\",\"state_at\":1699999000000,\"successor\":null}]}",
	"{\"releases\":[{\"group\":\"github.com/roc-lang/unicode/releases/download/{v}/\",\"hash\":\"US517G5965aydkZ46HS38QLi7UQiSojurfbQfKCELFx\",\"log_index\":1,\"published_at\":1700000000000,\"repo\":\"roc-lang/unicode\",\"roc_version\":null,\"series\":\"0.25\",\"tag\":\"0.25.1\",\"url\":\"https://github.com/roc-lang/unicode/releases/download/0.25.1/US517G5965aydkZ46HS38QLi7UQiSojurfbQfKCELFx.tar.zst\",\"version\":\"0.25.1\",\"withdrawn\":null,\"yank_reason\":null,\"yanked\":false}],\"checked\":{\"checked_at\":1767222000000,\"name\":\"roc-lang/unicode\",\"stale\":false},\"repos\":[{\"name\":\"roc-lang/unicode\",\"state\":\"active\",\"state_at\":1699999000000,\"successor\":null}]}",
	"{\"releases\":[],\"checked\":null,\"repos\":[]}",
]

# Index.Detail: reads/ap2-artifact.
detail_bodies : List(Str)
detail_bodies = [
	"{\"artifact\":{\"deps\":[{\"alias\":\"a\",\"group\":\"github.com/roc-lang/unicode/releases/download/{v}/\",\"hash\":\"US517G5965aydkZ46HS38QLi7UQiSojurfbQfKCELFx\",\"series\":\"0.25\",\"url\":\"https://github.com/roc-lang/unicode/releases/download/0.25.1/US517G5965aydkZ46HS38QLi7UQiSojurfbQfKCELFx.tar.zst\",\"version\":\"0.25.1\"},{\"alias\":\"b\",\"group\":\"github.com/roc-lang/unicode/releases/download/v{v}/\",\"hash\":\"JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3\",\"series\":\"4\",\"url\":\"https://github.com/roc-lang/unicode/releases/download/v4.1.0/JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3.tar.zst\",\"version\":\"4.1.0\"}],\"exposed\":[\"Unicode\",\"Utf\"],\"hash\":\"1thX6LZfHDZZKUs92febYZhYRcXddmzfzF2NvTkPNE\",\"kind\":\"package\",\"platform_hash\":null,\"roc_pin\":null,\"size\":12345,\"target_names\":[]},\"releases\":[{\"group\":\"github.com/roc-lang/unicode/releases/download/{v}/\",\"hash\":\"1thX6LZfHDZZKUs92febYZhYRcXddmzfzF2NvTkPNE\",\"log_index\":2,\"published_at\":1700000100000,\"repo\":\"roc-lang/unicode\",\"roc_version\":\"0.1.0\",\"series\":\"4\",\"tag\":\"4.2.0\",\"url\":\"https://github.com/roc-lang/unicode/releases/download/4.2.0/1thX6LZfHDZZKUs92febYZhYRcXddmzfzF2NvTkPNE.tar.zst\",\"version\":\"4.2.0\",\"withdrawn\":null,\"yank_reason\":null,\"yanked\":false}],\"repos\":[{\"name\":\"roc-lang/unicode\",\"state\":\"active\",\"state_at\":1699999000000,\"successor\":null}]}",
	"{\"artifact\":{\"deps\":[],\"exposed\":[\"Two\"],\"hash\":\"JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3\",\"kind\":\"package\",\"platform_hash\":null,\"roc_pin\":null,\"size\":222,\"target_names\":[]},\"releases\":[{\"group\":\"github.com/roc-lang/unicode/releases/download/v{v}/\",\"hash\":\"JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3\",\"log_index\":3,\"published_at\":1700000200000,\"repo\":\"roc-lang/unicode\",\"roc_version\":null,\"series\":\"4\",\"tag\":\"v4.1.0\",\"url\":\"https://github.com/roc-lang/unicode/releases/download/v4.1.0/JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3.tar.zst\",\"version\":\"4.1.0\",\"withdrawn\":null,\"yank_reason\":null,\"yanked\":false},{\"group\":\"github.com/roc-lang/unicode/releases/download/{v}/\",\"hash\":\"JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3\",\"log_index\":4,\"published_at\":1700000300000,\"repo\":\"roc-lang/unicode\",\"roc_version\":null,\"series\":\"4\",\"tag\":\"4.3.0\",\"url\":\"https://github.com/roc-lang/unicode/releases/download/4.3.0/JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3.tar.zst\",\"version\":\"4.3.0\",\"withdrawn\":\"edited\",\"yank_reason\":null,\"yanked\":false}],\"repos\":[{\"name\":\"roc-lang/unicode\",\"state\":\"active\",\"state_at\":1699999000000,\"successor\":null}]}",
	"{\"artifact\":{\"deps\":[],\"exposed\":[],\"hash\":\"cGfHiC6Kgg3FpFZvgwGcswsCRtp4aBP2fzuXRQPizuN\",\"kind\":\"platform\",\"platform_hash\":null,\"roc_pin\":\"nightly-2026-10-31-f7bef6b\",\"size\":99,\"target_names\":[\"wasm32\",\"x64linux\"]},\"releases\":[{\"group\":\"github.com/roc-lang/other/releases/download/{v}/\",\"hash\":\"cGfHiC6Kgg3FpFZvgwGcswsCRtp4aBP2fzuXRQPizuN\",\"log_index\":6,\"published_at\":1700000500000,\"repo\":\"roc-lang/other\",\"roc_version\":null,\"series\":\"2\",\"tag\":\"2.0.0\",\"url\":\"https://github.com/roc-lang/other/releases/download/2.0.0/cGfHiC6Kgg3FpFZvgwGcswsCRtp4aBP2fzuXRQPizuN.tar.zst\",\"version\":\"2.0.0\",\"withdrawn\":null,\"yank_reason\":null,\"yanked\":false}],\"repos\":[{\"name\":\"roc-lang/other\",\"state\":\"moved\",\"state_at\":1699999500000,\"successor\":\"roc-lang/moved\"}]}",
	"{\"artifact\":{\"deps\":[],\"exposed\":[],\"hash\":\"EWmDvi3hhz86LYi2NcD6YUp18DeeB5gDkwJzde3MgF9A\",\"kind\":\"app\",\"platform_hash\":\"cGfHiC6Kgg3FpFZvgwGcswsCRtp4aBP2fzuXRQPizuN\",\"roc_pin\":null,\"size\":7,\"target_names\":[]},\"releases\":[{\"group\":\"example.com/pkg/{v}/\",\"hash\":\"EWmDvi3hhz86LYi2NcD6YUp18DeeB5gDkwJzde3MgF9A\",\"log_index\":5,\"published_at\":1700000400000,\"repo\":null,\"roc_version\":null,\"series\":\"1\",\"tag\":null,\"url\":\"https://example.com/pkg/1.0.0/EWmDvi3hhz86LYi2NcD6YUp18DeeB5gDkwJzde3MgF9A.tar.zst\",\"version\":\"1.0.0\",\"withdrawn\":null,\"yank_reason\":null,\"yanked\":false}],\"repos\":[]}",
]

# Index.Page: the `releases` and `repos` of the ap2 bodies (the W2 cases of R-AP14 compare JSON, not bytes), and the empty page.
page_bodies : List(Str)
page_bodies = [
	"{\"releases\":[{\"group\":\"github.com/roc-lang/unicode/releases/download/{v}/\",\"hash\":\"1thX6LZfHDZZKUs92febYZhYRcXddmzfzF2NvTkPNE\",\"log_index\":2,\"published_at\":1700000100000,\"repo\":\"roc-lang/unicode\",\"roc_version\":\"0.1.0\",\"series\":\"4\",\"tag\":\"4.2.0\",\"url\":\"https://github.com/roc-lang/unicode/releases/download/4.2.0/1thX6LZfHDZZKUs92febYZhYRcXddmzfzF2NvTkPNE.tar.zst\",\"version\":\"4.2.0\",\"withdrawn\":null,\"yank_reason\":null,\"yanked\":false}],\"repos\":[{\"name\":\"roc-lang/unicode\",\"state\":\"active\",\"state_at\":1699999000000,\"successor\":null}]}",
	"{\"releases\":[{\"group\":\"github.com/roc-lang/unicode/releases/download/v{v}/\",\"hash\":\"JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3\",\"log_index\":3,\"published_at\":1700000200000,\"repo\":\"roc-lang/unicode\",\"roc_version\":null,\"series\":\"4\",\"tag\":\"v4.1.0\",\"url\":\"https://github.com/roc-lang/unicode/releases/download/v4.1.0/JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3.tar.zst\",\"version\":\"4.1.0\",\"withdrawn\":null,\"yank_reason\":null,\"yanked\":false},{\"group\":\"github.com/roc-lang/unicode/releases/download/{v}/\",\"hash\":\"JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3\",\"log_index\":4,\"published_at\":1700000300000,\"repo\":\"roc-lang/unicode\",\"roc_version\":null,\"series\":\"4\",\"tag\":\"4.3.0\",\"url\":\"https://github.com/roc-lang/unicode/releases/download/4.3.0/JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3.tar.zst\",\"version\":\"4.3.0\",\"withdrawn\":\"edited\",\"yank_reason\":null,\"yanked\":false}],\"repos\":[{\"name\":\"roc-lang/unicode\",\"state\":\"active\",\"state_at\":1699999000000,\"successor\":null}]}",
	"{\"releases\":[{\"group\":\"github.com/roc-lang/other/releases/download/{v}/\",\"hash\":\"cGfHiC6Kgg3FpFZvgwGcswsCRtp4aBP2fzuXRQPizuN\",\"log_index\":6,\"published_at\":1700000500000,\"repo\":\"roc-lang/other\",\"roc_version\":null,\"series\":\"2\",\"tag\":\"2.0.0\",\"url\":\"https://github.com/roc-lang/other/releases/download/2.0.0/cGfHiC6Kgg3FpFZvgwGcswsCRtp4aBP2fzuXRQPizuN.tar.zst\",\"version\":\"2.0.0\",\"withdrawn\":null,\"yank_reason\":null,\"yanked\":false}],\"repos\":[{\"name\":\"roc-lang/other\",\"state\":\"moved\",\"state_at\":1699999500000,\"successor\":\"roc-lang/moved\"}]}",
	"{\"releases\":[{\"group\":\"example.com/pkg/{v}/\",\"hash\":\"EWmDvi3hhz86LYi2NcD6YUp18DeeB5gDkwJzde3MgF9A\",\"log_index\":5,\"published_at\":1700000400000,\"repo\":null,\"roc_version\":null,\"series\":\"1\",\"tag\":null,\"url\":\"https://example.com/pkg/1.0.0/EWmDvi3hhz86LYi2NcD6YUp18DeeB5gDkwJzde3MgF9A.tar.zst\",\"version\":\"1.0.0\",\"withdrawn\":null,\"yank_reason\":null,\"yanked\":false}],\"repos\":[]}",
	"{\"releases\":[],\"repos\":[]}",
]

# Toolchain.Page: toolchains/get-query (slice 109) with `size` added after `sha256` (slice 104h).
toolchain_page_bodies : List(Str)
toolchain_page_bodies = [
	"{\"toolchains\":[{\"tag\":\"nightly-2026-10-20-7a8a800\",\"target\":\"linux_arm64\",\"asset_name\":\"roc_nightly-linux_arm64-2026-10-20-7a8a800.tar.gz\",\"sha256\":\"0000000000000000000000000000000000000000000000000000000000000001\",\"size\":1000001,\"published_at\":1792508400000,\"log_index\":1},{\"tag\":\"nightly-2026-10-20-7a8a800\",\"target\":\"linux_x86_64\",\"asset_name\":\"roc_nightly-linux_x86_64-2026-10-20-7a8a800.tar.gz\",\"sha256\":\"0000000000000000000000000000000000000000000000000000000000000002\",\"size\":1000002,\"published_at\":1792508400000,\"log_index\":2},{\"tag\":\"nightly-2026-10-21-5349569\",\"target\":\"linux_arm64\",\"asset_name\":\"roc_nightly-linux_arm64-2026-10-21-5349569.tar.gz\",\"sha256\":\"0000000000000000000000000000000000000000000000000000000000000003\",\"size\":1000003,\"published_at\":1792594800000,\"log_index\":3},{\"tag\":\"nightly-2026-10-20-7a8a800\",\"target\":\"windows_x86_64\",\"asset_name\":\"roc_nightly-windows_x86_64-2026-10-20-7a8a800.zip\",\"sha256\":\"0000000000000000000000000000000000000000000000000000000000000004\",\"size\":1000004,\"published_at\":1792508400000,\"log_index\":4},{\"tag\":\"nightly-2026-10-21-5349569\",\"target\":\"linux_x86_64\",\"asset_name\":\"roc_nightly-linux_x86_64-2026-10-21-5349569.tar.gz\",\"sha256\":\"0000000000000000000000000000000000000000000000000000000000000005\",\"size\":1000005,\"published_at\":1792594800000,\"log_index\":5},{\"tag\":\"nightly-2026-10-21-5349569\",\"target\":\"windows_x86_64\",\"asset_name\":\"roc_nightly-windows_x86_64-2026-10-21-5349569.zip\",\"sha256\":\"0000000000000000000000000000000000000000000000000000000000000006\",\"size\":1000006,\"published_at\":1792594800000,\"log_index\":6}],\"more\":false}",
	"{\"toolchains\":[{\"tag\":\"nightly-2026-10-20-7a8a800\",\"target\":\"windows_x86_64\",\"asset_name\":\"roc_nightly-windows_x86_64-2026-10-20-7a8a800.zip\",\"sha256\":\"0000000000000000000000000000000000000000000000000000000000000004\",\"size\":1000004,\"published_at\":1792508400000,\"log_index\":4},{\"tag\":\"nightly-2026-10-21-5349569\",\"target\":\"linux_x86_64\",\"asset_name\":\"roc_nightly-linux_x86_64-2026-10-21-5349569.tar.gz\",\"sha256\":\"0000000000000000000000000000000000000000000000000000000000000005\",\"size\":1000005,\"published_at\":1792594800000,\"log_index\":5},{\"tag\":\"nightly-2026-10-21-5349569\",\"target\":\"windows_x86_64\",\"asset_name\":\"roc_nightly-windows_x86_64-2026-10-21-5349569.zip\",\"sha256\":\"0000000000000000000000000000000000000000000000000000000000000006\",\"size\":1000006,\"published_at\":1792594800000,\"log_index\":6}],\"more\":false}",
	"{\"toolchains\":[],\"more\":false}",
]

# Toolchain.Put: toolchains/pu-new-tag and oidc/tp3-jwt-strict (slice 109) with `size` added (slice 104h).
toolchain_put_bodies : List(Str)
toolchain_put_bodies = [
	"{\"toolchains\":[{\"tag\":\"nightly-2026-10-21-5349569\",\"target\":\"linux_arm64\",\"asset_name\":\"roc_nightly-linux_arm64-2026-10-21-5349569.tar.gz\",\"sha256\":\"cb6cbe82e45ba284d5b01910e8e91a978701ffed3c2baf2c9a88baa4adc369f5\",\"size\":1000001,\"published_at\":1792594866000,\"log_index\":1},{\"tag\":\"nightly-2026-10-21-5349569\",\"target\":\"linux_x86_64\",\"asset_name\":\"roc_nightly-linux_x86_64-2026-10-21-5349569.tar.gz\",\"sha256\":\"70346ac60dd0b0507881447c5b47aed799fd1bea01c50bac56f82ed96897f4df\",\"size\":1000002,\"published_at\":1792594866000,\"log_index\":2},{\"tag\":\"nightly-2026-10-21-5349569\",\"target\":\"macos_apple_silicon\",\"asset_name\":\"roc_nightly-macos_apple_silicon-2026-10-21-5349569.tar.gz\",\"sha256\":\"a8a81b5436c69eb5bf14ddc48bd9f0ef71326fd485340a4a1a7a683db442e5a6\",\"size\":1000003,\"published_at\":1792594866000,\"log_index\":3},{\"tag\":\"nightly-2026-10-21-5349569\",\"target\":\"macos_x86_64\",\"asset_name\":\"roc_nightly-macos_x86_64-2026-10-21-5349569.tar.gz\",\"sha256\":\"31b1c15f5627a7144e66c26695bd3fd11c1dac2f619c256398f9134c7cc9bec6\",\"size\":1000004,\"published_at\":1792594866000,\"log_index\":4},{\"tag\":\"nightly-2026-10-21-5349569\",\"target\":\"windows_x86_64\",\"asset_name\":\"roc_nightly-windows_x86_64-2026-10-21-5349569.zip\",\"sha256\":\"105026125c36b57b17201380c7d15dafbfd9ce663767d52989e11ffd53d2bcf7\",\"size\":1000005,\"published_at\":1792594866000,\"log_index\":5}]}",
	"{\"toolchains\":[{\"tag\":\"nightly-2026-10-31-f7bef6b\",\"target\":\"linux_x86_64\",\"asset_name\":\"roc_nightly-linux_x86_64-2026-10-31-f7bef6b.tar.gz\",\"sha256\":\"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee\",\"size\":1000001,\"published_at\":1793448000000,\"log_index\":1}]}",
]

# Short.Matches: shorts/sn1-table and shorts/ap33-moved (slice 107).
matches_bodies : List(Str)
matches_bodies = [
	"{\"matches\":[{\"matches\":[{\"first_log_index\":1,\"name\":\"lukewilliamboswell/roc-parser\",\"state\":\"active\"}],\"short\":\"parser\"}]}",
	"{\"matches\":[{\"matches\":[{\"first_log_index\":1,\"name\":\"lukewilliamboswell/roc-parser\",\"state\":\"active\"}],\"short\":\"roc-parser\"}]}",
	"{\"matches\":[{\"matches\":[],\"short\":\"pars\"}]}",
	"{\"matches\":[{\"matches\":[{\"first_log_index\":5,\"moved_from\":\"olduser/roc-json\",\"name\":\"acme/roc-json\",\"state\":\"active\"}],\"short\":\"json\"}]}",
	"{\"matches\":[{\"matches\":[{\"first_log_index\":10,\"moved_from\":\"a/chain1\",\"name\":\"d/final\",\"state\":\"active\"}],\"short\":\"chain1\"}]}",
	"{\"matches\":[{\"matches\":[{\"first_log_index\":11,\"moved_from\":\"x/lone\",\"name\":\"n/four\",\"state\":\"active\"}],\"short\":\"lone\"}]}",
	"{\"matches\":[{\"matches\":[{\"first_log_index\":12,\"moved_from\":\"q/old-lost\",\"name\":\"r/lost\",\"state\":\"missing\"}],\"short\":\"old-lost\"}]}",
	"{\"matches\":[{\"matches\":[{\"first_log_index\":14,\"moved_from\":\"y/roc-sort\",\"name\":\"c/other-end\",\"state\":\"active\"},{\"first_log_index\":15,\"name\":\"m/sort\",\"state\":\"active\"}],\"short\":\"sort\"}]}",
	"{\"matches\":[{\"matches\":[],\"short\":\"ghostmove\"}]}",
]

# Short.Packages: shorts/sn5-search (slice 107).
packages_bodies : List(Str)
packages_bodies = [
	"{\"packages\":[{\"first_log_index\":31,\"name\":\"m/roc-ranked\",\"state\":\"moved\"},{\"first_log_index\":28,\"name\":\"z/ranked\",\"state\":\"active\"},{\"first_log_index\":1,\"name\":\"own/ranked-01\",\"state\":\"active\"},{\"first_log_index\":2,\"name\":\"own/ranked-02\",\"state\":\"active\"},{\"first_log_index\":3,\"name\":\"own/ranked-03\",\"state\":\"active\"},{\"first_log_index\":4,\"name\":\"own/ranked-04\",\"state\":\"active\"},{\"first_log_index\":5,\"name\":\"own/ranked-05\",\"state\":\"active\"},{\"first_log_index\":6,\"name\":\"own/ranked-06\",\"state\":\"active\"},{\"first_log_index\":7,\"name\":\"own/ranked-07\",\"state\":\"active\"},{\"first_log_index\":8,\"name\":\"own/ranked-08\",\"state\":\"active\"},{\"first_log_index\":9,\"name\":\"own/ranked-09\",\"state\":\"active\"},{\"first_log_index\":10,\"name\":\"own/ranked-10\",\"state\":\"active\"},{\"first_log_index\":11,\"name\":\"own/ranked-11\",\"state\":\"active\"},{\"first_log_index\":12,\"name\":\"own/ranked-12\",\"state\":\"active\"},{\"first_log_index\":13,\"name\":\"own/ranked-13\",\"state\":\"active\"},{\"first_log_index\":14,\"name\":\"own/ranked-14\",\"state\":\"active\"},{\"first_log_index\":15,\"name\":\"own/ranked-15\",\"state\":\"active\"},{\"first_log_index\":16,\"name\":\"own/ranked-16\",\"state\":\"active\"},{\"first_log_index\":17,\"name\":\"own/ranked-17\",\"state\":\"active\"},{\"first_log_index\":18,\"name\":\"own/ranked-18\",\"state\":\"active\"}]}",
	"{\"packages\":[{\"first_log_index\":31,\"name\":\"m/roc-ranked\",\"state\":\"moved\"}]}",
]

# Result of a decode as a Bool: Err(BadJson)
bad_with : (Str -> Try(a, [BadJson(Str)])), Str -> Bool
bad_with = |decode, text| match decode(text) {
	Err(BadJson(_)) => Bool.True
	_ => Bool.False
}

# decode then encode gives the same bytes
same : (Str -> Try(a, [BadJson(Str)])), (a -> Str), Str -> Bool
same = |decode, encode, text| decode(text).map_ok(encode) == Ok(text)

# R-AP73, R-AP53, R-AP1, R-AP13: the release answers. The 5 Worker bodies round trip to the same bytes. The first has a `checked` item and one `repos` item. `checked` null is a value.
expect {
	first = Index.decode_releases(releases_bodies.first() ?? "")
	empty = Index.decode_releases(js("{'releases':[],'checked':null,'repos':[]}"))
	releases_bodies.all(|b| same(Index.decode_releases, Index.encode_releases, b)) and (
		match first {
			Ok(a) => a.releases.len() == 4 and a.checked == Ok({ name: "roc-lang/unicode", checked_at: Ok(1767222000000), stale: Bool.False }) and a.repos.len() == 1
			_ => Bool.False
		}
	) and empty == Ok({ releases: [], checked: Err(None), repos: [] }) and Index.encode_releases({ releases: [], checked: Err(None), repos: [] }) == js("{'releases':[],'checked':null,'repos':[]}")
}

# R-AP73, R-AP53, R-AP14, R-AP2: the page and the artifact answer: same bytes after a round trip, with the members in the order of the table.
expect {
	empty_page = Index.encode_page({ releases: [], repos: [] })
	page_bodies.all(|b| same(Index.decode_page, Index.encode_page, b)) and detail_bodies.all(|b| same(Index.decode_detail, Index.encode_detail, b)) and empty_page == js("{'releases':[],'repos':[]}") and detail_bodies.all(|b| b.starts_with(js("{'artifact':{"))) and (
		match Index.decode_detail(detail_bodies.first() ?? "") {
			Ok(a) => a.artifact.hash == "1thX6LZfHDZZKUs92febYZhYRcXddmzfzF2NvTkPNE" and a.artifact.deps.len() == 2 and a.releases.len() == 1
			_ => Bool.False
		}
	)
}

# R-AP73, R-AP51, R-AP44: a missing or null required member, a wrong type, a bad release inside, are BadJson. An unknown member is ignored.
expect {
	cases = [
		"{'releases':[],'repos':[]}",
		"{'releases':[],'checked':null}",
		"{'releases':null,'checked':null,'repos':[]}",
		"{'releases':[],'checked':null,'repos':null}",
		"{'releases':[{'log_index':1}],'checked':null,'repos':[]}",
		"{'releases':[],'checked':{'name':'a'},'repos':[]}",
		"[]",
	]
	ok = Index.decode_releases(js("{'releases':[],'checked':null,'repos':[],'future':{'a':1}}"))
	cases.all(|c| bad_with(Index.decode_releases, js(c))) and bad_with(Index.decode_page, js("{'releases':[]}")) and bad_with(Index.decode_detail, js("{'releases':[],'repos':[]}")) and bad_with(Index.decode_detail, js("{'artifact':null,'releases':[],'repos':[]}")) and ok == Ok({ releases: [], checked: Err(None), repos: [] })
}

# R-AP73, R-AP5, R-AP6, R-AP49 (row of R-RE4): the toolchain answers. The Worker bodies (page of 1000-row fixtures, a put, a row) round trip to the same bytes. A row has its members in the order tag, target, asset_name, sha256, size, published_at, log_index.
expect {
	row = { tag: "nightly-2026-10-20-7a8a800", target: "linux_arm64", asset_name: "a \"q\".tar.gz", sha256: "00", size: 52428800, published_at: 1792508400000, log_index: 1 }
	row_text = Toolchain.encode_row(row)
	toolchain_page_bodies.all(|b| same(Toolchain.decode_page, Toolchain.encode_page, b)) and toolchain_put_bodies.all(|b| same(Toolchain.decode_put, Toolchain.encode_put, b)) and row_text == "{\"tag\":\"nightly-2026-10-20-7a8a800\",\"target\":\"linux_arm64\",\"asset_name\":\"a \\\"q\\\".tar.gz\",\"sha256\":\"00\",\"size\":52428800,\"published_at\":1792508400000,\"log_index\":1}" and Toolchain.decode_row(row_text) == Ok(row) and Toolchain.encode_page({ toolchains: [], more: Bool.False }) == js("{'toolchains':[],'more':false}") and Toolchain.encode_page({ toolchains: [row], more: Bool.True }) == js("{'toolchains':[${row_text}],'more':true}") and Toolchain.encode_put({ toolchains: [row] }) == js("{'toolchains':[${row_text}]}")
}

# R-AP73, R-AP51: a missing `more`, `toolchains` or row member, a negative or fractional number, a text for `more`, are BadJson.
expect {
	r = "{'tag':'t','target':'x','asset_name':'a','sha256':'s','size':5,'published_at':1,'log_index':1}"
	cases = [
		"{'toolchains':[]}",
		"{'more':true}",
		"{'toolchains':null,'more':true}",
		"{'toolchains':[],'more':'yes'}",
		"{'toolchains':[{'tag':'t'}],'more':false}",
		"{'toolchains':[${r.replace_first("'published_at':1,", "'published_at':-1,")}],'more':false}",
		"{'toolchains':[${r.replace_first("'log_index':1", "'log_index':1.5")}],'more':false}",
		"{'toolchains':[${r.replace_first("'sha256':'s',", "")}],'more':false}",
		"{'toolchains':[${r.replace_first("'size':5,", "")}],'more':false}",
	]
	cases.all(|c| bad_with(Toolchain.decode_page, js(c))) and bad_with(Toolchain.decode_put, js("{'more':false}")) and Toolchain.decode_page(js("{'toolchains':[${r}],'more':false,'future':1}")) == Ok({ toolchains: [{ tag: "t", target: "x", asset_name: "a", sha256: "s", size: 5, published_at: 1, log_index: 1 }], more: Bool.False })
}

# R-AP73, R-AP7, R-SN6, R-AP33: the short names. The Worker bodies round trip to the same bytes. `moved_from` is left out when there is none. An empty list is a value.
expect {
	moved = Short.decode_matches(js("{'matches':[{'matches':[{'first_log_index':5,'moved_from':'olduser/roc-json','name':'acme/roc-json','state':'active'}],'short':'json'}]}"))
	plain = { name: "a/b", first_log_index: 1, state: Missing, moved_from: Err(None) }
	matches_bodies.all(|b| same(Short.decode_matches, Short.encode_matches, b)) and packages_bodies.all(|b| same(Short.decode_packages, Short.encode_packages, b)) and moved == Ok({ matches: [{ short: "json", matches: [{ name: "acme/roc-json", first_log_index: 5, state: Active, moved_from: Ok("olduser/roc-json") }] }] }) and Short.encode_matches({ matches: [{ short: "x", matches: [plain] }] }) == js("{'matches':[{'matches':[{'first_log_index':1,'name':'a/b','state':'missing'}],'short':'x'}]}") and Short.encode_matches({ matches: [{ short: "pars", matches: [] }] }) == js("{'matches':[{'matches':[],'short':'pars'}]}") and Short.encode_matches({ matches: [] }) == js("{'matches':[]}") and Short.encode_packages({ found: [] }) == js("{'packages':[]}") and Short.decode_packages(js("{'packages':[{'first_log_index':3,'name':'m/n','state':'moved'}]}")) == Ok({ found: [{ name: "m/n", first_log_index: 3, state: Moved }] })
}

# R-AP73, R-AP51: `moved_from` null is none (and is left out again on encode). A state that is not active, missing or moved, and a missing member, are BadJson.
expect {
	null_from = Short.decode_matches(js("{'matches':[{'matches':[{'first_log_index':1,'moved_from':null,'name':'a/b','state':'active'}],'short':'x'}]}"))
	back = null_from.map_ok(Short.encode_matches)
	bad_m = |c| bad_with(Short.decode_matches, js(c))
	bad_p = |c| bad_with(Short.decode_packages, js(c))
	back == Ok(js("{'matches':[{'matches':[{'first_log_index':1,'name':'a/b','state':'active'}],'short':'x'}]}")) and bad_m("{'matches':[{'matches':[{'first_log_index':1,'name':'a/b','state':'gone'}],'short':'x'}]}") and bad_m("{'matches':[{'matches':[{'first_log_index':1,'name':'a/b','state':'Active'}],'short':'x'}]}") and bad_m("{'matches':[{'matches':[{'name':'a/b','state':'active'}],'short':'x'}]}") and bad_m("{'matches':[{'matches':[]}]}") and bad_m("{'matches':null}") and bad_m("{}") and bad_p("{'packages':[{'name':'a/b','state':'active'}]}") and bad_p("{'packages':[{'first_log_index':1,'name':'a/b','state':'x'}]}") and bad_p("{'packages':null}") and bad_p("{}")
}

# R-AP73, R-AP35, R-AP37, R-AP50, R-AP51, R-CT10: the account types. The encoders write the members in alphabetical order (a proposal, TW24). The two times of the tracker are required and may be null.
expect {
	who = { id: 12345, login: "ada" }
	tracker = { account: who, machines: 2, counted: 10, first: 4, agreed: 3, disagreed: 1, unconfirmed: 0, first_time: Ok(1760000000000), last_time: Ok(1760000100000) }
	fresh = { ..tracker, machines: 0, counted: 0, first: 0, agreed: 0, disagreed: 0, first_time: Err(None), last_time: Err(None) }
	t_text = Account.encode_tracker(tracker)
	f_text = Account.encode_tracker(fresh)
	token = { token: "a.b.c", expires_at: 1760003600000, account: who }
	t_text == js("{'account':{'id':12345,'login':'ada'},'agreed':3,'counted':10,'disagreed':1,'first':4,'first_time':1760000000000,'last_time':1760000100000,'machines':2,'unconfirmed':0}") and f_text.contains(js("'first_time':null,'last_time':null")) and Account.decode_tracker(t_text) == Ok(tracker) and Account.decode_tracker(f_text) == Ok(fresh) and Account.encode_token(token) == js("{'account':{'id':12345,'login':'ada'},'expires_at':1760003600000,'token':'a.b.c'}") and Account.decode_token(Account.encode_token(token)) == Ok(token) and Account.encode_login({ github_token: "gho_x" }) == js("{'github_token':'gho_x'}") and Account.decode_login(js("{'github_token':'gho_x','future':1}")) == Ok({ github_token: "gho_x" })
}

# R-AP73, R-AP51: a missing time member, a missing count, a null count, a missing token member, a missing `github_token`, are BadJson.
expect {
	good = js("{'account':{'id':1,'login':'a'},'agreed':0,'counted':0,'disagreed':0,'first':0,'first_time':null,'last_time':null,'machines':0,'unconfirmed':0}")
	cut = |m| bad_with(Account.decode_tracker, good.replace_first(js("'${m}':null,"), "").replace_first(js(",'${m}':null"), ""))
	cut("first_time") and cut("last_time") and good.replace_first(js("'agreed':0,"), "") != good and bad_with(Account.decode_tracker, good.replace_first(js("'agreed':0,"), "")) and bad_with(Account.decode_tracker, good.replace_first(js("'agreed':0"), js("'agreed':null"))) and bad_with(Account.decode_tracker, good.replace_first(js("'login':'a'"), js("'login':null"))) and bad_with(Account.decode_token, js("{'account':{'id':1,'login':'a'},'token':'t'}")) and bad_with(Account.decode_token, js("{'expires_at':1,'token':'t'}")) and bad_with(Account.decode_login, "{}") and bad_with(Account.decode_login, js("{'github_token':null}"))
}

# Slice 104h, R-AP80, R-AP51: `size` is required in a toolchain row, in the page, the put and the row alone. A missing `size`, `null`, a text, a negative number, a fraction, an object and a list are a decode error. A row has no `url` member: an unknown `url` is ignored.
expect {
	r = "{'tag':'t','target':'x','asset_name':'a','sha256':'s','size':5,'published_at':1,'log_index':1}"
	with_size = |v| r.replace_first("'size':5", "'size':${v}")
	wrong = ["null", "'5'", "-5", "5.5", "{}", "[5]", "true"]
	page = |row| js("{'toolchains':[${row}],'more':false}")
	row_ok = { tag: "t", target: "x", asset_name: "a", sha256: "s", size: 5, published_at: 1, log_index: 1 }
	wrong.all(|v| bad_with(Toolchain.decode_row, js(with_size(v)))) and wrong.all(|v| bad_with(Toolchain.decode_page, page(js(with_size(v))))) and wrong.all(|v| bad_with(Toolchain.decode_put, js("{'toolchains':[${with_size(v)}]}"))) and bad_with(Toolchain.decode_row, js(r.replace_first("'size':5,", ""))) and bad_with(Toolchain.decode_put, js("{'toolchains':[${r.replace_first("'size':5,", "")}]}")) and Toolchain.decode_row(js(r)) == Ok(row_ok) and Toolchain.decode_row(js(r.replace_first("{", "{'url':'https://x/y',"))) == Ok(row_ok) and !Toolchain.encode_row(row_ok).contains("url") and Toolchain.encode_row(row_ok) == js("{'tag':'t','target':'x','asset_name':'a','sha256':'s','size':5,'published_at':1,'log_index':1}")
}
