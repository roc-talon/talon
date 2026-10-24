| Id | Result | Layers that must catch it | Layers that failed |
| --- | --- | --- | --- |
| M01 | caught | l0 l2 l3 | l0 l2 l3 |
| M02 | caught | l0 | l0 |
| M03 | caught | l0 | l0 |
| M04 | caught | l0 | l0 |
| M05 | caught | l0 | l0 |
| M06 | caught | l0 | l0 |
| M07 | caught | l0 | l0 |
| M08 | caught | l0 | l0 |
| M09 | caught | l0 l2 l3 | l0 l2 l3 |
| M10 | caught | l0 l2 l3 | l0 l2 l3 |
| M11 | caught | l0 | l0 |
| M12 | caught | l0 l2 | l0 l2 |
| M13 | caught | l0 l2 | l0 l2 |
| M14 | caught | l0 l2 l3 | l0 l2 l3 |
| M15 | caught | l0 l2 | l0 l2 |
| M16 | caught | l2 | l2 |
| M17 | caught | l2 | l2 |
| M18 | caught | l2 | l2 |
| M19 | caught | l2 | l2 |
| M20 | caught (changed on 2026-10-23: the link records `full`, not the canonical path) | l0 l3 | l0 l3 |
| M21 | caught | l2 l3 | l2 l3 |
| M22 | caught | l2 l3 | l2 l3 |
| M23 | caught | l2 | l2 |
| M24 | caught | l2 l3 | l2 l3 |
| M25 | caught | l2 l3 | l2 l3 |
| M26 | caught | l2 l3 | l2 l3 |
| M27 | caught | l2 | l2 |
| M28 | caught | l2 | l2 |
| M29 | caught | l2 l3 | l2 l3 |
| M30 | caught | l2 | l2 |
| M31 | caught | l0 l2 | l0 l2 |
| M32 | caught | l0 | l0 |
| M33 | caught | l0 l2 l3 | l0 l2 l3 |
| M34 | caught (second try: the first text matched `copy_tree!`) | l3 | l3 |
| M35 | caught | l3 | l3 |
| M36 | caught | l3 | l3 |
| M37 | not caught: the text of `Other` (`is a directory` against `is a dir`) is hidden on purpose in the L3 case, because the text of a platform changes. No test pins it: the doc of `Fx.copy_file!` gives the text and the fake does too. | l3 |  |
| M38 | caught (second try: `++` does not exist) | l2 | l2 |
| M39 | caught (added 2026-10-23: `canonical!` gets the typed path) | l2 | l2 |
| M40 | caught (added 2026-10-23: no `Text.resolve`, a `..` part stays) | l3 | l3 |
| M41 | caught (added 2026-10-23: `Link.source` gives the typed path) | l0 l2 l3 | l0 l2 l3 |
