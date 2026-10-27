#!/usr/bin/env python3
"""Makes the L3 fixture of the compiler list (slice 020, TW14) from a saved copy of the real release list of roc-lang/nightlies.

Usage: python3 -I trim.py <dir with p1.json p2.json ...> <out dir>
The input is the answer of `GET /repos/roc-lang/nightlies/releases?per_page=100&page=N` (saved on 2026-10-22, 338 releases).
The output is `list-page1.json` and `list-page2.json`: 12 real releases in the order of the answer, and 6 fields of each asset
(`id`, `name`, `size`, `digest`, `content_type`, `browser_download_url`). The asset URL has the host of the fake server (`$PORT`, the
fake HTTP server replaces it). The tags show the cases of R-CV1, R-CV2 and R-NS1:

| Tag | Case |
| --- | --- |
| nightly-2026-10-21-5349569, -10-20-7a8a800, -10-19-601b54c, -08-06-61bbb59 | Plain releases. The newest have 10 assets (5 hosts, 2 source archives, 3 wasm files). |
| nightly-2026-09-01-db83307, nightly-2026-09-01-24e3995 | Two nightlies of one date. `published_at` order and tag text order agree. The answer lists the newer first. |
| nightly-2026-July-31-f5556d8 | The month name form |
| nightly-2026-July-23-306abd6, nightly-2026-July-23-fdd77c3 | Two nightlies of one date. `published_at` order is NOT the tag text order. |
| nightly-2026-February-10-c95f04d | The asset names have another sha (`ea7058b`) than the tag |
| nightly-2025-November-03-4215483 | No asset |
| nightly-2025-October-25-c3487d2 | The asset names have another sha (`2b89aee`) |
"""
import glob
import json
import os
import sys

src, out = sys.argv[1], sys.argv[2]
want = [
    ["nightly-2026-10-21-5349569", "nightly-2026-10-20-7a8a800", "nightly-2026-10-19-601b54c", "nightly-2026-09-01-db83307", "nightly-2026-09-01-24e3995", "nightly-2026-08-06-61bbb59"],
    ["nightly-2026-July-31-f5556d8", "nightly-2026-July-23-306abd6", "nightly-2026-July-23-fdd77c3", "nightly-2026-February-10-c95f04d", "nightly-2025-November-03-4215483", "nightly-2025-October-25-c3487d2"],
]
releases = []
for name in sorted(glob.glob(os.path.join(src, "p*.json"))):
    with open(name) as f:
        releases += json.load(f)
by_tag = {r["tag_name"]: r for r in releases}
order = [r["tag_name"] for r in releases]


def trim(r):
    tag = r["tag_name"]
    assets = []
    for a in r["assets"]:
        assets.append({
            "id": a["id"],
            "name": a["name"],
            "size": a["size"],
            "digest": a["digest"],
            "content_type": a["content_type"],
            "browser_download_url": "http://127.0.0.1:$PORT/dl/%s/%s" % (tag, a["name"]),
        })
    return {"tag_name": tag, "draft": r["draft"], "prerelease": r["prerelease"], "published_at": r["published_at"], "assets": assets}


for n, tags in enumerate(want, start=1):
    tags = sorted(tags, key=order.index)
    with open(os.path.join(out, "list-page%d.json" % n), "w") as f:
        json.dump([trim(by_tag[t]) for t in tags], f, indent=1)
        f.write("\n")
