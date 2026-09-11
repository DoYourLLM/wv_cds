#!/bin/bash
#====================================================================
# Script Name: wv_cds_gui_start.sh
# Function: Make sure the Python wv_cds GUI is running, without ever
#           blocking the calling Virtuoso session.
#
# Usage: ./wv_cds_gui_start.sh <gui_py> [python] [port] [log]
#   <gui_py>  absolute path to wv_cds_gui.py
#   [python]  interpreter (default: $WV_CDS_PYTHON, else python3)
#   [port]    add-listener port to probe (default: 61889)
#   [log]     stdout/stderr of the GUI (default: $WV_CDS_GUI_LOG,
#             else /tmp/wv_cds_gui.log)
#
# Why a launcher script: the GUI is long-lived, so it must not be a
# blocking child of Virtuoso. This script only probes the port and, when
# nothing is listening, starts the GUI with nohup + background + all
# three standard streams redirected. It then waits (bounded) until the
# port answers, so the caller's first push is not lost in the startup
# race, prints one status line, and exits immediately.
#
# Status line (exactly one, for the SKILL caller):
#   already-up        something already listens on <port>; nothing started
#   started           a new GUI was launched and accepts connections
#   started-no-listen launched, but the port did not answer within the wait
#   no-gui-file       <gui_py> does not exist
#   no-python         the interpreter was not found
#   no-log-dir        the log directory is missing or not writable
#
# Exit status is 0 for already-up / started / started-no-listen and 1 for
# the three configuration errors.
#====================================================================
gui_py="$1"
py="${2:-${WV_CDS_PYTHON:-python3}}"
port="${3:-61889}"
log="${4:-${WV_CDS_GUI_LOG:-/tmp/wv_cds_gui.log}}"

WAIT_TRIES=50      # 50 * 0.2s = up to 10s for the add-listener to appear

# Does anything accept a connection on the port? bash's /dev/tcp succeeds
# only when a listener is there, and fails fast (ECONNREFUSED) when
# nothing is listening on loopback.
port_up() { (exec 3<>/dev/tcp/127.0.0.1/"$1") 2>/dev/null; }

if port_up "$port"; then
    echo already-up
    exit 0
fi

[ -n "$gui_py" ] && [ -f "$gui_py" ] || { echo no-gui-file; exit 1; }
command -v "$py" >/dev/null 2>&1 || { echo no-python; exit 1; }

logdir="$(dirname "$log")"
[ -d "$logdir" ] && [ -w "$logdir" ] || { echo no-log-dir; exit 1; }

# Detach completely: nohup, background, stdin from /dev/null, stdout and
# stderr appended to the log. The GUI therefore inherits none of this
# script's descriptors - the SKILL ipc pipe closes as soon as we exit -
# and it keeps running independently of the Virtuoso session. DISPLAY and
# the rest of the environment are inherited from Virtuoso, which is what
# Tkinter needs.
cd "$(dirname "$gui_py")" || { echo no-gui-file; exit 1; }
nohup "$py" "$gui_py" >>"$log" 2>&1 </dev/null &
disown 2>/dev/null

# bounded wait for the add-listener, so the caller's first push lands
i=0
while [ "$i" -lt "$WAIT_TRIES" ]; do
    if port_up "$port"; then
        echo started
        exit 0
    fi
    sleep 0.2
    i=$((i + 1))
done

echo started-no-listen
exit 0
