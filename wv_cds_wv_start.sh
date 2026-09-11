#!/bin/bash
#====================================================================
# Script Name: wv_cds_wv_start.sh
# Function: Make sure wv (Custom WaveView) is running WITH the RPC
#           server loaded, without ever blocking the calling Virtuoso
#           session, and without a manual "source wv_rpc_server.tcl".
#
# Usage: ./wv_cds_wv_start.sh <wv_bin> <wv_opts> <rpc_tcl> [port] [log]
#   <wv_bin>   wv launcher: "wv", or an absolute path when wv is only a
#              shell alias/function (aliases are NOT visible to a script)
#   <wv_opts>  startup options, e.g. "-ace_gui" ("" for none)
#   <rpc_tcl>  absolute path to wv_rpc_server.tcl
#   [port]     RPC port to probe (default 61888)
#   [log]      stdout/stderr of wv (default $WV_CDS_WV_LOG,
#              else /tmp/wv_cds_wv.log)
#
# The command run is exactly:   <wv_bin> <wv_opts> <rpc_tcl>
# so wv loads the RPC server at startup. wv is a long-lived GUI, so it is
# started detached (nohup + background + all three standard streams
# redirected): it inherits none of the SKILL ipc descriptors and keeps
# running independently of the Virtuoso session. DISPLAY is inherited
# from Virtuoso, which is what the wv GUI needs.
#
# Lines written for the SKILL caller, in this order:
#   already-up        something already listens on <port>; nothing started
#                     (this is the only line, and it is the last one)
#   starting          wv was just launched; more lines follow when it settles
#   started           its RPC port answers - plots will work now
#   started-no-listen wv is up but the port never answered within the wait
#   no-wv-bin         <wv_bin> was not found
#   no-tcl-file       <rpc_tcl> does not exist
#   no-log-dir        the log directory is missing or not writable
#
# Exit status is 0 for already-up / starting / started / started-no-listen and
# 1 for the three configuration errors.
#====================================================================
wv_bin="$1"
wv_opts="$2"
rpc_tcl="$3"
port="${4:-61888}"
log="${5:-${WV_CDS_WV_LOG:-/tmp/wv_cds_wv.log}}"

WAIT_TRIES=300     # 300 * 0.2s = up to 60s; wv is a large app and this
                   # launcher runs detached, so waiting costs nothing

# Does anything accept a connection on the port? bash's /dev/tcp succeeds
# only when a listener is there, and fails fast (ECONNREFUSED) when
# nothing is listening on loopback.
port_up() { (exec 3<>/dev/tcp/127.0.0.1/"$1") 2>/dev/null; }

if port_up "$port"; then
    echo already-up
    exit 0
fi

[ -n "$wv_bin" ] || { echo no-wv-bin; exit 1; }
command -v "$wv_bin" >/dev/null 2>&1 || { echo no-wv-bin; exit 1; }
[ -n "$rpc_tcl" ] && [ -f "$rpc_tcl" ] || { echo no-tcl-file; exit 1; }

logdir="$(dirname "$log")"
[ -d "$logdir" ] && [ -w "$logdir" ] || { echo no-log-dir; exit 1; }

# When handed an absolute wv path (e.g. $WV_HOME/bin/wv), put its directory
# on PATH as well, so wv's own helper lookups behave the same as in the
# user's shell where PATH=$WV_HOME/bin was exported.
case "$wv_bin" in
    /*) PATH="$(dirname "$wv_bin"):$PATH"; export PATH ;;
esac

# $wv_opts is intentionally unquoted so several options can be listed in
# one string (e.g. "-ace_gui -foo"); keep them space-separated.
nohup "$wv_bin" $wv_opts "$rpc_tcl" >>"$log" 2>&1 </dev/null &
disown 2>/dev/null

# Report immediately that wv is on its way. The SKILL caller reads its child's
# output as it arrives, so this line reaches the CIW right away instead of
# leaving the user guessing until the wait below finishes.
echo starting

# bounded wait for the RPC listener, so the caller's first plot lands
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
