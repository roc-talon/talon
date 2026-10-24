| Id | Result | Layers that must catch it | Layers that failed |
| --- | --- | --- | --- |
| M01 | caught | l0 | l0 |
| M02 | caught | l0 | l0 |
| M03 | caught | l0 l2 l3 | l0 l2 l3 |
| M04 | caught | l0 l2 | l0 l2 |
| M05 | caught | l0 l2 | l0 l2 |
| M06 | caught | l0 l2 | l0 l2 |
| M07 | caught | l0 | l0 |
| M08 | caught | l0 l3 | l0 l3 |
| M09 | caught | l0 l2 l3 | l0 l2 l3 |
| M10 | caught | l0 l2 l3 | l0 l2 l3 |
| M11 | caught | l0 l2 l3 | l0 l2 l3 |
| M12 | caught | l0 l2 | l0 l2 |
| M13 | caught | l0 l2 l3 | l0 l2 l3 |
| M14 | caught | l0 l2 | l0 l2 |
| M15 | caught | l0 l2 | l0 l2 |
| M16 | caught | l0 l2 l3 | l0 l2 l3 |
| M17 | caught | l2 l3 | l2 l3 |
| M18 | caught | l2 | l2 |
| M19 | caught | l2 l3 | l2 l3 |
| M20 | caught | l2 | l2 |
| M21 | caught | l2 | l2 |
| M22 | caught | l2 l3 | l2 l3 |
| M23 | caught | l2 | l2 |
| M24 | caught | l2 l3 | l2 l3 |
| M25 | caught | l2 | l2 |
| M26 | caught | l2 | l2 |
| M27 | caught | l2 l3 | l2 l3 |
| M28 | caught | l2 | l2 |
| M29 | caught | l0 | l0 |

First pass (2026-10-23): 7 mutations did not compile or did not apply (a constant condition, an unused variable, a changed text). They were written again and run again (M06, M09, M17, M19, M20, M21, M23, M27 changed).
Review (2026-10-23): `roc rm` waits for the item lock (Q2 changed). M18 and M28 were changed for it (M28: `Wait` becomes `NoWait`) and run again, with a busy lock row in `rm1-remove` (`fx/locks`). M29 is new for the dated release row of `next_default` (G2: `times` ignored). 29 of 29 caught.
