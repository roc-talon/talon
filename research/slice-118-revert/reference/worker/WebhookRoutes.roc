## Private reference of slice 118 (WebhookRoutes.roc). Not for the code agent (TW18).
import pf.Request
import pf.Response
import pf.Env
import pf.WebCrypto
import lib.Problem
import lib.Webhook
import IndexQueue
import ReadRoutes

WebhookRoutes :: [].{

	post! : Request => Try(Response, ReadRoutes.Error)
	post! = |req| {
		bytes = match req.bytes_with!({ max_bytes: body_limit }) {
			Ok(b) => b
			Err(TooLarge) => return Ok(too_large)
			Err(BodyErr(_)) => []
		}
		secret = Env.secret!("GITHUB_WEBHOOK_SECRET").map_err(|e| Fault(Str.inspect(e)))?
		key = secret.reveal().to_utf8()
		if key.is_empty() {
			return Err(Fault("the secret GITHUB_WEBHOOK_SECRET is empty"))
		}
		given = match req.header("x-hub-signature-256") {
			Ok(h) => Webhook.parse_signature(h)
			Err(NotFound) => Err(Malformed)
		}
		match given {
			Err(Malformed) => return Err(Refuse(Webhook.bad_signature))
			Ok(sig) => if (!WebCrypto.timing_safe_equal!(WebCrypto.hmac_sha256(key, bytes), sig)) return Err(Refuse(Webhook.bad_signature))
		}
		event = req.header("x-github-event") ?? ""
		decision = Webhook.parse_event({ event, body: bytes }).map_err(|p| Refuse(p))?
		match decision {
			Ignore => {}
			Send(message) => IndexQueue.index.send!(message).map_err(|e| Fault(Str.inspect(e)))?
		}
		Ok(Response.from_status(202).with_header("cache-control", "no-store"))
	}

	body_limit : U64
	body_limit = 1048576

	too_large : Response
	too_large = {
		problem = Problem.new(TooLarge, "the body of the webhook request is larger than its limit of ${body_limit.to_str()}")
		Response.from_bytes(413, "application/problem+json", Problem.to_json_with(problem, { field: "body", limit: body_limit }).to_utf8())
	}
}
