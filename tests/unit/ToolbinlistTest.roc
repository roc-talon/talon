import lib.ToolBinCheck

ToolbinlistTest :: [].{}

# Slice 092 (docs/slices/092-prebuilt-bin-check.md), Design Q239, R-PT20 step 1 in direct mode: the asset digests come from the release list that the command already read (R-DI2), not from a new call. `ToolBinCheck.list_assets` is a proposal for the name of the pure function (TW24). It gives the assets of the release with the tag in the pages of the list, with the rules of `release_assets` (only `sha256:<64 hex>` counts).

h1 = Str.repeat("a", 64)

h2 = Str.repeat("b", 64)

release = |tag, assets| "{\"tag_name\":\"${tag}\",\"draft\":false,\"assets\":[${assets}]}"

asset = |name, digest| "{\"name\":\"${name}\",\"size\":10,\"digest\":${digest}}"

# R-PT20 step 1, Q239: the release with the tag is found in any page. An asset with no valid digest is no binary. Another release of the list does not count.
expect {
	page1 = "[${release("1.1.0", asset("x", "\"sha256:${h2}\""))}]"
	page2 = "[${release("1.0.0", "${asset("a", "\"sha256:${h1}\"")},${asset("b", "null")},${asset("c", "\"sha512:${h1}\"")}")}]"
	ToolBinCheck.list_assets({ pages: [page1, page2], tag: "1.0.0" }) == [{ name: "a", digest: h1 }] and ToolBinCheck.list_assets({ pages: [page1, page2], tag: "1.1.0" }) == [{ name: "x", digest: h2 }]
}

# Q239: no page has the tag, no pages, a release with no `assets`, a page that is no list: no asset, no failure.
expect {
	page = "[${release("1.1.0", asset("x", "\"sha256:${h2}\""))}]"
	ToolBinCheck.list_assets({ pages: [page], tag: "2.0.0" }) == [] and ToolBinCheck.list_assets({ pages: [], tag: "1.1.0" }) == [] and ToolBinCheck.list_assets({ pages: ["[{\"tag_name\":\"1.1.0\"}]"], tag: "1.1.0" }) == [] and ToolBinCheck.list_assets({ pages: ["nope", "{\"tag_name\":\"1.1.0\"}", page], tag: "1.1.0" }) == [{ name: "x", digest: h2 }]
}

# Q239: the first release with the tag wins (the list is newest first and a tag is once in it).
expect {
	p1 = "[${release("1.1.0", asset("first", "\"sha256:${h1}\""))}]"
	p2 = "[${release("1.1.0", asset("second", "\"sha256:${h2}\""))}]"
	ToolBinCheck.list_assets({ pages: [p1, p2], tag: "1.1.0" }) == [{ name: "first", digest: h1 }]
}
