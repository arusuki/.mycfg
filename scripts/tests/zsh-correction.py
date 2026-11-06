#!/usr/bin/env python3
"""Exercise real Enter/Tab/Space behavior in an isolated Zsh pseudo-terminal."""

import argparse
import os
from pathlib import Path
import pty
import re
import select
import shlex
import shutil
import signal
import subprocess
import tempfile
import time


SCRIPT = Path(__file__).resolve().parents[1] / "zsh-correction.zsh"
ZSH = shutil.which("zsh")
assert ZSH and shutil.which("git"), "Zsh and Git must be installed"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--oh-my-zsh", action="store_true", help="also load the installed Oh My Zsh and configured plugins")
args = parser.parse_args()


class Shell:
    def __init__(self, env, directory):
        self.pending = b""
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.chdir(directory)
            os.execve(ZSH, [ZSH, "-dfi"], env)

    def send(self, value):
        os.write(self.fd, value.encode())

    def expect(self, value):
        target = value.encode()
        deadline = time.monotonic() + 15
        while target not in self.pending:
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not select.select([self.fd], [], [], remaining)[0]:
                raise AssertionError(f"Missing {value!r}; output: {self.pending!r}")
            block = os.read(self.fd, 65536)
            if not block:
                raise AssertionError(f"Shell exited while waiting for {value!r}")
            self.pending += block
        end = self.pending.index(target) + len(target)
        result, self.pending = self.pending[:end], self.pending[end:]
        # Oh My Zsh emits terminal title/cwd OSC sequences between output lines.
        return re.sub(r"\x1b\][^\x1b\x07]*(?:\x07|\x1b\\)", "", result.decode(errors="replace"))

    def ready(self):
        return self.expect("MYCFG_READY> ")

    def answer(self, value):
        # Zsh prints SPROMPT before checking for typeahead, which forces 'n'.
        # Let it enter its character read before sending the response.
        time.sleep(0.1)
        self.send(value)

    def close(self):
        os.kill(self.pid, signal.SIGTERM)
        os.close(self.fd)
        os.waitpid(self.pid, 0)


