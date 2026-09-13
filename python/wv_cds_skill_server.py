#!/usr/bin/env python3
"""wv_cds_skill_server.py - let an outside process send SKILL to Virtuoso.

Python port of Cadence's own example, "How to send a SKILL command to Virtuoso
via a TCP/IP socket" (Troubleshooting Article 2561). The original ships a Tcl
script called skillServer; this is the same protocol with no tclsh dependency,
since Virtuoso already needs python3 for this package.

Virtuoso starts this from wv_cds_skill_server.il with ipcBeginProcess, so:

  * our stdout is read by SKILL's data handler, and every line we write is
    EVALUATED AS SKILL. Never write diagnostics here - they go to stderr.
  * our stdin receives the replies, as "<channel> <result>".

Protocol, one line per message:

  client -> server : <a SKILL command>
  server -> SKILL  : <channel> <that command>
  SKILL  -> server : <channel> <result>
  server -> client : <result>

On connect the server announces itself the same way the original does, by
sending "<channel> abSkillServerConnection(\"addr\" \"port\")" up to SKILL, so
the first line a client reads back is the reply to that, not to its command.
Cadence's skillClientResult throws that first line away for this reason.

SECURITY, and this is not a formality: whatever arrives on this port is
executed as SKILL inside the user's Virtuoso session, with no authentication.
Cadence's own article says so - "It is completely open - and so is susceptible
to commands being sent to virtuoso without the person running virtuoso's
consent." The one mitigation applied here is binding to 127.0.0.1 only. The
original Tcl does a bare "socket -server listener $port", which listens on
every interface - on a networked machine that hands remote code execution to
anyone who can reach the port.

Port: $WV_CDS_SKILL_PORT, else $SKILLSERVPORT, else 8123 (the original's
default). --port overrides both.
"""

import os
import socket
import sys
import threading
import time

DEFAULT_PORT = 8123
HOST = "127.0.0.1"          # loopback only, see SECURITY above

_lock = threading.Lock()
_channels = {}


def log(msg):
    """Diagnostics go to stderr: stdout is the SKILL evaluation channel."""
    sys.stderr.write("wv_cds_skill_server: %s\n" % msg)
    sys.stderr.flush()


def to_virtuoso(line):
    """Send one line up to SKILL, which will evalstring it."""
    with _lock:
        sys.stdout.write(line + "\n")
        sys.stdout.flush()


def from_virtuoso():
    """Forward '<channel> <result>' lines from SKILL back to the client."""
    try:
        for raw in sys.stdin:
            line = raw.rstrip("\n")
            if not line:
                continue
            parts = line.split(" ", 1)
            token = parts[0]
            result = parts[1] if len(parts) > 1 else ""
            with _lock:
                conn = _channels.get(token)
            if conn is None:
                continue
            try:
                conn.sendall((result + "\n").encode("utf-8", "replace"))
            except OSError:
                pass
    except (OSError, ValueError) as exc:
        log("reading from Virtuoso failed: %s" % exc)
    # stdin reached EOF, which means the process that spawned us - Virtuoso,
    # through ipcBeginProcess - has exited. Nothing can be evaluated any more,
    # so stop: otherwise this process outlives Virtuoso and keeps the port
    # bound, and the next Virtuoso cannot bind it. The GUI would then talk to
    # an orphan whose SKILL side is gone and never see an answer.
    #
    # os._exit, not sys.exit: this runs on a worker thread, where sys.exit
    # would only end the thread and leave the process holding the socket.
    log("Virtuoso is gone - exiting so the port is released")
    os._exit(0)


def serve_client(conn, addr, token):
    with _lock:
        _channels[token] = conn
    try:
        # same announcement the Tcl original makes, so the client's first read
        # is the reply to this rather than to its own command
        to_virtuoso('%s abSkillServerConnection("%s" "%s")'
                    % (token, addr[0], addr[1]))
        stream = conn.makefile("r", encoding="utf-8", errors="replace")
        for line in stream:
            to_virtuoso("%s %s" % (token, line.rstrip("\n")))
    except OSError:
        pass
    finally:
        with _lock:
            _channels.pop(token, None)
        try:
            conn.close()
        except OSError:
            pass


def main(argv):
    port = int(os.environ.get("WV_CDS_SKILL_PORT")
               or os.environ.get("SKILLSERVPORT")
               or DEFAULT_PORT)
    if "--port" in argv:
        port = int(argv[argv.index("--port") + 1])

    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        srv.bind((HOST, port))
    except OSError as exc:
        log("cannot bind %s:%d - %s" % (HOST, port, exc))
        return 1
    srv.listen(8)
    log("listening on %s:%d" % (HOST, port))

    threading.Thread(target=from_virtuoso, daemon=True).start()

    n = 0
    while True:
        try:
            conn, addr = srv.accept()
        except OSError as exc:
            log("accept failed - %s" % exc)
            return 1
        n += 1
        threading.Thread(target=serve_client,
                         args=(conn, addr, "sock%d" % n),
                         daemon=True).start()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
