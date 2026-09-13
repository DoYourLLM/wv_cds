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
#     set lines [ sx_display $signal ]      ;# returns the line objects
#     sx_get_name <line object>             ;# "" once the line is gone
#
#   "Already displayed" is NOT remembered by name. wv itself is asked, by
#   keeping the line object each sx_display returned and probing it with
#   sx_get_name: a live line answers its signal name, a line you deleted in
#   the wv GUI answers the empty string. So deleting a curve in wv is enough
#   to make the next click plot it again.
#
#   ::wv_cds_lines lives INSIDE wv (name -> line objects), so it dies with wv
#   and nothing has to be cleaned up on the Virtuoso side.
#
#   Only sx_signal, sx_display and sx_get_name are used. The commands that
#   walk a waveview (sx_first_panel / sx_first_line / sx_next_*) are
#   deliberately avoided: they make wv recompute its layout, which blocks the
#   interpreter the RPC server is running on, and the call hangs.
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
    #
    # Every variable is wvc_-prefixed on purpose: wv_rpc_server.tcl runs this
    # with uplevel #0, so each of them becomes a global in wv's own
    # interpreter - a bare "alive" or "new" could collide with wv's internals.
    cmd="if {![info exists ::wv_cds_lines]} {set ::wv_cds_lines [dict create]}"
    cmd="$cmd ; set wvc_matches [ sx_signal ${pattern} ]"
    cmd="$cmd ; set wvc_new 0 ; set wvc_skip 0"
    cmd="$cmd ; foreach wvc_sig \$wvc_matches {"
    cmd="$cmd set wvc_nm [sx_get_name \$wvc_sig]"
    cmd="$cmd ; set wvc_live 0"
    # probe every line object we kept for this signal; one survivor is enough
    #
    # The name must match the key, not merely be non-empty: wv RECYCLES line
    # object handles. Once a line is freed, its handle value comes back for a
    # later sx_display, so a stale entry can end up pointing at a different,
    # live signal - observed as net3 and net5 sharing _94c94c0_void_pp. A bare
    # non-empty test then reports the deleted net3 as still on screen and skips
    # it. Comparing the name makes a recycled handle fail the check, which puts
    # that net back on the list to display.
    cmd="$cmd ; if {[dict exists \$::wv_cds_lines \$wvc_nm]} {"
    cmd="$cmd foreach wvc_old [dict get \$::wv_cds_lines \$wvc_nm] {"
    cmd="$cmd set wvc_alive 0"
    cmd="$cmd ; if {![catch {sx_get_name \$wvc_old} wvc_nm2]} { if {\$wvc_nm2 eq \$wvc_nm} { set wvc_alive 1 } }"
    cmd="$cmd ; if {\$wvc_alive} { set wvc_live 1 ; break } } }"
    cmd="$cmd ; if {\$wvc_live} { incr wvc_skip } else {"
    cmd="$cmd set wvc_lines [sx_display \$wvc_sig]"
    cmd="$cmd ; if {[llength \$wvc_lines]} { dict set ::wv_cds_lines \$wvc_nm \$wvc_lines ; incr wvc_new } } }"
    cmd="$cmd ; format {%d new, %d already plotted} \$wvc_new \$wvc_skip"

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
