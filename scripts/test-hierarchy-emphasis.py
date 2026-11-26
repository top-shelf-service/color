#!/usr/bin/env python3
"""Exercise the actual terminal renderer through a pseudo-terminal (stdlib)."""
import errno
import os
import pty
import select
import subprocess
import sys
import time
from pathlib import Path

loader = Path(sys.argv[1]).resolve()
runtime = loader.parent
env = dict(os.environ)
for key in ("COLOR_RUNTIME_HOME", "COLOR_ROLE_SCHEMA_PATH", "COLOR_LAWS_PATH",
            "COLOR_PROMPT_DISABLE", "COLOR_QUIET"):
    env.pop(key, None)
env["TERM"] = "xterm-256color"

def run(body, tty=False):
    args = ["bash", "-c", 'set -e; source "$1"; shift; ' + body, "test", str(loader)]
    if not tty:
        return subprocess.check_output(args, env=env, stderr=subprocess.STDOUT, timeout=5)
    master, slave = pty.openpty()
    proc = None
    try:
        proc = subprocess.Popen(args, env=env, stdout=slave, stderr=slave)
        os.close(slave)
        slave = None
        chunks = []
        deadline = time.monotonic() + 5
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not select.select([master], [], [], remaining)[0]:
                raise TimeoutError("PTY test timed out")
            try:
                data = os.read(master, 4096)
            except OSError as exc:
                if exc.errno == errno.EIO:
                    break
                raise
            if not data:
                break
            chunks.append(data)
        assert proc.wait(timeout=5) == 0, b"".join(chunks)
        return b"".join(chunks).replace(b"\r\n", b"\n")
    finally:
        if proc is not None and proc.poll() is None:
            proc.kill()
            proc.wait()
        os.close(master)
        if slave is not None:
            os.close(slave)

body = 'color_apply warnings WARNING; color_apply javascript app.js; color_apply success SUCCESS; color_apply nodejs node; color_apply errors ERROR; color_apply not_registered fallback; printf "plain\n"'
expected = (b"\x1b[1m\x1b[38;2;255;255;0mWARNING\x1b[0m\n"
            b"\x1b[38;2;247;223;30mapp.js\x1b[0m\n"
            b"\x1b[1m\x1b[38;2;0;255;0mSUCCESS\x1b[0m\n"
            b"\x1b[38;2;104;160;99mnode\x1b[0m\n"
            b"\x1b[1m\x1b[38;2;255;46;46mERROR\x1b[0m\n"
            b"fallback\nplain\n")
assert run(body, tty=True) == expected, "TTY hierarchy or reset mismatch"
assert run(body) == b"WARNING\napp.js\nSUCCESS\nnode\nERROR\nfallback\nplain\n", "redirected output changed"
subprocess.run([str(runtime / "install_hook.sh"), "test_alert", "alert", "alert", "--hex", "#FFAA55"], env=env, check=True, stdout=subprocess.DEVNULL, timeout=5)
assert run('color_reload; color_apply test_alert custom', tty=True) == b"\x1b[1m\x1b[38;2;255;170;85mcustom\x1b[0m\n", "registered alert not emphasized"
# An old cache is readable but has no hierarchy information. Rebuild it even
# when it is newer than the schema; subsequent loads must use the new format.
cache = runtime / "cache" / "roles.sh"
cache.write_text("COLOR_ROLE_HEX['warnings']='#FFFF00'\n")
assert run('color_apply warnings WARNING', tty=True) == expected.splitlines(keepends=True)[0], "old cache not migrated"
print("Hierarchy emphasis contract passed.")
