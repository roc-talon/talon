Draft of an issue for roc-lang/roc. Not filed. It waits for the user's approval.

Title: A match arm with an or-pattern is emitted once per alternative (wasm32 function 3x to 6x larger)

## Summary

A `match` arm with an or-pattern of N tag alternatives is lowered as N copies of the arm body, also when the pattern binds nothing. If the arm calls a large inlined function, the enclosing function becomes N times larger. In a real Cloudflare Worker app this made one wasm function 1,246,912 bytes (20 percent of the code section). V8 compiles it lazily at the first call, which costs about 39 ms of CPU on a cold request.

## Compiler

`nightly-2026-10-31-f7bef6b`, `roc build --target=wasm32 --opt=speed` (the same with `--opt=size`).

## Repro

Two apps that differ only in one arm. The platform is a release URL, so each app builds with no local setup:
- https://github.com/roc-talon/talon/tree/main/research/bigfn/variants/mini2or (`main.roc`, `Problem.roc`, `Route.roc`)
- https://github.com/roc-talon/talon/tree/main/research/bigfn/variants/mini2wild

The only difference (`main.roc` line 175):

```roc
# mini2or
Fetch(_) | Scheduled(_) | Queue(_) | Email(_) | Tail(_) | Other(_) => own!(e)
_ => worker.event!(e)

# mini2wild
Rpc(_) => worker.event!(e)
EntrypointFetch(_) => worker.event!(e)
Object(_) => worker.event!(e)
Manifest => worker.event!(e)
_ => own!(e)
```

| App | Largest wasm function | Copies of one string table in it |
| --- | --- | --- |
| mini2or | 501,878 bytes | 102 (6 x 17 call sites) |
| mini2wild | 165,808 bytes | 17 |

The copies were counted from the `i32.const` values in the function body that point at one data string. The scanner is `research/bigfn/wasmscan.mjs` in the same repo.

## Expected

The arm body is emitted once, and each alternative jumps to it (the pattern binds no variable).

## Notes

- A native program with no platform header and the same or-pattern shape did not show the effect (`research/bigfn/orpat/`). So the trigger needs more than the pattern alone: possibly the `=>` closure in a record, the platform types, or the wasm32 target.
- Separate problem, same app: `--specialize=no` crashes the compiler (`Segmentation fault ... post-check boxy_plan`).
