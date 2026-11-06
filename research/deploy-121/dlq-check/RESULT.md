# R-PU45 edge check: result (2026-11-06)

PASS. One message sent at 10:49:28 UTC to `talon-dlqc-main` (consumer: `retry()` with no delay on each attempt, `max_retries = 1`) was in `talon-dlqc-dlq` at 10:49:36 UTC (HTTP pull, 1 message, the same body). So a `retry()` at the last attempt is a failed delivery, and the broker moves the message to the dead letter queue. R-PU45 stands: the consumer at attempt 5 calls `retry` with no delay, and the code needs no producer for `INDEX_DLQ`.

The Worker `talon-dlq-check` and both queues are deleted.
