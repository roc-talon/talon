# R-PU25 check: the installation token reads public repositories outside the installation

Date: 2026-11-02T00:17:18Z  
Mode: real (installation token of the App)  
Probe repositories (not in the installation): roc-lang/basic-cli Karakatiza666/roc-semver  
Installation id: 177657685, account roc-talon, repository_selection selected  
Repositories in the installation: roc-talon/talon  
Permissions of the token: {"contents":"read","metadata":"read"}  
Events of the App: ["release","repository"]  

x-ratelimit-limit with no token: 60 (expect 60). With the token: 5000 (expect 5000 or more).

| Read | Repository | Status | x-ratelimit-limit | Remaining before | Remaining after | Verdict | Note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GET /repos/{o}/{r} | roc-lang/basic-cli | 200 | 5000 | 4999 | 4998 | PASS | visibility public |
| GET /repos/{o}/{r} + If-None-Match | roc-lang/basic-cli | 304 | 5000 | 4998 | 4998 | FREE | 304 is free when before = after |
| GET /repos/{o}/{r}/releases | roc-lang/basic-cli | 200 | 5000 | 4998 | 4997 | PASS | 30 releases, drafts listed: 0 |
| GET releases + If-None-Match | roc-lang/basic-cli | 304 | 5000 | 4997 | 5000 | COUNTS | 304 is free when before = after |
| GET /repos/{o}/{r}/releases/tags/{tag} | roc-lang/basic-cli | 200 | 5000 | 5000 | 4999 | PASS | tag 0.26.0 |
| asset: browser_download_url | roc-lang/basic-cli | 206 | - | 4999 | - | PASS | no API call |
| asset: API url, Accept octet-stream | roc-lang/basic-cli | 302 | 5000 | 4999 | 4996 | PASS | redirect to a signed URL; the remaining count of this answer can come from another counter, so it is not used |
| asset: signed URL (no token) | roc-lang/basic-cli | 206 | - | 4999 | - | PASS | no API call |
| GET /repositories/{id} | roc-lang/basic-cli | 200 | 5000 | 4999 | 4998 | PASS | full_name roc-lang/basic-cli, visibility public |
| GET /repositories/{id} + If-None-Match | roc-lang/basic-cli | 304 | 5000 | 4998 | 4998 | FREE | 304 is free when before = after |
| GET /repos/{o}/{r}/contents/ (root) | roc-lang/basic-cli | 200 | 5000 | 4998 | 4997 | PASS | 23 entries |
| GET /repos/{o}/{r}/contents/{path} | roc-lang/basic-cli | 200 | 5000 | 4997 | 4996 | PASS | .envrc |
| same, Accept raw | roc-lang/basic-cli | 200 | 5000 | 4996 | 4995 | PASS | 10 bytes |
| GET /repos/{o}/{r} | Karakatiza666/roc-semver | 200 | 5000 | 4995 | 4994 | PASS | visibility public |
| GET /repos/{o}/{r} + If-None-Match | Karakatiza666/roc-semver | 304 | 5000 | 4994 | 4994 | FREE | 304 is free when before = after |
| GET /repos/{o}/{r}/releases | Karakatiza666/roc-semver | 200 | 5000 | 4994 | 4993 | PASS | 2 releases, drafts listed: 0 |
| GET releases + If-None-Match | Karakatiza666/roc-semver | 304 | 5000 | 4993 | 4993 | FREE | 304 is free when before = after |
| GET /repos/{o}/{r}/releases/tags/{tag} | Karakatiza666/roc-semver | 200 | 5000 | 4993 | 4992 | PASS | tag 0.2.0 |
| asset: browser_download_url | Karakatiza666/roc-semver | 206 | - | 4992 | - | PASS | no API call |
| asset: API url, Accept octet-stream | Karakatiza666/roc-semver | 302 | 5000 | 4992 | 4995 | PASS | redirect to a signed URL; the remaining count of this answer can come from another counter, so it is not used |
| asset: signed URL (no token) | Karakatiza666/roc-semver | 206 | - | 4992 | - | PASS | no API call |
| GET /repositories/{id} | Karakatiza666/roc-semver | 200 | 5000 | 4992 | 4991 | PASS | full_name Karakatiza666/roc-semver, visibility public |
| GET /repositories/{id} + If-None-Match | Karakatiza666/roc-semver | 304 | 5000 | 4991 | 4991 | FREE | 304 is free when before = after |
| GET /repos/{o}/{r}/contents/ (root) | Karakatiza666/roc-semver | 200 | 5000 | 4991 | 4990 | PASS | 9 entries |
| GET /repos/{o}/{r}/contents/{path} | Karakatiza666/roc-semver | 200 | 5000 | 4990 | 4989 | PASS | .gitignore |
| same, Accept raw | Karakatiza666/roc-semver | 200 | 5000 | 4989 | 4988 | PASS | 24 bytes |

Verdicts: PASS and FAIL are for the status. FREE: a 304 left the remaining count the same. COUNTS: a 304 used one request. INFO: not a pass or fail.

Drafts (R-PU23): the release lists above show no draft. This is trivially true for repositories where the App has no write access: GitHub shows drafts only to a reader with push access, so this check cannot test the R-PU23 claim for the installed repository roc-talon/talon. A test needs a draft release in roc-talon/talon.

Result: PASS. The installation token reads public repositories outside the installation. R-PU25 stands.
