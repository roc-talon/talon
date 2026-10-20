| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| D1 | R-DI12 | `if c.missing return Err(Github.no_page_failure(f.n` | caught by l3:add/ad1-add-entries (add/ad1-add-entries) |
| D2 | R-DI12 | `Fail.new(Network, "the index of ${name} has no cac` | caught by l3:add/ad1-add-entries (add/ad1-add-entries) |
| D3 | R-DI12 | `has no cached page and --offline is set.` | caught by l3:add/ad1-add-entries (add/ad1-add-entries) |
| T2 | R-PH7 | `Ok(id) if !facts.frozen => {` | caught by l3:verify/vf1-verify (verify/vf1-verify) |
| T3 | R-SC12 | `Ok((_, text)) if !text.is_empty() => if Compiler.k` | caught by l3:verify/vf1-verify (verify/vf1-verify) |
| T4 | R-EV5 | `name == "ROC_TOOLCHAIN"` | caught by l3:verify/vf1-verify (verify/vf1-verify) |
| P1 | R-SC12 R-EC19 | `if !Pin.is_id(e.value) return` | caught by l3:verify/vf1-verify (verify/vf1-verify) |
| T1 | R-SO2 R-EV5 | `Compiler.require({ id, path_roc: facts.path_roc })` | caught by l3:verify/vf1-verify (verify/vf1-verify) |
| P2 | R-EC19 | `.fold(1, /n, b/` | caught by l3:verify/vf1-verify (verify/vf1-verify) |
| N1 | R-NS10 | `(_, _, Ok(b)) => (b, Config)` | caught by l3:verify/vf1-verify (verify/vf1-verify) |
| N2 | R-NS8 | `(Ok(b), _, _) => (b, Env)` | caught by l3:verify/vf1-verify (verify/vf1-verify) |
| N3 | R-NS9 R-NS10 | `(_, Ok(b), _) => (b, Toml)    (_, _, Ok(b)) => (b,` | NOT CAUGHT |
| N4 | R-NS2 | `Env => "TALON_NIGHTLY"` | caught by l3:verify/vf1-verify (verify/vf1-verify) |
| N5 | R-NS2 | `Config => "nightly in config.toml"` | caught by l3:verify/vf1-verify (verify/vf1-verify) |
| C1 | R-C7 R-LY4 | `user: loaded.config.min_release_age` | caught by l3:verify/vf1-verify (verify/vf1-verify) |
| C2 | R-C7 | `doc,     "min-release-age",     /v/ match v {` | caught by l3:verify/vf1-verify (verify/vf1-verify) |
| G1 | R-SO13 R-SO4 | `!Pin.admits({ req, id: facts.compiler }) => Err(` | caught by l2:resolve/rs-no-compiler (resolve/rs-no-compiler) |
| G2 | R-NS3 R-NS2 | `if Pin.is_nightly(facts.compiler) and !facts.night` | caught by l2:resolve/rs-no-compiler (resolve/rs-no-compiler) |
| G3 | R-NS2 | `Err(Fail.new(NoTuple, "the roc on PATH,` | caught by l2:resolve/rs-no-compiler (resolve/rs-no-compiler) |
| G4 | R-SO13 | `Ok(id) => if decision.pinned {` | caught by l2:resolve/rs-no-compiler (resolve/rs-no-compiler) |
| G5 | R-SO3 R-PH7 | `Ok(id) => if decision.pinned {` | NOT CAUGHT |
| F1 | R-SO2 (frozen) | `Ok(id) if !facts.frozen => {` | NOT CAUGHT |
| I1 | R-SO2 (install) | `compiler = Install.compiler!(fx, env, opts.frozen)` | NOT CAUGHT |
| W1 | W8 (Why.find) | `at = ents.find_first_index(/x/ x.alias == alias an` | NOT CAUGHT |
| C3 | R-NS10 | `config = read_config!(fx, config_path, config_resu` | caught by l3:verify/vf1-verify (verify/vf1-verify) |
