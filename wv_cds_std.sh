#!/bin/bash
#====================================================================
# Script Name: wv_cds_std.sh
# Function: Send one arbitrary Tcl command to a running wv, from the shell.
#
# Usage: ./wv_cds_std.sh 'expr 2+3'
#        ./wv_cds_std.sh 'wvVersion'
#
#   Nothing in the package calls this; it is here for trying things out
#   against wv's RPC server on 127.0.0.1:61888 by hand.
#
#   Output is wv's one-line reply, or the single word "refused" when nothing
#   is listening on the port. Exit status is 0 only when wv answered.
#====================================================================
wv1() {
    local r

    if ! { exec 3<>/dev/tcp/127.0.0.1/61888; } 2>/dev/null; then
        printf 'refused\n'
        printf 'wv_cds_std.sh: nothing listening on 127.0.0.1:61888 - start wv with the RPC server (./start_wv.sh)\n' >&2
        return 1
    fi

    printf 'RPC:%s\n' "$*" >&3
    if ! IFS= read -r r <&3; then
        exec 3<&-
        printf 'refused\n'
        printf 'wv_cds_std.sh: wv closed the connection without answering\n' >&2
        return 1
    fi
    exec 3<&-
    printf '%s\n' "$r"
}
wv1 "$@"
