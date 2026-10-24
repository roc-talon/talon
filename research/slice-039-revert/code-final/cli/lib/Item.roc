## An item in the directory layout (CLI 6.1, R-LY1 and R-LY2). `Roots.item` gives the path of an item.
## The path of an item is also the item name of a lock (`Fx.lock!`, R-CC3 point 4).
##
## | Tag | Path |
## | --- | --- |
## | `Package(hash)` | `<cache>/packages/<hash>` |
## | `PackageDeps(hash)` | `<cache>/packages/<hash>.deps.json` |
## | `Compat(id)` | `<build>/compat-<id>`: the only item under `build` (R-CR1) |
## | `Toolchain(id)` | `<cache>/toolchains/<id>` |
## | `ToolchainRoc(id)` | `<cache>/toolchains/<id>/roc` |
## | `ToolchainMeta(id)` | `<cache>/toolchains/<id>/.talon.json` |
## | `ToolchainLastUse(id)` | `<cache>/toolchains/<id>/.last-use` |
## | `Zig(version)` | `<cache>/toolchains/zig-<version>` |
## | `Index` | `<cache>/talon/index` |
## | `CompatDb` | `<cache>/talon/compat.db` |
## | `ProjectsJson` | `<cache>/talon/projects.json` |
## | `PathRocJson` | `<cache>/talon/path-roc.json` |
## | `TalonTmp(hex)` | `<cache>/talon/tmp/<hex>` |
## | `Gc` | `<cache>/talon/gc` (its lock is `gc.lock`) |
## | `XBuild(digest)` | `<cache>/talon/x/<digest>` |
## | `Config` | `<config>/config.toml` |
## | `Bin` | `<data>/bin` |
## | `ToolsJson` | `<data>/tools.json` |
## | `ShareJson` | `<data>/share.json` |
Item := [
	Package(Str),
	PackageDeps(Str),
	Compat(Str),
	Toolchain(Str),
	ToolchainRoc(Str),
	ToolchainMeta(Str),
	ToolchainLastUse(Str),
	Zig(Str),
	Index,
	CompatDb,
	ProjectsJson,
	PathRocJson,
	TalonTmp(Str),
	Gc,
	XBuild(Str),
	Config,
	Bin,
	ToolsJson,
	ShareJson,
].{
	is_eq : _
}
