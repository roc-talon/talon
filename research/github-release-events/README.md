# GitHub release events for a late asset

Question: does GitHub send a webhook event when a workflow uploads an asset to a release that is already published? Registry 7, R-PU13 depends on the answer. The schemas say no (Registry 7, evidence table). This test checks what GitHub sends.

Status: not run. It needs a person: it creates a repository and a webhook, which are outward actions.

## Setup

| Step | Action |
| --- | --- |
| 1 | Create a private test repository, for example `<you>/talon-release-events`. |
| 2 | Open a receiver: `https://webhook.site` gives a URL, or run `gh webhook forward --repo=<you>/talon-release-events --events='*' --url=http://localhost:8080` with a local listener (needs the extension `gh extension install cli/gh-webhook`). |
| 3 | Add a repository webhook to that URL, content type `application/json`, with "Send me everything". |
| 4 | `git commit --allow-empty -m t && git tag 1.0.0 && git push origin HEAD 1.0.0` |

## Cases

| # | Commands | Record |
| --- | --- | --- |
| A | `gh release create 1.0.0 --title t --notes t`, wait 1 min, then `gh release upload 1.0.0 x.tar.zst` | Each event with its `X-GitHub-Event` header and `action` after the upload |
| B | `gh release create 1.0.1 --draft`, `gh release upload 1.0.1 x.tar.zst`, `gh release edit 1.0.1 --draft=false` | The events, and the asset count in the `published` payload |
| C | `gh release delete-asset 1.0.0 x.tar.zst`, then `gh release upload 1.0.0 y.tar.zst` (a re-released tag, R-PU19, R-PU20) | The events after each command |

## Result

Expected from the schemas: case A gives no event after the upload. Case B gives `published` with 1 asset. Case C gives no event.

Write the result here, with the date, and update the evidence table of Registry 7. Then delete the test repository.
