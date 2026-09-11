#!/bin/bash
#====================================================================
# Script Name: wv_cds_plot.sh
# Function: Ask a running wv (Custom WaveView) to display the signals
#           matching a pattern, and NOT to display again what that wv is
#           already showing.
#
# Usage: ./wv_cds_plot.sh "I0.I1.net1"
#        ./wv_cds_plot.sh "VDD*"     # sx_signal matches, so wildcards work
#
#   Opens a short TCP connection to 127.0.0.1:61888 - wv's own RPC server,
#   which wv_rpc_server.tcl starts inside wv - and runs
#
#     set matches [ sx_signal <pattern> ]
#     foreach signal $matches {
#         if {[lsearch -exact $::wv_cds_plotted $signal] < 0} {
#             sx_display $signal ; lappend ::wv_cds_plotted $signal
#         }
#     }
#
#   The bookkeeping variable ::wv_cds_plotted lives INSIDE wv, so a signal is
#   displayed at most once per wv session and the memory disappears with wv.
#   wv_cds_openfsdb.sh resets the list when it opens a file.
#
#   Output:
#     <n> new, <m> already plotted   wv accepted the request
#     refused                        nothing is listening on the port: wv is
#                                    not running, or it was started without
#                                    the RPC server
#   Exit status is 0 only when wv actually answered.
#====================================================================
wv1() {
    local pattern="$1"
    local cmd r

    # Note: [ and ] are left bare inside the double quotes - a backslash
    # does NOT escape them in bash, so \[ would reach wv as a literal
    # backslash and turn the command substitution into a plain string.
    cmd="if {![info exists ::wv_cds_plotted]} {set ::wv_cds_plotted {}}"
    cmd="$cmd ; set matches [ sx_signal ${pattern} ]"
    cmd="$cmd ; set new 0"
    cmd="$cmd ; foreach signal \$matches {"
    cmd="$cmd if {[lsearch -exact \$::wv_cds_plotted \$signal] < 0}"
    cmd="$cmd { sx_display \$signal ; lappend ::wv_cds_plotted \$signal ; incr new } }"
    cmd="$cmd ; format {%d new, %d already plotted} \$new [expr {[llength \$matches] - \$new}]"

    # { ...; } so the redirect failure is silenced: a trailing 2>/dev/null on
    # the exec does not take effect, because the /dev/tcp redirect fails first
    if ! { exec 3<>/dev/tcp/127.0.0.1/61888; } 2>/dev/null; then
        printf 'refused\n'
        printf 'wv_cds_plot.sh: nothing listening on 127.0.0.1:61888 - start wv with the RPC server (./start_wv.sh)\n' >&2
        return 1
    fi

    printf 'RPC:%s\n' "$cmd" >&3
    if ! IFS= read -r r <&3; then
        exec 3<&-
        printf 'refused\n'
        printf 'wv_cds_plot.sh: wv closed the connection without answering\n' >&2
        return 1
    fi
    # one close is enough; closing the same fd twice is what produced the
    # "Bad file descriptor" noise
    exec 3<&-
    printf '%s\n' "$r"
}
wv1 "$@"
