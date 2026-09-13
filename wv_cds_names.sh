#!/bin/bash
#====================================================================
# Script Name: wv_cds_names.sh
# Function: Ask a running wv (Custom WaveView) which signals it is still
#           displaying, and print their names.
#
# Usage: ./wv_cds_names.sh
#
#   Opens a short TCP connection to 127.0.0.1:61888 - wv's own RPC server,
#   which wv_rpc_server.tcl starts inside wv - and walks ::wv_cds_lines, the
#   name -> line objects map wv_cds_plot.sh maintains:
#
#     foreach nm [dict keys $::wv_cds_lines] {
#         keep nm if at least one of its line objects is still alive
#     }
#
#   A line you deleted in the wv GUI answers the empty string, so the names
#   printed here are exactly the ones wv is still showing - the same set
#   wv_cds_plot.sh will skip as "already plotted".
#
#   Only sx_get_name is used. Nothing here walks the waveview
#   (sx_first_panel / sx_first_line / sx_next_*) - those make wv recompute
#   its layout, which blocks the interpreter the RPC server runs on, and the
#   call hangs.
#
#   Output:
#     <n> <name> <name> ...   one line: the count first, then the names
#                             (just "0" when this tool has nothing on screen
#                             in wv)
#     refused                 nothing is listening on the port: wv is not
#                             running, or it was started without the RPC server
#   Exit status is 0 only when wv actually answered.
#
#   The count is what lets the SKILL caller tell the two empty cases apart:
#   parseString("") and a "refused" reply are BOTH nil there, so without it
#   "wv answered, nothing is displayed" (clear the probes) would be
#   indistinguishable from "wv did not answer" (leave the probes alone).
#
#   Called once per "Send to WV (Direct)" click, not once per net: the reply
#   is the whole list either way.
#====================================================================
wv1() {
    local cmd r

    # Note: [ and ] are left bare inside the double quotes - a backslash does
    # NOT escape them in bash, so \[ would reach wv as a literal backslash and
    # turn the command substitution into a plain string.
    #
    # Variables are wvc_-prefixed because wv_rpc_server.tcl runs this with
    # uplevel #0, so each one becomes a global in wv's own interpreter.
    cmd="set wvc_out {}"
    cmd="$cmd ; if {[info exists ::wv_cds_lines]} {"
    cmd="$cmd foreach wvc_nm [dict keys \$::wv_cds_lines] {"
    cmd="$cmd foreach wvc_l [dict get \$::wv_cds_lines \$wvc_nm] {"
    cmd="$cmd set wvc_alive 0"
    cmd="$cmd ; if {![catch {sx_get_name \$wvc_l} wvc_n2]} { if {\$wvc_n2 ne \"\"} { set wvc_alive 1 } }"
    cmd="$cmd ; if {\$wvc_alive} { lappend wvc_out \$wvc_nm ; break } } } }"
    cmd="$cmd ; set wvc_out [linsert \$wvc_out 0 [llength \$wvc_out]]"
    cmd="$cmd ; set wvc_out"

    if ! { exec 3<>/dev/tcp/127.0.0.1/61888; } 2>/dev/null; then
        printf 'refused\n'
        printf 'wv_cds_names.sh: nothing listening on 127.0.0.1:61888 - start wv with the RPC server (./start_wv.sh)\n' >&2
        return 1
    fi

    printf 'RPC:%s\n' "$cmd" >&3
    if ! IFS= read -r r <&3; then
        exec 3<&-
        printf 'refused\n'
        printf 'wv_cds_names.sh: wv closed the connection without answering\n' >&2
        return 1
    fi
    # one close is enough; closing the same fd twice is what produced the
    # "Bad file descriptor" noise
    exec 3<&-
    printf '%s\n' "$r"
}
wv1 "$@"
