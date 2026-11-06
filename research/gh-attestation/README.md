# gh attestation verify: real JSON shape

Run date: 2026-11-03. Tool: gh 2.103.3 (2026-10-26), linux amd64.
The tarball sha256 matched the release checksums file
(4c806978ffce1cec70853302a56d70ac6da4f19bae7adca4e1a8ab00633dd91d).
`gh attestation verify --help` exits 0.

Artifact: `gh_2.103.3_linux_amd64.tar.gz` from cli/cli.

## Files

| File | Content |
|---|---|
| repo.json | stdout of `verify <file> --repo cli/cli --format json`, exit 0 |
| owner.json | stdout of `verify <file> --owner cli --format json`, exit 0 |
| failures.txt | exit code, stdout and last stderr line of three failure cases |

repo.json and owner.json are the same except for the verifiedIdentity regexp
(the --owner run matches the owner prefix only). No token is in them.

## Top level

The top level is an array. One element for this artifact.
The GitHub API lists 2 attestations for this digest. The default predicate
filter (SLSA provenance v1) keeps 1. A 2-element array was not seen.
The code must take the elements as a list, not as one object.

## Paths (all start with `[i]`, for example `[0]`)

| Item | JSON path | Value in this run |
|---|---|---|
| Source commit digest | `[i].verificationResult.signature.certificate.sourceRepositoryDigest` | 63837fb778d6a39f02be0ce76ff89f2bc8d74bdc |
| Signer workflow URI | `[i].verificationResult.signature.certificate.buildSignerURI` | https://github.com/cli/cli/.github/workflows/deployment.yml@refs/heads/trunk |
| Source repository URI | `[i].verificationResult.signature.certificate.sourceRepositoryURI` | https://github.com/cli/cli |
| Source ref | `[i].verificationResult.signature.certificate.sourceRepositoryRef` | refs/heads/trunk |
| Workflow ref | `[i].verificationResult.signature.certificate.githubWorkflowRef` | refs/heads/trunk |
| Workflow repository | `[i].verificationResult.signature.certificate.githubWorkflowRepository` | cli/cli |
| Workflow commit | `[i].verificationResult.signature.certificate.githubWorkflowSHA` | 63837fb7... (same as source digest here) |
| Signer commit | `[i].verificationResult.signature.certificate.buildSignerDigest` | 63837fb7... |
| Certificate SAN | `[i].verificationResult.signature.certificate.subjectAlternativeName` | same as buildSignerURI here |
| Statement commit (from predicate) | `[i].verificationResult.statement.predicate.buildDefinition.resolvedDependencies[0].digest.gitCommit` | 63837fb7... |
| Statement workflow path | `[i].verificationResult.statement.predicate.buildDefinition.externalParameters.workflow.path` | .github/workflows/deployment.yml |
| Subjects (file names and sha256) | `[i].verificationResult.statement.subject[j]` | one entry per release asset |

The `buildSignerURI` value joins the workflow repository, the workflow file
path, and `@` plus the ref. The workflow file path alone is in
`statement.predicate.buildDefinition.externalParameters.workflow.path`.

## Comparison with the names slice 092 assumes

| Assumed name | Real path | Result |
|---|---|---|
| `verificationResult.signature.certificate.sourceRepositoryDigest` (commit) | `[i].verificationResult.signature.certificate.sourceRepositoryDigest` | same (only the `[i]` array prefix is added) |
| `buildSignerURI` (workflow file) | `[i].verificationResult.signature.certificate.buildSignerURI` | same (full path as above; the value is a URI with `@ref`, not a bare file path) |
| Top level is one object | Top level is an array | different |

## Failure shapes

All three cases exit 1 with empty stdout. See failures.txt.

| Case | Exit | Last stderr line |
|---|---|---|
| File with no attestation | 1 | `Error: no attestations found` |
| Right file, wrong --repo (cli/go-gh) | 1 | `Error: HTTP 404: Not Found (https://api.github.com/repos/cli/go-gh/attestations/sha256:...)` |
| Right file, wrong --owner | 1 | `Error: HTTP 404: Not Found (https://api.github.com/orgs/<owner>/attestations/sha256:...)` |

A wrong repo gives HTTP 404, not "no attestations found". A script cannot
tell "no attestation" from "wrong repo" by exit code. Use the last stderr line.
