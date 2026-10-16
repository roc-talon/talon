# GitHub device flow of the OAuth App `Talon` (Registry 6.1, R-CT8)

Question: does the OAuth App `Talon` (org `roc-talon`, client id `Ov23li2sxWgMaAvjaUbQ`) give a token with no scope through the device flow, with no client secret, and can the token read `GET /user`?

Answer: yes. Checked on 2026-10-16.

## Run

| Command | What it does |
| --- | --- |
| `./check.sh [client_id]` | Asks for a device code, prints the user code, and waits for a person to approve it at `https://github.com/login/device`. Then it reads `GET /user` with the token. It never prints the token. |

Needs `curl` and `sed`. After the run, remove the grant: user Settings, Applications, Authorized OAuth Apps, Talon, Revoke. The script cannot revoke the token, because that needs the client secret, and the app has none (R-CT8 row 2).

## Results

| Step | Result |
| --- | --- |
| `POST /login/device/code` with only `client_id` | A user code, `expires_in` 899 s, `interval` 5 s |
| The page that the person sees | "Talon by Roc Talon wants to access your account. Public data only." |
| `POST /login/oauth/access_token`, with no client secret | A `bearer` token, `scope` empty |
| `GET /user` with the token | `id` and `login` of the account |
| `X-OAuth-Scopes` of that answer | Empty |

So the Worker gets the GitHub user id from one `GET /user` call (R-CT8), and the token can read only public data.
