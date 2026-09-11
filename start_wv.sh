#!/bin/bash
#====================================================================
# Script Name: start_wv.sh
# Function: Start wv (Custom WaveView) with the RPC server loaded, from a
#           plain terminal - and tell you which wv is the one that
#           receives plots.
#
# The right-click items start wv for you when they need it. This script is
# for the other order of events: you want wv already up before you touch
# Virtuoso, or you want to watch wv's own startup output.
#
# It runs exactly
#
#   <wv> <WV_CDS_WV_OPTS> <this package>/wv_rpc_server.tcl
#
# with the options defaulting to -ace_gui - the same command the right-click
# items use, so the RPC server ends up on the RPC port and Virtuoso can talk
# to this wv straight away.
#
# Only ONE wv can hold the RPC port, so this script also reports the state
# when the port is already taken and when more than one wv is running.
#
# Run ./start_wv.sh -h for the usage text.
#====================================================================
set -u

usage() {
    cat <<'EOF'
start_wv.sh - start wv (Custom WaveView) with the RPC server loaded.

Usage:
  ./start_wv.sh          start wv in the foreground; closing wv or Ctrl-C
                         returns you to the prompt
  ./start_wv.sh -b       start it detached in the background, wait for the
                         RPC port, then return
  ./start_wv.sh -h       this help

It runs:

  <wv> -ace_gui <this package>/wv_rpc_server.tcl

Only one wv can hold the RPC port (default 61888): it is the one that
receives the plots. Any other wv you start runs without an RPC server, so
it never gets plots - its console shows
"wv RPC server NOT started: ... cannot listen ...".

If the RPC port is already answering, nothing is started and the current
state is reported instead.

Environment overrides (all optional):
  WV_CDS_WV_BIN    wv executable; default $WV_HOME/bin/wv, else wv on PATH
  WV_CDS_WV_OPTS   options placed before the script; default "-ace_gui"
  WV_CDS_RPC_PORT  port that is probed; default 61888
  WV_CDS_WV_LOG    log file for -b; default /tmp/wv_cds_wv.log
EOF
}

PKG=$(cd "$(dirname "$0")" && pwd) || exit 1
TCL="$PKG/wv_rpc_server.tcl"
PORT="${WV_CDS_RPC_PORT:-61888}"
LOG="${WV_CDS_WV_LOG:-/tmp/wv_cds_wv.log}"
OPTS="${WV_CDS_WV_OPTS:--ace_gui}"

BACK=0
case "${1:-}" in
    -b|--background) BACK=1 ;;
    -h|--help)       usage; exit 0 ;;
    "")              ;;
    *) printf 'start_wv: unknown option %s (try -h)\n' "$1" >&2; exit 1 ;;
esac

port_up() { (exec 3<>/dev/tcp/127.0.0.1/"$1") 2>/dev/null; }

# who is listening on the port - best effort, silent when nothing fits
port_owner() {
    if command -v ss >/dev/null 2>&1; then
        ss -ltnp 2>/dev/null | awk -v p=":$1" '$4 ~ p { print; exit }'
    elif command -v netstat >/dev/null 2>&1; then
        netstat -ltnp 2>/dev/null | awk -v p=":$1" '$4 ~ p { print; exit }'
    fi
}

# how many wv processes are running; 0 when we cannot tell
wv_count() {
    command -v pgrep >/dev/null 2>&1 || { printf '0'; return; }
    pgrep -c -x wv 2>/dev/null || true
}

# resolve wv: WV_CDS_WV_BIN, then $WV_HOME/bin/wv, then PATH
WV_BIN="${WV_CDS_WV_BIN:-}"
if [ -z "$WV_BIN" ] && [ -n "${WV_HOME:-}" ] && [ -x "${WV_HOME}/bin/wv" ]; then
    WV_BIN="${WV_HOME}/bin/wv"
fi
if [ -z "$WV_BIN" ]; then
    WV_BIN=$(command -v wv 2>/dev/null || true)
fi
if [ -z "$WV_BIN" ]; then
    printf 'start_wv: cannot find wv\n' >&2
    printf '          set WV_CDS_WV_BIN, or export WV_HOME so that $WV_HOME/bin/wv exists\n' >&2
    printf '          (a wv shell alias or function is not visible to a script)\n' >&2
    exit 1
fi

if [ ! -f "$TCL" ]; then
    printf 'start_wv: missing %s - is this really the package root?\n' "$TCL" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# state: which wv receives the plots
# ---------------------------------------------------------------------------
EXTRA_WV=0
NWV=$(wv_count)
case "$NWV" in ''|*[!0-9]*) NWV=0 ;; esac
[ "$NWV" -gt 1 ] && EXTRA_WV=1

if port_up "$PORT"; then
    printf 'start_wv: something is already listening on %s - nothing to do\n' "$PORT"
    OWNER=$(port_owner "$PORT")
    if [ -n "$OWNER" ]; then
        printf 'start_wv:   %s\n' "$OWNER"
    fi
    printf 'start_wv: that process is the wv that receives the plots\n'
    if [ "$EXTRA_WV" -eq 1 ]; then
        printf 'start_wv: WARNING %s wv processes are running but only one can hold port %s\n' "$NWV" "$PORT"
        printf 'start_wv:   the others have no RPC server and will never be plotted into;\n'
        printf 'start_wv:   their console says "wv RPC server NOT started: ... cannot listen ..."\n'
    fi
    exit 0
fi

if [ "$EXTRA_WV" -eq 1 ]; then
    printf 'start_wv: WARNING %s wv processes are running; port %s looks free, so an\n' "$NWV" "$PORT"
    printf 'start_wv:   extra wv is about to be started and will hold the port itself\n'
fi

printf 'start_wv: package  %s\n' "$PKG"
printf 'start_wv: wv       %s\n' "$WV_BIN"
printf 'start_wv: command  %s %s %s\n' "$WV_BIN" "$OPTS" "$TCL"

if [ "$BACK" -eq 1 ]; then
    # detach: nohup, background, all three streams redirected, so wv holds
    # nothing of this shell and survives the terminal closing
    nohup "$WV_BIN" $OPTS "$TCL" >>"$LOG" 2>&1 </dev/null &
    disown 2>/dev/null
    printf 'start_wv: started in the background, log: %s\n' "$LOG"
    printf 'start_wv: waiting for the RPC port'
    i=0
    while [ "$i" -lt 100 ]; do
        if port_up "$PORT"; then
            printf ' - listening on %s\n' "$PORT"
            printf 'start_wv: this wv is now the one that receives the plots\n'
            exit 0
        fi
        printf '.'
        sleep 0.2
        i=$((i + 1))
    done
    printf '\nstart_wv: the port is still not answering - see %s\n' "$LOG" >&2
    exit 1
fi

printf 'start_wv: starting wv; close it or press Ctrl-C to stop\n'
exec "$WV_BIN" $OPTS "$TCL"
