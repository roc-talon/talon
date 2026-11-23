"""Slice 262a: the expected help texts of the tests, made by the rule of
docs/slices/262-cli-ux-fixes.md section 6.3 (one writer, so the L0 and L2 files agree).
Usage: python3 texts.py <key>   (key "" = the general text). Prints the text."""
import sys

GLOBAL = "Flags for every command: --json --yes --offline --quiet --registry <url|direct> --help"
GLOBAL_X = "Flags for every command: --yes --offline --quiet --registry <url|direct> --help"

ARGS = {
    "<name>[@<sel>]": "A package: an alias, owner/repo, host/path or a short name, with an optional selector (@1.2.3, @^1.2, @latest)",
    "<owner/app>[@<sel>]": "A Roc app on GitHub, with an optional selector",
    "<owner/app@ref>": "A Roc app on GitHub at a git ref (a branch, a tag or a commit)",
    "<key>": "A key of [tools] in talon.toml",
    "<args>": "Words that tln passes on as they are",
    "<channel>": "The name of a user channel (tln roc channel list). With none: the nightlies",
    "<tool>": "A tool name",
}

FLAGS = {
    "--file": ("--file <path>", "The project file"),
    "--frozen": ("--frozen", "Fetch the closure of the header, and change nothing (no names only)"),
    "--no-probe": ("--no-probe", "Run no probe: use only known facts"),
    "--no-check": ("--no-check", "Do not check the result"),
    "--snapshot": ("--snapshot <log:N|time>", "Hide the releases after a registry log size or a time"),
    "--strategy": ("--strategy highest|lowest", "Choose the highest or the lowest versions"),
    "--dry-run": ("--dry-run", "Show the changes, and write nothing"),
    "--slots": ("--slots <n>", "Run at most <n> probes at the same time"),
    "--as": ("--as <alias>", "The alias of the new entry (one name only)"),
    "--as tool install": ("--as <name>", "The binary name"),
    "--no-pin": ("--no-pin", "With an exact version: start there, with no pin"),
    "--platform": ("--platform", "The name is the platform of the app"),
    "--git": ("--git", "The operand is a git ref"),
    "--path": ("--path <dir>", "The directory of the app in the repository"),
    "--rename-keys": ("--rename-keys", "Rename the stale keys of talon.toml with no prompt"),
    "--allow-moves": ("--allow-moves", "Move held entries with no prompt"),
    "--allow-downloads": ("--allow-downloads", "Download the compilers that the command needs with no prompt"),
    "--roc": ("--roc pinned|installed", "Which compiler builds the app"),
    "--allow-unchecked": ("--allow-unchecked", "Use a cached build that was not checked online"),
    "--tool": ("--tool", "Add a project tool to [tools] of talon.toml"),
}

# key: (usage lines (operands, with FLAGS where [flags] goes), also, description, args, flags)
CMDS = {
    "install": (["[<name>[@<sel>]...] FLAGS", "--platform <name>[@<sel>] FLAGS", "--tool <owner/app>[@<sel>] FLAGS"],
                "tln add, tln i", "Add packages, or fetch the closure of the header",
                ["<name>[@<sel>]", "<owner/app>[@<sel>]"],
                ["--file", "--frozen", "--no-probe", "--no-check", "--snapshot", "--strategy", "--dry-run", "--slots", "--as", "--no-pin", "--platform", "--rename-keys", "--allow-moves", "--allow-downloads", "--tool"]),
    "roc update": (["[<channel>]"], "tln roc up", "Install the newest compiler release, and move the global default to it", ["<channel>"], []),
    "x": (["<owner/app>[@<sel>] FLAGS [-- <args>]", "<key> FLAGS [-- <args>]"], None, "Build a Roc app and run it once",
          ["<owner/app>[@<sel>]", "<args>", "<key>"], ["--slots", "--roc", "--allow-unchecked"]),
    "tool install": (["<owner/app>[@<sel>] FLAGS", "--git <owner/app@ref> FLAGS"], "tln tool add, tln tool i", "Build a Roc app and put it on PATH",
                     ["<owner/app>[@<sel>]", "<owner/app@ref>"], ["--slots", "--as tool install", "--git", "--path", "--roc", "--allow-unchecked"]),
    "tool rebuild": (["[<tool>]"], None, "Build tools again on the default compiler", ["<tool>"], []),
}

