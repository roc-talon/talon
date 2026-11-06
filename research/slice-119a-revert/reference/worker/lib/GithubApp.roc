## PRIVATE REFERENCE of slice 119a (not for the code agent, TW18). The pure part of the GitHub read token.
import base64.Base64
import Problem
import Toolchains

GithubApp :: [].{

	user_agent : Str
	user_agent = "talon-registry"

	accept : Str
	accept = "application/vnd.github+json"

	keep_margin_ms : U64
	keep_margin_ms = 300_000

	Token : { token : Str, expires_ms : U64 }

	Failure : [NoSetting(Str), BadSetting(Str), SignFailed, TokenStatus(U16), TokenNoAnswer, TokenBad]

	header_b64 : Str
	header_b64 = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9"

	jwt_input : { app_id : Str, now_ms : U64 } -> Try(Str, [BadAppId])
	jwt_input = |x| {
		bytes = x.app_id.to_utf8()
		if bytes.is_empty() or !bytes.all(|b| b >= '0' and b <= '9') {
			return Err(BadAppId)
		}
		id = U64.from_str(x.app_id) ? |_| BadAppId
		s = x.now_ms // 1000
		iat = if (s < 60) 0 else s - 60
		payload = "{\"iat\":${iat.to_str()},\"exp\":${(s + 540).to_str()},\"iss\":${id.to_str()}}"
		Ok("${header_b64}.${Base64.encode_url(payload.to_utf8())}")
	}

	jwt_text : { input : Str, signature : List(U8) } -> Str
	jwt_text = |x| "${x.input}.${Base64.encode_url(x.signature)}"

	token_url : Str -> Str
	token_url = |installation_id| "https://api.github.com/app/installations/${installation_id}/access_tokens"

	RawToken : { token : Str, expires_at : Str }

	parse_token : Str -> Try(GithubApp.Token, [BadAnswer])
	parse_token = |text| {
		raw : Try(GithubApp.RawToken, _)
		raw = Json.parse(text)
		match raw {
			Ok(r) => match Toolchains.parse_time(r.expires_at) {
				Ok(expires_ms) => Ok({ token: r.token, expires_ms })
				Err(_) => Err(BadAnswer)
			}
			Err(_) => Err(BadAnswer)
		}
	}

	usable : GithubApp.Token, U64 -> Bool
	usable = |t, now_ms| now_ms.plus_saturated(keep_margin_ms) < t.expires_ms

	pkcs8_of_pem : Str -> Try(List(U8), [NotPem, Pkcs1])
	pkcs8_of_pem = |pem| {
		lines = pem.replace_each("\r", "").split_on("\n").keep_if(|l| !l.is_empty())
		match lines {
			["-----BEGIN RSA PRIVATE KEY-----", .. as _rest] => Err(Pkcs1)
			["-----BEGIN PRIVATE KEY-----", .. as rest] => match rest.last() {
				Ok("-----END PRIVATE KEY-----") => {
					body = Str.join_with(rest.drop_last(1), "")
					if body.is_empty() {
						Err(NotPem)
					} else {
						Base64.decode(body).map_err(|_| NotPem)
					}
				}
				_ => Err(NotPem)
			}
			_ => Err(NotPem)
		}
	}

	api_prefix : Str
	api_prefix = "https://api.github.com/"

	uses_token : Str -> Bool
	uses_token = |url| url.starts_with(api_prefix)

	read_headers : { url : Str, token : Str } -> List((Str, Str))
	read_headers = |x| if (uses_token(x.url)) [("user-agent", user_agent), ("accept", accept), ("authorization", "Bearer ${x.token}")] else [("user-agent", user_agent)]

	failure_class : GithubApp.Failure -> [Upstream(Str), Fault(Str)]
	failure_class = |failure| match failure {
		NoSetting(n) => Fault("the setting ${n} is not set")
		BadSetting(n) => Fault("the setting ${n} is not valid")
		SignFailed => Fault("the JWT of the App cannot be signed")
		TokenStatus(s) => Upstream("the GitHub installation token request failed with status ${s.to_str()}")
		TokenNoAnswer => Upstream("the GitHub installation token request failed: no answer")
		TokenBad => Upstream("the GitHub installation token answer is not valid")
	}
}
