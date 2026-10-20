#!/usr/bin/env python3
"""Run a command under a pseudo terminal, for the L3 tag `tty` (TESTING.md 3.2).

Usage: ptyrun.py <answers file or -> <command> [args...]

stdin, stdout and stderr of the command are the terminal. The lines of the answers file are
written to the terminal as input. Echo is off, and a newline is not changed to CR LF, so the
output is the plain text of stdout and stderr in one stream. The exit code is the code of the command.
"""
import os
import pty
import select
import sys
import termios


def main():
    answers_file, command = sys.argv[1], sys.argv[2:]
    answers = b""
    if answers_file != "-" and os.path.exists(answers_file):
        with open(answers_file, "rb") as f:
            answers = f.read()
    pid, fd = pty.fork()
    if pid == 0:
        attrs = termios.tcgetattr(0)
        attrs[1] &= ~termios.OPOST
        attrs[3] &= ~termios.ECHO
        termios.tcsetattr(0, termios.TCSANOW, attrs)
        os.execvp(command[0], command)
    # The terminal of the command is the slave side: turn echo off from here too.
    attrs = termios.tcgetattr(fd)
    attrs[1] &= ~termios.OPOST
    attrs[3] &= ~termios.ECHO
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    if answers:
        os.write(fd, answers)
    out = sys.stdout.buffer
    while True:
        ready, _, _ = select.select([fd], [], [], 60)
        if not ready:
            os.kill(pid, 9)
            break
        try:
            data = os.read(fd, 4096)
        except OSError:
            break
        if not data:
            break
        out.write(data)
        out.flush()
    _, status = os.waitpid(pid, 0)
    sys.exit(os.waitstatus_to_exitcode(status))


main()
