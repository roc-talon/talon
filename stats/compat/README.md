# Compat bot stats

The compat bot keeps the time and the resources of each probe. `runs.csv` has one row per run, `<YYYY-MM>.csv` has one row per probe (the columns are the first line of each file).

Run totals of the last 3 runs (ms). The first line is wall time and the second line is CPU time (user plus system).

```mermaid
xychart-beta
    title "Compat bot run totals"
    x-axis "run id" ["42428275982", "42475950878", "42624444372"]
    y-axis "ms"
    line [143940, 3060, 574300]
    line [38340, 5610, 602900]
```
