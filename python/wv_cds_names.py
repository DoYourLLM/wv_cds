#!/usr/bin/env python3
"""wv_cds_names.py - ask a running wv (Custom WaveView) which signals it is
still displaying, and print their names.

Replaces the former wv_cds_names.sh. The wv side is a single Tcl command sent
over the same plain RPC: line protocol every other wv_cds script uses, so the
logic lives in a language that can be unit-tested without a wv at all.

It walks ::wv_cds_lines, the name -> line objects map wv_cds_plot.sh maintains
inside wv, and keeps a name when at least one of its line objects is still
alive. A line you deleted in the wv GUI answers the empty string, so what comes
out is exactly what wv is still showing - the same set wv_cds_plot.sh will skip
as "already plotted".

Only sx_get_name is used. Nothing here walks the waveview (sx_first_panel /
sx_first_line / sx_next_*) - those make wv recompute its layout, which blocks
the interpreter the RPC server runs on, and the call hangs.

Output, one line on stdout:
    <n> <name> <name> ...   the count first, then the names
                            (just "0" when this tool has nothing on screen)
    refused                 nothing is listening on the port

Exit status is 0 only when wv actually answered.

The count is what lets the SKILL caller tell the two empty cases apart:
parseString("") and a "refused" reply are BOTH nil there, so without it
"wv answered, nothing is displayed" (clear the probes) would be
indistinguishable from "wv did not answer" (leave the probes alone).
"""

import os
import socket
import sys

RPC_HOST = "127.0.0.1"
RPC_PORT = int(os.environ.get("WV_CDS_RPC_PORT") or 61888)
TIMEOUT = 10.0

# Variables are wvc_-prefixed because wv_rpc_server.tcl runs this with
# uplevel #0, so each one becomes a global in wv's own interpreter.
TCL = (
    "set wvc_out {}"
    " ; if {[info exists ::wv_cds_lines]} {"
    " foreach wvc_nm [dict keys $::wv_cds_lines] {"
    " foreach wvc_l [dict get $::wv_cds_lines $wvc_nm] {"
    " set wvc_alive 0"
    " ; if {![catch {sx_get_name $wvc_l} wvc_n2]}"
    " { if {$wvc_n2 ne \"\"} { set wvc_alive 1 } }"
    " ; if {$wvc_alive} { lappend wvc_out $wvc_nm ; break } } } }"
    " ; set wvc_out [linsert $wvc_out 0 [llength $wvc_out]]"
    " ; set wvc_out"
)


def ask(command, host=RPC_HOST, port=RPC_PORT, timeout=TIMEOUT):
    """Send one plain-protocol RPC command, return wv's single-line reply.

    Raises OSError when the port is dead or wv closes without answering.
    """
    with socket.create_connection((host, port), timeout=timeout) as sock:
        sock.sendall(("RPC:%s\n" % command).encode("utf-8"))
        stream = sock.makefile("r", encoding="utf-8", errors="replace")
        line = stream.readline()
    if line == "":
        raise OSError("wv closed the connection without answering")
    return line.rstrip("\n")


def main():
    try:
        reply = ask(TCL)
    except OSError as exc:
        # "refused" is the token the SKILL side looks for; the explanation
        # goes to stderr, which ipcReadProcess merges in but which is ignored
        # once the first token says refused.
        sys.stdout.write("refused\n")
        sys.stderr.write(
            "wv_cds_names.py: nothing listening on %s:%d - %s\n"
            % (RPC_HOST, RPC_PORT, exc))
        return 1
    sys.stdout.write(reply + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
