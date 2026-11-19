## The trigger of the tile step after a write (Registry R-SG7, R-PU1, R-AP41; Design Q636 (8); slice 257c, docs/slices/257-log-tiles.md section 3.6).
## Pure: no `Fx`. W0: `worker/tests/unit/LogTriggerTest.roc`. The effects (the step, its log line, `Response.after`) are in `worker/LogWriter.roc` (`once!`, `with_step`).
## Every body is a stub until the code agent writes it (TW18).

LogTrigger :: [].{

	## R-SG7, Design Q636 (8): did the request or the job write a new leaf? The answer status of a route that can write a leaf (publish, ingest, `PUT /v1/toolchains/{tag}`,
	## and the shared flow `IngestRoutes.index!` of the index queue job) is 201 exactly when its D1 batch added a release or a compiler asset, and so a leaf (R-SG8).
	## Each other status writes no leaf: a 200 (the label is indexed, a provenance row only, another request was first, a toolchain tag that has rows), a 304, each 4xx, each 5xx.
	## True: the step runs after the answer (`Response.after`) or at the end of the queue job. False: no step, no R2 call.
	wrote_leaf : U16 -> Bool
	wrote_leaf = |_status| crash "todo"
}
