# Mutation m10-claims-loose of the slice 108b reference: the Talon claims parse fault is ignored when the registered claims parse
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = 'claims = claims_try ? |_| not_jwt'
new = 'claims = claims_try ?? { iss: Err(Missing), aud: Err(Missing), exp: Err(Missing), nbf: Err(Missing), repository: Err(Missing), repository_id: Err(Missing), repository_owner_id: Err(Missing), repository_visibility: Err(Missing), ref: Err(Missing), ref_type: Err(Missing), event_name: Err(Missing), workflow_ref: Err(Missing), workflow_sha: Err(Missing), job_workflow_ref: Err(Missing), run_id: Err(Missing), run_attempt: Err(Missing), actor_id: Err(Missing), runner_environment: Err(Missing) }'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
