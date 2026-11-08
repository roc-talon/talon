# CLI state formats: upgrade and downgrade audit

Date: 2026-11-08. Scope: the files and dirs that `tln` (cli/) writes or reads as state, and how versions N, N+1 and N-1 of `tln` share them. Read-only audit: no code, test or design change.

Spec: CLI 6.1 (R-LY1 to R-LY3, R-TF1 to R-TF7, R-IX1 to R-IX7), CLI 7.4 (R-CC1 to R-CC12), Design 4.2 and 4.3.

Design policy in short (R-TF1 to R-TF4):

| Item | Design rule |
| --- | --- |
| JSON files | Top-level integer `format`. A new field keeps the same `format` and is kept on rewrite. A newer `format`: a file that Talon can make again is ignored. For each other file, Talon stops with exit 19. |
| `compat.db` | `PRAGMA user_version`. A new table keeps the same version (R-TF7). |
| `talon.toml`, `config.toml` | No version. An unknown key gives a warning. A known key with a value of an unknown form gives exit 19. |

## 1. Inventory

Paths are relative to the repo root. "kept" means that a rewrite keeps the unknown fields.

| File | Writer (path:line) | Reader (path:line) | Version marker | Unknown-field policy | Risk |
| --- | --- | --- | --- | --- | --- |
| `talon.toml` (project file, in git) | cli/lib/IntentEdit.roc:13, cli/lib/ToolsToml.roc:74 | cli/lib/Intent.roc:101, cli/lib/ToolsToml.roc:182 | none | Unknown key: warning. Unknown value form: exit 19. A rewrite of a `[tools]` entry drops unknown subkeys. | High (F3, F4, F8) |
| App header (`roc:` pin, URLs) | cli/lib/InstallWrite.roc:158 | cli/lib/Locked.roc, cli/lib/Pin.roc:170 | none | Span edit. Unmanaged entries are kept (R-H1, R-H4). | Low |
| `config.toml` | cli/lib/RocManage.roc:228 (with cli/lib/Manage.roc:169), cli/lib/RocInstall.roc:490, cli/lib/ShareFlow.roc:191 | cli/lib/ConfigToml.roc:20 | none | Unknown key: warning, kept (span edit). Unknown value form: exit 19. | Medium (F13) |
| `talon/projects.json` | cli/lib/Known.roc:67, cli/lib/Projects.roc:111 | cli/lib/Projects.roc:84 | `format` 1 | Kept (top fields and item fields) | High (F1) |
| `tools.json` (data dir) | cli/lib/ToolsJson.roc:393, cli/lib/BinRecord.roc:49 | cli/lib/ToolsJson.roc:58, cli/lib/Setup.roc:229, cli/lib/BinRecord.roc:76 | `format` 1 | Fields kept. An unknown `source.kind` gives exit 19. | High (F2) |
| `share.json` (contributor id, JWT) | cli/lib/ShareJson.roc:84, cli/lib/ShareFlow.roc:224 | cli/lib/ShareJson.roc:91 | `format` (a constant) | Kept | Medium (F5) |
| `talon/path-roc.json` | cli/lib/PathRoc.roc:61 | cli/lib/PathRoc.roc:142 | `format` 1 | Top fields kept. Row fields dropped. | Low (F12) |
| `talon/index/registry/<origin>/toolchains.json` | cli/lib/RegistryToolchains.roc:140 | cli/lib/RegistryToolchains.roc:57 | `format` 1 | Kept (top fields and row fields) | Low |
| `talon/index/.../get/<key>.json` and `<key>.meta` | cli/lib/RegistryCache.roc:47, cli/lib/Github.roc:239 | cli/lib/RegistryCache.roc:62 | none (cache) | An unknown meta line is ignored | Low |
| `talon/x/<digest>/` manifest | cli/lib/XCache.roc:77, cli/lib/ToolBinUse.roc:84 | cli/lib/XCache.roc:100, cli/lib/ToolBinUse.roc:98 | `format` 1 | Talon can make it again | Low |
| `toolchains/<id>/.talon.json` | cli/lib/Toolchain.roc:312, cli/lib/RocInstall.roc:415, cli/lib/Zig.roc:294, cli/lib/GitBuild.roc:69, cli/lib/Link.roc:101 | cli/lib/Manage.roc:342, cli/lib/Compiler.roc:252, cli/lib/ResolveSelect.roc:101, cli/lib/Link.roc:123 | `format` 1. Only Link reads it. | The other readers ignore `format` | Medium (F7) |
| `toolchains/<id>/.last-use` | cli/lib/Launch.roc:80 | cli/lib/Manage.roc:361, cli/lib/Gc.roc:321 | none (one UTC line) | Bad text: GC keeps the compiler | Low |
| `toolchains/<id>/` dir names | cli/lib/RocInstall.roc, cli/lib/Zig.roc | cli/lib/Compiler.roc:246, cli/lib/CacheGc.roc:97, cli/lib/Gc.roc:111 | id prefix only | Unknown name: not listed, never removed by GC | Low (F14) |
| `talon/compat.db` | cli/RealDb.roc:309, cli/RealDb.roc:343 | cli/RealDb.roc:151 | `user_version` 1 | Columns read by name. New tables use `IF NOT EXISTS`. A row with an unknown enum word is ignored. | Medium (F6, F11) |
| `<item>.lock/` (`owner`, `beat`) | cli/RealLocks.roc:17, cli/lib/Lock.roc:40 | cli/lib/Lock.roc:29 | none | n/a | Medium (F10) |
| Temp names (`*.<16hex>.tmp`, `*.stale`, `talon/tmp/`, `.del`) | cli/RealFx.roc (`write_atomic!`), cli/RealLocks.roc | The sweeps of GC and of each start | none | n/a | Low (F15) |

