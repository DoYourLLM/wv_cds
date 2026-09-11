#!/usr/bin/env python3
"""test_add_client.py - send "add <signal>" lines to a running wv_cds_gui.

Usage:
    python3 test_add_client.py net1 net2 I0.I1.net3
    printf 'add I0.I1.net1\nnet2\n' | python3 test_add_client.py

Each argument (or each non-empty stdin line) is sent as one "add <name>"
line to the GUI's external-add listener (see WV_CDS_LISTEN_* in
wv_cds_config.py). A bare name is rewritten to "add <name>".
"""

import socket
import sys

import wv_cds_config as cfg


def main():
    lines = sys.argv[1:]
    if not lines:
        lines = [ln.rstrip("\n").strip() for ln in sys.stdin
                 if ln.strip()]
    if not lines:
        print("usage: test_add_client.py <signal> [<signal> ...]")
        return 1

    with socket.create_connection(
            (cfg.WV_CDS_LISTEN_HOST, cfg.WV_CDS_LISTEN_PORT), timeout=5) as s:
        for line in lines:
            if not line.lower().startswith("add "):
                line = "add " + line
            s.sendall((line + "\n").encode("utf-8"))
            print("sent: %s" % line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
