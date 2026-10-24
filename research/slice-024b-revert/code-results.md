# Revert check of the code, slice 024b (42 mutations, see code-mutate.py)

Rule: a mutation is CAUGHT when a listed test fails. Only the tests that should catch it were run (no full sweep). cli/ was restored from code-final/ before and after each mutation. At the end `diff -r code-final ../../cli` shows no difference.
M18, M22, M24 and M39 were written again (the first form did not compile, or no longer matched after the move of the shared functions). M39 to M42 test the shared `Clock.now!` and `Fx.locked!`.
Caught 37 of 42. Not caught: M30, M36, M37, M38, M40.

| Id | Class | Reason |
| --- | --- | --- |
| M30 | Equivalent change | `Launch.program!` for a `link-*` id that is not installed. `Proxy.want` and `Compiler.require` refuse such an id before the call, so no run reaches the guard. It stays as a defense. |
| M36, M37, M38 | Equivalent change (test hides the text) | `Path.copy!` also fails for a directory (and for a link to a directory), and the result is `Other(<platform text>)` in each form. The L3 case checks the variant only: the text is the text of the platform (as M37 of the test agent). |
| M40 | Test gap | A bad `TALON_NOW` is exit 2 (`Clock.now!`). No L2 or L3 case sets a bad `TALON_NOW`: the old `Proxy.clock_now!` and `Install.begin!` had the same hole (R-EV22, Q5, Q7). The L0 `Clock.now` test covers the pure part only. Proposal: one row in an L2 case (slice 001 or 023 owner). |

M01: CAUGHT by l0:link (R-FL12: --force with no --copy is accepted)
M02: CAUGHT by l0:link (R-R12, R-R13: the prefixes are swapped)
M03: CAUGHT by l0:link (R-LY1: a name that ends in .lock)
M04: CAUGHT by l0:link (R-LY1: a name with a backslash)
M05: CAUGHT by l0:link (R-CM15: the text of the count)
M06: CAUGHT by l0:link (R-LK4, Q5: the canonical path is used, not the absolute path)
M07: CAUGHT by l0:link (R-R12: no such file is exit 18)
M08: CAUGHT by l0:link (R-LK2: --force replaces only without the flag)
M09: CAUGHT by l0:link (R-LK2: the text of a link that exists)
M10: CAUGHT by l0:link (R-LK4: the key of a link)
M11: CAUGHT by l0:link (R-TF1: the time of .talon.json)
M12: CAUGHT by l0:link (R-LK4: a relative target path is accepted)
M13: CAUGHT by l0:link (R-LK4: a link with no .talon.json is exit 19)
M14: CAUGHT by l0:link (R-TF3: a newer format is read)
M15: CAUGHT by l0:link (R-OUT2: no line end)
M16: CAUGHT by l0:link (R-J3: replaced is never true)
M17: CAUGHT by l2:link/ (R-CC3, R-CC5: no wait for a busy lock)
M18: CAUGHT by l2:link/ (R-CC1: a failed copy leaves the temp dir)
M19: CAUGHT by l2:link/ (R-LK2: the trash dir stays after a replace)
M20: CAUGHT by l2:link/ (R-LK4: the path is not made absolute)
M21: CAUGHT by l3:compilers/lk1-link-real (R-LK4, Q5: the recorded path is the canonical path)
M22: CAUGHT by l2:link/ (R-EV22: no clock call)
M23: CAUGHT by l2:link/ (R-J3: the envelope is written without --json)
M24: CAUGHT by l2:link/ (R-FL4: --quiet does not hide the line)
M25: CAUGHT by l2:link/ (R-LK4, R-LK2: the kinds are swapped)
M26: CAUGHT by l2:link/ (R-J3: replaced is never true)
M27: CAUGHT by l2:link/ (R-CC10: the old dir goes to another trash name)
M28: CAUGHT by l2:proxy/lk2 (R-LK4: a read of .talon.json for any id)
M29: CAUGHT by l2:proxy/lk2 (R-LK4, R-R5: the proxy never reads the link)
M30: NOT CAUGHT by - (D13: a read for a link that is not installed)
M31: CAUGHT by l0:pin (R-R4, R-LK3: a local build is written as the pin)
M32: CAUGHT by l0:args (R-FL12: --copy for every command)
M33: CAUGHT by l0:args (R-FL12: --copy is not a flag of roc link)
M34: CAUGHT by l3:fx/lk1-real-fx-copy-file (R-LK2: a target that exists is replaced)
M35: CAUGHT by l3:fx/lk1-real-fx-copy-file (R-R13: no parent dirs of the target)
M36: NOT CAUGHT by - (R-R13: a directory as source is not found)
M37: NOT CAUGHT by - (the text of the error of a directory)
M38: NOT CAUGHT by - (R-LK2: a link to a directory is not seen as a directory)
M39: CAUGHT by l2:link/ (R-EV22: Clock.now! ignores TALON_NOW)
M40: NOT CAUGHT by - (R-EV22: a bad TALON_NOW is not exit 2)
M41: CAUGHT by l2:link/ (R-CC5: Fx.locked! does not wait)
M42: CAUGHT by l2:link/ (Fx.locked! changes the kind of a failure of the body)
