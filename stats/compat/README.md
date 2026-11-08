# Compat bot stats

The compat bot keeps the time and the resources of each probe. `runs.csv` has one row per run, `<YYYY-MM>.csv` has one row per probe (the columns are the first line of each file).

Run totals of the last 1 runs (ms). The first line is wall time and the second line is CPU time (user plus system).

```mermaid
xychart-beta
    title "Compat bot run totals"
    x-axis "run id" ["42428275982"]
    y-axis "ms"
    line [143940]
    line [38340]
```