with tempfile.TemporaryDirectory(prefix="mycfg-correction-") as temporary:
    root = Path(temporary)
    (root / "bin").mkdir()
    demo = root / "bin/mycfgdemo"
    demo.write_text("#!/bin/sh\nprintf 'COMMAND_OK\\n'\n")
    demo.chmod(0o755)
    (root / "README.md").write_text("FILE_OK\n")
    (root / "alpha.txt").touch()
    (root / "alphi.txt").touch()
    env = {
        "HOME": temporary,
        "ZDOTDIR": temporary,
        "PATH": str(root / "bin") + os.pathsep + os.environ["PATH"],
        "TERM": "xterm",
        "LC_ALL": "C",
        "MYCFG_CORRECTION": str(SCRIPT),
    }
    subprocess.run(
        [ZSH, "-dfc", 'source "$MYCFG_CORRECTION"; '
         '[[ ! -o correct && ! -o correct_all ]] && (( ! $+functions[compdef] ))'],
        env=env, check=True,
    )
    fixture = root / "setup.zsh"
    prelude = ""
    if args.oh_my_zsh:
        env.update({
            "ZSH": str(Path.home() / ".oh-my-zsh"),
            "ZSH_CUSTOM": str(Path.home() / "zsh_custom"),
            "ZSH_CACHE_DIR": temporary,
            "ZSH_COMPDUMP": str(root / "zcompdump"),
        })
        prelude = '''
DISABLE_AUTO_UPDATE=true
plugins=(git zsh-autosuggestions zsh-syntax-highlighting history-substring-search)
source "$ZSH/oh-my-zsh.sh"
'''
    fixture.write_text(prelude + '''
bindkey -e
alias mycfgkeep='nocorrect print -r --'
alias mycfgone='print -r -- ALIAS_OK'
mycfgfunction() { print -r -- FUNCTION_OK; }
CORRECT_IGNORE='_private*'
CORRECT_IGNORE_FILE='*.bak'
source "$MYCFG_CORRECTION"
compinit() { print -u2 -- UNEXPECTED_COMPINIT; return 99; }
source "$MYCFG_CORRECTION"
[[ $aliases[mycfgkeep] == 'nocorrect print -r --' &&
   $CORRECT_IGNORE == '_private*' && $CORRECT_IGNORE_FILE == '*.bak' ]] || exit 1
_mycfg_capture() {
  print -r -- "BUFFER<${BUFFER}>"
  BUFFER=''
  zle .accept-line
}
zle -N _mycfg_capture
bindkey '^X^B' _mycfg_capture
bindkey -M viins '^X^B' _mycfg_capture
PROMPT='MYCFG_READY> '
RPROMPT=''
''')
    shell = Shell(env, temporary)
    try:
        shell.send("source " + shlex.quote(str(fixture)) + "\n")
        assert "UNEXPECTED_COMPINIT" not in shell.ready()
        # Reload after plugin precmd hooks have already wrapped the widgets.
        shell.send('source "$MYCFG_CORRECTION"\n')
        assert "UNEXPECTED_COMPINIT" not in shell.ready()

        # A lone bare command corrects and executes immediately, including
        # surrounding whitespace or a cursor moved away from the word's end.
        for typed in ["mycfgdmeo\n", "  mycfgdmeo\x16 \n", "mycfgdmeo\x01\r"]:
            shell.send(typed)
            output = shell.ready()
            assert "COMMAND_OK" in output and "zsh: correct " not in output, output

        for typed, expected in [("mycfgone", "ALIAS_OK"), ("mycfgfunction", "FUNCTION_OK")]:
            shell.send(typed + "\n")
            output = shell.ready()
            assert expected in output and "zsh: correct " not in output, output

        # Bypass Space correction to verify that a command WITH an argument
        # still requires confirmation when Enter is pressed.
        shell.send("mycfgdmeo\x16 argument\n")
        shell.expect('correct "mycfgdmeo" to "mycfgdemo"?')
        shell.expect("[y=yes, n=no, a=abort, e=edit] ")
        shell.answer("y")
        output = shell.ready()
        assert "COMMAND_OK" in output, output

        shell.send("\x1b[200~mycfgdmeo; :\x1b[201~\n")
        shell.expect("[y=yes, n=no, a=abort, e=edit] ")
        shell.answer("a")
        assert "COMMAND_OK" not in shell.ready()

        shell.send("cat READEM.md\n")
        shell.expect('correct "READEM.md" to "README.md"?')
        shell.expect("[y=yes, n=no, a=abort, e=edit] ")
        shell.answer("y")
        output = shell.ready()
        assert "FILE_OK" in output, output

        # Enter must not accept a correction without an explicit 'y'.
        shell.send("print -r -- READEM.md\n")
        shell.expect("[y=yes, n=no, a=abort, e=edit] ")
        shell.answer("\r")
        output = shell.ready()
        assert "\r\nREADEM.md\r\n" in output, output

        shell.send("cat READEM.md\n")
        shell.expect("[y=yes, n=no, a=abort, e=edit] ")
        shell.answer("a")
        assert "FILE_OK" not in shell.ready()

        shell.send("cat README.md\n")
        output = shell.ready()
        assert "FILE_OK" in output and "zsh: correct " not in output, output

        shell.send("nocorrect print -r -- READEM.md\n")
        output = shell.ready()
        assert "\r\nREADEM.md\r\n" in output and "zsh: correct " not in output, output

        shell.send("mycfgkeep READEM.md\n")
        output = shell.ready()
        assert "\r\nREADEM.md\r\n" in output and "zsh: correct " not in output, output

        # Capture ZLE's buffer after Tab, without executing completed commands.
        for typed, expected in [
            ("mycfgdmeo", "mycfgdemo"),
            ("cat READEM.md", "cat README.md"),
            ("git statsu", "git status"),
            ("git --hlep", "git --help"),
            ("git stat", "git status"),
        ]:
            shell.send(typed + "\t\x18\x02")
            shell.expect("BUFFER<")
            actual = shell.expect(">")[:-1].strip()
            assert actual == expected, (typed, actual, expected)
            shell.ready()

        # Space corrects only a unique typo and never executes the buffer.
        for typed, expected in [
            ("mycfgdmeo ", "mycfgdemo "),
            ("cat READEM.md ", "cat README.md "),
            ("git statsu ", "git status "),
            ("git --hlep ", "git --help "),
            ("git stat ", "git stat "),  # Valid prefix is not a typo.
            ("git status  ", "git status  "),
            ("cat alphx.txt ", "cat alphx.txt "),  # Ambiguous.
            ("git qzxvbn ", "git qzxvbn "),  # No candidate.
            ("git statsu\x16 ", "git statsu "),  # Quoted literal space.
            ("nocorrect cat READEM.md ", "nocorrect cat READEM.md "),
            ("mycfgkeep READEM.md ", "mycfgkeep READEM.md "),
            ("print 'READEM.md ", "print 'READEM.md "),
            ('print "READEM.md" ', 'print "READEM.md" '),
            ("cat READEM\\ file ", "cat READEM\\ file "),
            ("print $READEM ", "print $READEM "),
            ("git statsu\x01 ", " git statsu"),  # Mid-line insertion.
            ("\x1b[200~mycfgdmeo statsu \x1b[201~", "mycfgdmeo statsu "),
        ]:
            shell.send(typed + "\x18\x02")
            shell.expect("BUFFER<")
            actual = shell.expect(">")[:-1]
            assert actual == expected, (typed, actual, expected)
            shell.ready()

        shell.send("bindkey -v\n")
        shell.ready()
        shell.send("mycfgdmeo\r")
        output = shell.ready()
        assert "COMMAND_OK" in output and "zsh: correct " not in output, output
        shell.send("git statsu \x18\x02")
        shell.expect("BUFFER<git status >")
        shell.ready()

        shell.send("MYCFG_SPACE_CORRECTION=off\n")
        shell.ready()
        shell.send("git statsu \x18\x02")
        shell.expect("BUFFER<git statsu >")
        shell.ready()
    finally:
        shell.close()

print("Zsh correction: bare-command autocorrection, argument confirmation, Tab, Space, bypass, reload and noninteractive checks passed")
