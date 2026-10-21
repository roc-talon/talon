| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| N1 | R-SO20 | `(Ok(p), Ok(t), Lock) if t != p => Ok(Pin.toolchain` | caught by l0:pin, l2:ladder/ld-no-check-refuse, l3:update/up1-update-entries, l3:remove/rm2-workspace |
| N2 | R-SO20 R-SP1 | `(Ok(p), Ok(t), Verify) if t != p => (Ok(t), Env)` | caught by l0:pin, l2:ladder/ld-no-check-refuse, l3:update/up1-update-entries, l3:remove/rm2-workspace |
| V1 | R-SO21 | `(Ok(p), Ok(t), Verify) if t != p => (Ok(t), Env)` | caught by l0:pin, l3:verify/vf1-verify |
| E1 | R-SO19 | `(Err(NoPin), Ok(t), _) => (Ok(t), Env)` | caught by l0:pin, l3:verify/vf1-verify |
| G5 | R-SO19 G5 | `ResolveBase.check_pin(loaded, settings, decision,` (the install flow gates the roc on PATH also with a pin) | caught by l2:ladder/ld-no-check-refuse. First try: the row gated the pin id (`Pin => Pin.gate(...)`), which is no bug (`outside` has checked it): NOT CAUGHT, so the row was rewritten |
| NS4 | R-NS4 R-SO21 | `Env => if role == Verify {` | caught by l3:verify/vf1-verify |
| X1 | R-SO19 | `Err(Fail.new(NoTuple, "the compiler ${facts.compil` | caught by l0:pin, l3:verify/vf1-verify |
| X2 | R-SO19 | `if Pin.is_nightly(facts.compiler) and !facts.night` | caught by l0:pin |
| S1 | R-SO22 R-H6 | `can_write = !facts.no_check` | caught by l0:pin, l2:ladder/ld-no-check-refuse |
| C1 | R-SO22 R-PH7 | `Ok({ toolchain, path_roc })` | caught by l3:verify/vf1-verify, l3:update/up1-update-entries |
| C2 | R-SO22 R-LF1 | `Ok({ toolchain, path_roc })` | caught by l3:install/in1-workspace-frozen-rename |
| R1 | R-RP2 R-SO17 | `ResolveBase.check_pin(loaded, settings, decision,` | caught by l2:resolve/rs-failures |
| R2 | R-RP2 | `ResolveBase.check_pin(loaded, settings, decision,` (remove: no check for a pinned header) | caught by l3:remove/rm2-workspace |
| R3 | R-RP2 Q37 | `ResolveBase.check_pin(loaded, settings, decision,` (remove: no check with --no-check, as the code of slice 012) | caught by l3:remove/rm2-workspace |
| N3 | R-NS9 R-NS10 | `(_, Ok(b), _) => (b, Toml)    (_, _, Ok(b)) => (b,` | caught by l3:verify/vf1-verify |
| W1 | R-SO19 R-SO20 R-SO21 | `toolchain = Compiler.toolchain_of(env)?` | caught by l3:update/up1-update-entries, l3:verify/vf1-verify, l3:remove/rm2-workspace |
| P1 | R-SO20 | `(Ok(p), Ok(t), Lock) if t != p => Ok(Pin.toolchain` | caught by l0:pin |
| P2 | R-SO20 R-SO21 | `(Ok(p), Ok(t), Lock) if t != p => Ok(Pin.toolchain` | caught by l0:pin |
| O1 | R-SO21 R-RP2 | `outside: outside_pin(texts, { req: facts.req, nigh` | caught by l0:pin |