## 2. Findings

| Id | Risk | File | Problem | Failure scenario | Fix idea or design question |
| --- | --- | --- | --- | --- | --- |
| F1 | High | `projects.json` | The `roc` proxy records the project before it selects a compiler (cli/lib/Proxy.roc:44 step 5, cli/lib/Known.roc:64). `Projects.record` reads the file with `TalonFile.open` first (cli/lib/Projects.roc:84). A newer `format` gives exit 19, also when no write is necessary. | The user runs tln N+1 once, and it writes `projects.json` with format 2. Then the user goes back to N (`install.sh --version`, R-S4). Each `roc build` in each project fails with exit 19. | The design says to do this (R-TF3). Design question: `projects.json` is only a hint for GC. With a newer file, can Talon skip the record and let GC keep all compilers, at least in the proxy? |
| F2 | High | `tools.json` | `source.kind` is a closed enum (cli/lib/ToolsJson.roc:302-313). One tool with an unknown kind stops the read of the whole file (cli/lib/ToolsJson.roc:248) with exit 19. | N+1 adds `"kind":"registry"` and keeps `format` 1 (R-TF2: a new field). On N, `tln tool ls`, `tln tool install` and `tln tool update` stop for all tools. | Design question: is a new enum value a changed meaning (a new `format`) or a new field? Fix idea: list an entry with an unknown kind as "needs a newer tln", keep it on write, and do not change it. |
| F3 | High | `talon.toml` | No key gives the lowest tln version that a project needs. R-TF4 gives exit 19 for each new value form: `strategy` (cli/lib/Intent.roc:375), the compiler range (cli/lib/Intent.roc:315), the snapshot form, the range syntax. The file is in git. | A member on N+1 writes a new value form. All members on N, and CI that pins N, get exit 19. The message does not tell them to update tln. | Design question: a key such as `min-version`, or a rule that the exit 19 message names the newer tln. |
| F4 | High | `talon.toml` `[tools] bin` | The target list is closed: `ToolBin.all_targets` (cli/lib/ToolBin.roc:21), checked at cli/lib/ToolsToml.roc:254. An unknown target key: exit 19 (R-PT18). | N+1 adds a 6th target (`arm64win`). Each N user of that project gets exit 19. | Fix idea: an unknown target key gives a warning and is kept on rewrite. Design question: R-PT18. |
| F5 | High | `tools.json`, `share.json`, `projects.json`, `compat.db` | One version number for read and write. The repair path `install.sh --version <old>` runs `tln setup`, which reads `tools.json` (cli/lib/Setup.roc:229): exit 19. | N+1 bumps `tools.json` to format 2 and has a bad bug. The repair to N fails. | R-TF3 accepts this. Design question: a write-down step, or a read format and a write format for each file. |
| F6 | Medium | `compat.db` | `start!` checks `user_version > format` also for reads (cli/RealDb.roc:155). | N+1 rebuilds `facts` with a new key, `user_version` 2. Each N command that reads facts stops with exit 19. | Fix idea: a separate lowest reader version. |
| F7 | Medium | `toolchains/<id>/.talon.json` | Most readers do not check `format`: cli/lib/Manage.roc:342, cli/lib/Compiler.roc:252, cli/lib/Gc.roc:332. Only cli/lib/Link.roc:123 uses `TalonFile.open`. | N+1 changes the meaning of `published_at`. N orders nightlies wrong and GC uses a wrong age, with no message. | Fix idea: read each with `TalonFile.open`. Design question: what a newer file gives (exit 19, or "unknown"). |
| F8 | Medium | `talon.toml` `[tools]` | `ToolsToml.put` replaces the whole inline entry with `{ ref, url }` and keeps only `bin = false` (cli/lib/ToolsToml.roc:74-84, :226). | N+1 adds a subkey. N deletes it on `tln tool update`. | Design question: does "keep unknown fields" apply to a `[tools]` entry? |
| F9 | Medium | All JSON files | The format number is the literal `1` in many readers and writers (cli/lib/Setup.roc:229, cli/lib/ToolsJson.roc:228, cli/lib/BinRecord.roc:76, cli/lib/Link.roc:123, cli/lib/XCache.roc:100, cli/lib/ToolBinUse.roc:98, cli/lib/BinRecord.roc:49, cli/lib/ToolsJson.roc:393, cli/lib/Toolchain.roc:312, cli/lib/Zig.roc:294, cli/lib/GitBuild.roc:69, cli/lib/Link.roc:101). No migration step. | A bump misses one writer, which writes new data with label 1. | One constant and one `migrate` function for each file kind. No design question. |
| F10 | Medium | Lock dirs | Lock is the dir `<item>.lock/` (R-CC12). R-CC3: a new mechanism changes only the real `Fx`. | N+1 uses an OS lock, N the dir lock. Both change one file at once. | Design question: R-CC3 transition. |
| F11 | Low | `compat.db` | `outcome` and `source` words are closed (cli/lib/Db.roc:153, :169). A row with an unknown word is dropped, then the `Replace` upsert (cli/RealDb.roc:349) writes over it. | N replaces an N+1 `timeout` row with `hang`. | Fix idea: replace only when the old word is known. |
| F12 | Low | `path-roc.json` | A rewrite drops unknown row fields (cli/lib/PathRoc.roc:160). | N+1 must hash again. | Keep the pairs of each row. |
| F13 | Medium | `config.toml` | `default-roc` must be a known id kind (cli/lib/ConfigToml.roc:44, :81). Other closed forms: `gc-age`. Read by every tln version, also the proxy. | N+1 writes a new id kind. On N each command and `roc` run exits 19. | Design question: as F3. |
| F14 | Low | `toolchains/` names | Dir names encode the id scheme with no marker (cli/lib/Compiler.roc:246, cli/lib/Gc.roc:111). | N never lists or removes N+1 dirs of a new kind. | GC reports unknown dirs. |
| F15 | Low | Temp and stale names | Sweeps match fixed name forms. | N never removes temp files of a new N+1 form. | Keep the forms stable or put them in the design. |

## 3. What is good

| Item | Where |
| --- | --- |
| One reader for the JSON files of Talon | cli/lib/TalonFile.roc:20 |
| A rewrite keeps unknown fields in `projects.json`, `tools.json`, `share.json` and `toolchains.json` | cli/lib/Projects.roc:80, cli/lib/ToolsJson.roc:325, cli/lib/ShareJson.roc:84, cli/lib/RegistryToolchains.roc:46 |
| Span edits of `talon.toml`, `config.toml` and the header keep comments and unknown keys | cli/lib/IntentEdit.roc:5, R-CC6, R-H1 |
| `compat.db` reads columns by name, `IF NOT EXISTS`, version check before the WAL switch | cli/RealDb.roc:148, cli/RealDb.roc:309 |
| Each write uses a temp file and a rename (R-CC1). An install writes `.talon.json` last (R-CC4). | cli/lib/Fx.roc:21, cli/lib/RocInstall.roc:402 |
