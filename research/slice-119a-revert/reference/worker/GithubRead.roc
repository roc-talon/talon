## PRIVATE REFERENCE of slice 119a (not for the code agent, TW18).
import pf.Request
import pf.Response
import pf.Body
import pf.Http
import pf.Memo
import pf.Env
import pf.Time
import pf.WebCrypto
import lib.GithubApp

GithubRead :: [].{

	cache : Memo(GithubApp.Token)
	cache = Memo.new("github-read-token", { max_age_ms: 3_600_000 })

	send! : Request => Try(Response, [NoAnswer, Token(GithubApp.Failure)])
	send! = |request| {
		url = request.url()
		token = if (GithubApp.uses_token(url)) token!().map_err(|f| Token(f))? else ""
		headers = GithubApp.read_headers({ url, token })
		sent = headers.fold(request, |r, (name, value)| r.with_header(name, value))
		Http.send!(sent).map_err(|_| NoAnswer)
	}

	token! : () => Try(Str, GithubApp.Failure)
	token! = || {
		held = cache.get!(load!)?
		if GithubApp.usable(held, Time.now_ms!()) {
			Ok(held.token)
		} else {
			cache.clear!()
			fresh = cache.get!(load!)?
			Ok(fresh.token)
		}
	}

	setting! : Str => Try(Str, GithubApp.Failure)
	setting! = |name| Env.var!(name).map_err(|_| NoSetting(name))

	load! : () => Try(GithubApp.Token, GithubApp.Failure)
	load! = || {
		app_id = setting!("GITHUB_APP_ID")?
		installation = setting!("GITHUB_APP_INSTALLATION_ID")?
		secret = Env.secret!("GITHUB_APP_KEY") ? |_| NoSetting("GITHUB_APP_KEY")
		der = GithubApp.pkcs8_of_pem(secret.reveal()) ? |_| BadSetting("GITHUB_APP_KEY")
		input = GithubApp.jwt_input({ app_id, now_ms: Time.now_ms!() }) ? |_| BadSetting("GITHUB_APP_ID")
		signature = WebCrypto.sign!({ alg: RsaPkcs1(Sha256), key: Pkcs8(der), data: input.to_utf8() }) ? |_| SignFailed
		jwt = GithubApp.jwt_text({ input, signature })
		request = Request.post(GithubApp.token_url(installation), Body.Empty)
			.with_header("user-agent", GithubApp.user_agent)
			.with_header("accept", GithubApp.accept)
			.with_header("authorization", "Bearer ${jwt}")
		res = Http.send!(request) ? |_| TokenNoAnswer
		if res.status() != 201 {
			return Err(TokenStatus(res.status()))
		}
		text = res.text!() ? |_| TokenBad
		GithubApp.parse_token(text).map_err(|_| TokenBad)
	}
}
