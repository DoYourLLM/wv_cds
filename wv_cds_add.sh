#!/bin/bash
#====================================================================
# Script Name: wv_cds_add.sh
# Function: Push one net name to the Python wv_cds GUI's add-listener.
#
# Usage: ./wv_cds_add.sh "I0.I1.net1"
#   - opens a short TCP connection to 127.0.0.1:61889 (the GUI's
#     external-add listener)
#   - sends one line:  add <net>
#   - closes immediately (fire-and-forget; the GUI does NOT reply)
#
# It prints exactly one status line, so the SKILL caller can tell success
# from failure. Previously it printed nothing, which made the two cases
# look identical in the CIW (both showed "=> nil"):
#   sent      the line was written to the listener
#   refused   nothing is listening on the port, i.e. the GUI is not up
#
# NOTE: the port here must match WV_CDS_LISTEN_PORT in the Python
#       wv_cds_config.py and WV_CDS_GUI_PORT in the SKILL
#       wv_cds_config.il. A mismatch looks exactly like "the GUI started
#       but no net ever arrives".
#====================================================================
wv1() {
    local net="$1"
    # The whole exchange runs in a subshell, so a failed redirection
    # cannot take this script down before it reports anything; only the
    # subshell status decides the message.
    ( exec 3<>/dev/tcp/127.0.0.1/61889 2>/dev/null \
      && printf 'add %s\n' "$net" >&3 ) 2>/dev/null
    if [ $? -eq 0 ]; then
        echo sent
    else
        echo refused
        return 1
    fi
}
wv1 "$@"