GROUPS = {
    "roc": ("Manage compilers", [
        ("install", "Install a compiler: a nightly, a release or a git ref (also: add, i)"),
        ("link", "Use a local roc build under a name"),
        ("use", "Check the project on a compiler and write the roc: pin of the header"),
        ("list", "Show the installed compilers (also: ls)"),
        ("remove", "Remove one compiler (also: rm)"),
        ("default", "Set the global default compiler"),
        ("update", "Install the newest compiler and move the global default (also: up)"),
        ("channel", "Add, remove or list compiler channels"),
    ]),
}

def block(rows):
    w = max(len(a) for a, _ in rows) + 2
    return ["  " + a.ljust(w) + b for a, b in rows]

def command(key):
    if key in GROUPS:
        desc, subs = GROUPS[key]
        out = [f"Usage: tln {key} <command> [words]", "", desc + ".", "", "Commands:"]
        out += block(subs)
        out += ["", f"Run tln {key} <command> --help for the usage of one command.", GLOBAL]
        return "\n".join(out) + "\n"
    usage, also, desc, args, flags = CMDS[key]
    mark = " [flags]" if flags else ""
    lines = []
    for i, u in enumerate(usage):
        u = u.replace(" FLAGS", mark)
        if flags and "[flags]" not in u:
            u = u + mark
        head = "Usage: " if i == 0 else "       "
        lines.append(f"{head}tln {key} {u}")
    if also:
        lines.append(f"Also: {also}")
    lines += ["", desc + ".", ""]
    if args:
        lines.append("Arguments:")
        lines += block([(a, ARGS[a]) for a in args])
        lines.append("")
    if flags:
        lines.append("Flags:")
        lines += block([FLAGS[f] for f in flags])
        lines.append("")
    lines.append(GLOBAL_X if key == "x" else GLOBAL)
    return "\n".join(lines) + "\n"

GENERAL = """Usage: tln [flags] <command> [words]
       tln help <command>    Show the usage of one command (also: tln <command> --help)

Commands:
  init      Make a new app or package
  install   Add packages, or fetch the closure of the header (also: add, i)
  remove    Remove a package (also: rm)
  update    Move the packages of this project within the ranges (also: up)
  upgrade   Move the packages and the compiler of this project to the newest releases
  outdated  Show the current, wanted and latest versions
  why       Show why a package is in the closure
  probe     Probe an entry on the selected compiler
  list      Show the closure (also: ls)
  patch     Edit a copy of a dependency
  verify    Resolve and probe, and write nothing
  path      Print the directory of a header entry
  run       Run a script of talon.toml
  x         Build a Roc app and run it once
  publish   Register a release
  audit     Report yanked and changed releases
  roc       Manage compilers: install, link, use, list, remove, default, update, channel
  tool      Manage global tools: install, list, update, rebuild, remove
  cache     Manage the cache: gc, clean, list, dir
  setup     Install the roc proxy and the PATH line
  yank      Yank a release
  move      Set the successor of a package name
  share     Show or change the sharing of probe results: on, off, login, logout, forget
  help      Show this text, or the usage of one command

To update tln itself, run: tln tool update talon
(tln upgrade changes the project, not tln.)

Flags for every command:
  --json  --yes  --offline  --quiet  --registry <url|direct>  --help (-h)  --version
  --file <path>  The project file, for a command that uses a project
"""

if __name__ == "__main__":
    k = sys.argv[1] if len(sys.argv) > 1 else ""
    sys.stdout.write(GENERAL if k == "" else command(k))
