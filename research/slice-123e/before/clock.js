// The clock of the tests (the clock rule of Registry 8, TESTING.md TW2, TW33). Platform 0.0.3 has one clock: the shim option `now` (a function that gives ms since the epoch)
// drives `Time.now_ms!`, `Memo` and pin expiry, the task deadlines and the alarms (cloudflare-workers MODULES.md 11, "The clock"). So worker-test.js gives the shim `now`,
// and nothing sets `Date.now`: the Cache API, `crypto` and the timers keep the real clock.
let fixed = 1767225600000; // 2026-01-01T00:00:00Z, the default time of a case (worker/tests/run.mjs)
export const now = () => fixed;
export const setNow = (ms) => { fixed = ms; };
