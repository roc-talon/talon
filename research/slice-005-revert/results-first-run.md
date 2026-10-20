| Rule | Mutation | Result |
| --- | --- | --- |
| R-I4 implied lower bound | Ranges: `">=${version}, <${next_series(v)}"` | caught by l0:ranges |
| R-I4 series below 1.0 | Ranges: `if v.major() >= 1` | caught by l0:ranges |
| R-C1 all ranges admit | Ranges: `facts.ranges.all(` | caught by l0:ranges |
| R-TF4 range check | Ranges: `Ok(_) => Ok({}) 		Err(_) => Err(BadRange)` | caught by l0:ranges |
| R-C4 platform kind | Release: `Platform(_) => Platform` | caught by l0:pick |
| R-C3 pf entry of a platform | Release: `Ok(e) if kind != Platform => Ok(e.value)` | NOT CAUGHT |
| R-C2 deps without roc | Release: `!e.is_platform and e.name != "roc"` | caught by l0:pick |
| R-DI7 no header kind | Release: `Err(NoHeader) => Err(Fail.new(Input,` | caught by l0:pick |
| R-NS7 any | Pin: `Ok(Any)` | caught by l0:pin |
| R-NS7 at least | Pin: `AtLeast(a) => at_least(a, facts.id)` | caught by l0:pin |
| R-NS7 exactly | Pin: `Exactly(a) => facts.id == a` | caught by l0:pin |
| R-NS7 semver range has no nightly | Pin: `Semver(range) => !Pin.is_nightly(facts.id) and` | NOT CAUGHT |
| R-WS4 differing pins | Pin: `if texts.len() >= 2 {` | caught by l0:pin |
| R-RP1 member with a pin | Pin: `m.pin == Err(NoPin) and m.changes` | caught by l0:pin |
| R-RP3 write only for a change | Pin: `m.pin == Err(NoPin) and m.changes` | caught by l0:pin |
| R-H6 no_check writes no pin | Pin: `can_write = !facts.no_check` | caught by l0:pin |
| R-SP1 held pin | Pin: `[one] => Ok(one)` | caught by l0:pin |
| R-NS5 nightly with the switch off | Pin: `(Pin.is_nightly(pin) and !facts.nightly)` | caught by l0:pin |
| R-RP2 follow text | Pin: `${range}. ${follow}")` | caught by l0:pin |
| R-RP2 failure kind | Pin: `Fail.new(NoTuple, "the roc pin ${facts.pin} is out` | caught by l0:pin |
| R-NS7 same date order | Pin: `(Ok(a), Ok(b)) => !is_before(b, a)` | caught by l0:pin |
| Q9 release bound | Pin: `is_release(bound) and is_release(id) and` | NOT CAUGHT |
| R-H4 path row | Locked: `if e.value.contains("://") Foreign else Path` | caught by l0:locked |
| R-RP1 pin entry name | Locked: `entries.find_first(/e/ e.name == "roc")` | caught by l0:locked |
| R-H4 rows without roc | Locked: `entries.keep_if(/e/ e.name != "roc")` | caught by l0:locked |
| R-H4 never edit a path row | Locked: `_ => Err(internal("${alias} is a path entry or a f` | caught by l0:locked |
| R-H3 URL with a hash | Locked: `Err(Foreign) => Err(internal("${url} is not a rele` | caught by l0:locked |
| R-H1 add of a present alias | Locked: `if present(alias) return` | caught by l0:locked |
| R-H6 set the pin | Locked: `Ok(_) => written(id, Header.set_value(text, "roc",` | caught by l0:locked |
| R-CC7 spans | Locked: `facts.ops.map(/op/ entry_text(header, op))` | caught by l0:locked |
| R-CC7 span of the pin | Locked: `Pin(_) => "roc"` | caught by l0:locked |
| R-H7 path entries | Locked: `if r.what == Path Ok` | caught by l0:locked |
| R-I2 split at the first @ | Intent: `text.split_first("@")` | NOT CAUGHT |
| R-C7 days | Intent: `n * 86400` | caught by l0:intent |
| R-NS9 nightly | Intent: `Value.Boolean(b) => Ok(b)` | caught by l0:intent |
| R-WS5 member tables | Intent: `role == Member and !dependency_tables` | caught by l0:intent |
| R-TF4 unknown table | Intent: `message: "unknown table [${name}]"` | caught by l0:intent |
| R-DT3 log snapshot kind | Intent: `Ok(Log(n)) => Err(Fail.new(Usage,` | caught by l0:intent |
| R-DT4 time snapshot | Intent: `Ok(Time(seconds)) => Ok(Ok(seconds))` | caught by l0:intent |
| R-PD6 up to the root | Intent: `if dir == root or dir.is_empty() next` | caught by l0:intent |
| R-VA6 lowest | Intent: `Value.String("lowest") => Ok(Lowest)` | caught by l0:intent |
| R-AD25 same value | Intent: `Ok(Value.String(old)) if old == w.value => Ok(doc)` | caught by l0:intent |
| R-AD26 insert | Intent: `Err(NotFound) => Toml.insert(doc, ["dependencies",` | caught by l0:intent |
| R-CC7 toml spans | Intent: `Ok(value) => Value.print(value)` | caught by l0:intent |
| R-EC19 line of bad TOML | Intent: `Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.pa` | caught by l0:intent |
| R-OV1 overrides table | Intent: `overrides = read_deps(doc, "overrides")` | caught by l0:intent |
| R-I2 range check message | Intent: `is not a version range" })` | caught by l0:intent |
| R-WS1 group of a variable | Vars: `uses.keep_if(/u/ u.group == group)` | caught by l0:vars |
| R-VA6 platforms last | Vars: `firsts.keep_if(/u/ !u.is_platform).concat(firsts.k` | caught by l0:vars |
| R-I3 key range | Vars: `t.intent.deps.find_first(/d/ d.key == u.alias)` | caught by l0:vars |
| R-OV1 override range | Vars: `t.intent.overrides.find_first(/d/ d.key == u.alias` | NOT CAUGHT |
| R-I4 implied range | Vars: `Ranges.implied(u.version) ?? "*"` | caught by l0:vars |
| R-WS2 ranges of all uses | Vars: `uses.fold([], /found, u/ add_range(found, range_of` | caught by l0:vars |
| R-VA6 priority | Vars: `front.concat(vars.keep_if(/v/ !front.contains(v)))` | caught by l0:vars |
| R-WS6 two members | Vars: `f.want.members.len() >= 2` | caught by l0:vars |
| R-I8 stale range | Vars: `Ranges.admits({ ranges: [range], version: ident.ve` | caught by l0:vars |
| R-AD6 short name | Vars: `Ok(n) => if n.contains("/") Ok(n) else Err(Short(n` | caught by l0:vars |
| R-WS8 alias of 2 groups | Vars: `[(i, _)] => Ok(found.append(i))` | caught by l0:vars |
| R-SP20 outside | Vars: `variable.uses.any(/u/ !Ranges.admits` | caught by l0:vars |
| R-SP2 indexed only | Vars: `free = indexed and (all or is_named)` | caught by l0:vars |
| R-SP3 named | Vars: `free = indexed and (all or is_named)` | caught by l0:vars |
| R-SP5 any series | Vars: `any_series: Bool.True, note }` | caught by l0:vars |
| R-DI11 fixed note | Vars: `Fixed(host) => Ok(Index.fixed_line(host))` | caught by l0:vars |
| R-SP19 install holds | Vars: `Install => { variable, free: outside_range(variabl` | caught by l0:vars |
| R-SP14 picker | Vars: `vars.keep_if(/v/ v.host == Indexed).keep_oks` | caught by l0:vars |
| R-C1 range of a slot | Pick: `all.keep_if(/c/ Ranges.admits({ ranges: slot.range` | caught by l0:pick |
| R-C7 age | Pick: `c.published_at + facts.min_age > facts.now` | caught by l0:pick |
| R-C7 age boundary | Pick: `c.published_at + facts.min_age > facts.now` | NOT CAUGHT |
| R-DT4 snapshot | Pick: `Ok(time) => c.published_at > time` | caught by l0:pick |
| R-DT4 snapshot boundary | Pick: `Ok(time) => c.published_at > time` | NOT CAUGHT |
| R-C9 header value is never hidden | Pick: `exempt = slot.current == Ok(c.url) or slot.named` | caught by l0:pick |
| R-C7 named version is never hidden | Pick: `exempt = slot.current == Ok(c.url) or slot.named =` | caught by l0:pick |
| R-C4 kind of a package | Pick: `else release.kind == Package` | caught by l0:pick |
| R-DT2 sorted candidates | Pick: `slot.candidates.sort_with(/a, b/ Text.compare(a.ur` | NOT CAUGHT |
| R-C2 newer dependency | Pick: `ident.group == y.ident.group and is_newer(` | caught by l0:pick |
| R-C3 platform of a package | Pick: `ctx.single_platform and !x.is_platform` | caught by l0:pick |
| R-C9 current is a candidate | Pick: `Ok(c) if !listed.any(/x/ x.url == c.url) => listed` | caught by l0:pick |
| R-SP1 held slot | Pick: `all = if slot.free {` | caught by l0:pick |
| R-PH10 counts | Pick: `outside = total - d.in_range.len()` | caught by l0:pick |
| R-C7 note days | Pick: `days = /seconds/ (seconds // 86400).to_str()` | caught by l0:pick |
| R-PH10 failure kind | Pick: `Fail.new(NoTuple, "no tuple works: ${slot.id} has` | caught by l0:pick |
| R-C9 change | Pick: `change: if slot.current == Ok(c.url) Keep else Mov` | caught by l0:pick |
| R-LF1 wants | Frozen: `.concat(facts.wants.map(want_finding))` | caught by l0:frozen |
| R-SP20 free only | Frozen: `scoped.keep_if(/s/ s.free).join_map(` | NOT CAUGHT |
| R-EC14 frozen kind | Frozen: `Fail.new(Frozen, "the header does not satisfy` | caught by l0:frozen |
| R-LF1 joined findings | Frozen: `Str.join_with(findings, "; ")` | caught by l0:frozen |
| R-NS5 frozen nightly | Frozen: `if !facts.nightly and Pin.is_nightly(pin) {` | caught by l0:frozen |
| R-I8 stale finding | Frozen: `which the header names \"${alias}\""` | caught by l0:frozen |
| R-SP18 install takes no names | Resolve: `for text in (if request.command == Update request.` | NOT CAUGHT |
| R-LF1 frozen hash check | Resolve: `_ = read_releases!(fx, request, urls, Bool.False)?` | caught by l2:resolve/ (resolve/rs-frozen, resolve/rs-no-compiler) |
| Q3 no compiler | Resolve: `Err(NoCompiler) => Err(Fail.new(Environment, "cann` | caught by l2:resolve/ (resolve/rs-no-compiler) |
| Q3 kind | Resolve: `Err(NoCompiler) => Err(Fail.new(Environment,` | caught by l2:resolve/ (resolve/rs-no-compiler) |
| Q3 names roc | Resolve: `there is no roc on PATH that Talon can identify, a` | caught by l2:resolve/ (resolve/rs-no-compiler) |
| Q2 platform key | Resolve: `platform_wants(input.want_slots, all)?` | caught by l2:resolve/ (resolve/rs-want-platform) |
| R-RP2 outside pin | Resolve: `check_pin(loaded.intent, settings, decision)?` | caught by l2:resolve/ (resolve/rs-failures, resolve/rs-no-compiler) |
| R-DT3 snapshot | Resolve: `snapshot = Intent.direct_snapshot(loaded.intent.re` | caught by l2:resolve/ (resolve/rs-failures) |
| R-I8 stale warning | Resolve: `the key \"${w.key}\" names ${w.name ?? w.key}` | NOT CAUGHT |
| R-AD6 short name | Resolve: `Err(Short(text)) => return Err(short_failure(w.fro` | caught by l2:resolve/ (resolve/rs-failures) |
| R-H1 set only changed uses | Resolve: `.keep_if(/u/ u.url != c.url) 	.map(/u/ { file: u.f` | caught by l2:resolve/ (resolve/rs-install-add-key, resolve/rs-update-scope) |
| R-RP3 pin with a change | Resolve: `changes: changes.any(/e/ e.file == m.file)` | caught by l2:resolve/ (resolve/rs-install-add-key, resolve/rs-workspace-shared-group) |
| R-NS8 nightly default | Resolve: `intent.toolchain.nightly ?? Bool.True` | caught by l2:resolve/ (resolve/rs-failures, resolve/rs-install-add-key, resolve/rs-update-scope, resolve/rs-workspace-shared-group) |
| R-C7 default age | Resolve: `intent.resolution.min_release_age ?? 172800` | caught by l2:resolve/ (resolve/rs-failures, resolve/rs-update-scope, resolve/rs-workspace-shared-group) |
| R-VA6 default strategy | Resolve: `intent.resolution.strategy ?? Highest` | caught by l2:resolve/ (resolve/rs-install-add-key, resolve/rs-update-scope, resolve/rs-want-platform) |
| R-CC7 talon.toml first | Resolve: `paths = header_files.concat(toml_files)` | caught by l2:resolve/ (resolve/rs-update-scope) |
| R-I5 add the key | Resolve: `Insert => Ok([{ file, op: Add({ alias: plan.alias,` | caught by l2:resolve/ (resolve/rs-install-add-key) |
| R-WS7 wants | Resolve: `wants = live_wants!(fx, built.wants)?` | caught by l2:resolve/ (resolve/rs-failures, resolve/rs-install-add-key, resolve/rs-want-platform) |
| R-SP1 held variable index | Resolve: `free_names = scoped.keep_if(/s/ s.free).keep_oks` | caught by l2:resolve/ (resolve/rs-install-add-key, resolve/rs-update-scope, resolve/rs-want-platform) |
| R-AD22 selector in talon.toml | Resolve: `selector: Ok(p.selector), no_pin` | caught by l2:resolve/ (resolve/rs-update-scope) |
| R-AD26 new talon.toml | Resolve: `Text.join(Text.dir_of(u.file), "talon.toml")` | NOT CAUGHT |
| R-AD22 selector range | Resolve: `Exact(version) => Ok("=${version}")` | NOT CAUGHT |
| R-SP5 selector series | Resolve: `Exact(version) if s.any_series => Ok(version)` | NOT CAUGHT |
| R-C9 highest use | Resolve: `if a.order_relative_to(b) == After u else best` | NOT CAUGHT |
| R-LF2 no write | Resolve: `if request.frozen { 			frozen!(fx, request, loaded` | INVALID (compile error) |
| R-CC7 nothing to change | Resolve: `if changed.is_empty() {` | INVALID (compile error) |
| R-PD6 talon.toml candidates | Resolve: `candidates = files.map(/f/ Intent.paths({ member:` | INVALID (compile error) |
| R-WS5 root role | Resolve: `Ok(_) => if t.path == root_toml Root else Member` | NOT CAUGHT |

caught 97 of 113, invalid 3
