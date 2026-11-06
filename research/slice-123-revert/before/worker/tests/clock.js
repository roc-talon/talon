// The clock of the tests (the clock rule of Registry 8, TESTING.md TW2, TW33). worker-test.js imports this module first, so `Date.now()` is the time of the case
// before the shim loads. `Time.now_ms!` of the platform calls `Date.now()`. The shim option `now` is not this clock (it drives the task deadlines
// and the pins only), so worker-test.js gives the shim the real clock through that option.
export const realNow = Date.now.bind(Date);
let fixed = 1767225600000; // 2026-01-01T00:00:00Z, the default time of a case (worker/tests/run.mjs)
Date.now = () => fixed;
export const setNow = (ms) => { fixed = ms; };
