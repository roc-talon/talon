# R-PU45 edge check (slice 121)

A throwaway Worker `talon-dlq-check` and queues `talon-dlqc-main`, `talon-dlqc-dlq`. The consumer of the main queue calls `retry()` with no delay on each attempt, with `max_retries = 1`. The dead letter queue has an HTTP pull consumer. Pass: one message is in the dead letter queue after the second attempt. The run script is `run.sh`; it deletes the Worker and the queues at the end. The result is in `RESULT.md`.
