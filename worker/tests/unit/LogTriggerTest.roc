import lib.LogTrigger

LogTriggerTest :: [].{}

# W0 tests of worker/lib/LogTrigger.roc (slice 257c, docs/slices/257-log-tiles.md section 3.6). The W2 cases are worker/tests/cases/logafter/
# (made by research/slice-257c-vectors/cases.mjs).

# R-SG7, Design Q636 (8): a 201 of a write route (publish, ingest, `PUT /v1/toolchains/{tag}`, the shared flow of the index queue job) added a leaf: the step runs.
expect LogTrigger.wrote_leaf(201)

# R-SG7, Design Q636 (8): a 200 wrote no leaf (the label is indexed, a provenance row only, another request was first, a toolchain tag with rows): no step.
expect !LogTrigger.wrote_leaf(200)

# R-SG7: the other success statuses of the Worker write no leaf (202 of the webhook route sends a queue message; 204 and 304 write nothing).
expect [202, 204, 304].all(|s| !LogTrigger.wrote_leaf(s))

# R-SG7, R-AP48: a refusal (4xx) writes nothing, so no step.
expect [400, 401, 403, 404, 405, 409, 413, 415, 422, 429].all(|s| !LogTrigger.wrote_leaf(s))

# R-SG7: a fault (5xx) writes no leaf that the answer shows: no step after the answer (the catch-up cron covers a leaf of a batch that the answer did not see).
expect [500, 502, 503].all(|s| !LogTrigger.wrote_leaf(s))

# R-SG7: only the exact status 201 (not each 2xx; 206 and 226 are not answers of a write route).
expect [199, 206, 226, 0, 65535].all(|s| !LogTrigger.wrote_leaf(s))
