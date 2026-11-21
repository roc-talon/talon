# Compat bot stats

The compat bot keeps the time and the resources of each probe. `runs.csv` has one row per run, `<YYYY-MM>.csv` has one row per probe (the columns are the first line of each file).

Run totals of the last 14 runs (ms). The first line is wall time and the second line is CPU time (user plus system).

```mermaid
xychart-beta
    title "Compat bot run totals"
    x-axis "run id" ["42428275982", "42475950878", "42624444372", "43017525329", "43225107370", "43426380932", "43591360466", "43712776879", "43872613275", "44096414582", "44313296548", "44537589566", "44745290988", "44906502616"]
    y-axis "ms"
    line [143940, 3060, 574300, 306000, 264960, 361500, 314410, 244780, 404490, 5530, 231870, 42030, 275510, 397350]
    line [38340, 5610, 602900, 273650, 202220, 314450, 252560, 204130, 374410, 5430, 153680, 81430, 206240, 354070]
```
