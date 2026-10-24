#!/usr/bin/env python3
"""Makes the stub `Consent.roc` of slice 025 from the file with the reference bodies: the bodies of the 5 new functions become `crash "todo"`.
Usage: mkstub-consent.py <reference Consent.roc> <stub Consent.roc>"""
import re, sys
src = open(sys.argv[1]).read()
for name in ["command_download", "required_want", "download_stop", "download_refused", "command_declined", "auto_install"]:
    one = re.search(r"\t" + name + r" = \|([a-z_]+)\| [^\n]*\n", src)
    if one and not one.group(0).rstrip().endswith("{"):
        src = src[:one.start()] + "\t" + name + " = |_" + one.group(1) + "| crash \"todo\"\n" + src[one.end():]
        continue
    pat = re.compile(r"(\t" + name + r" = \|)([a-z_]+)(\|)(.*?)\n\t\}\n", re.S)
    m = pat.search(src)
    assert m, name
    # a body that is one line (`match ... {` ... `}`) also ends with a line `\t}` at one tab
    src = src[:m.start()] + "\t" + name + " = |_" + m.group(2) + "| crash \"todo\"\n" + src[m.end():]
# the reference imports `Pin` for the bodies: the stub needs no import
src = src.replace("import Mode\nimport Pin\nimport Prompt", "import Mode\nimport Prompt", 1)
open(sys.argv[2], "w").write(src)
