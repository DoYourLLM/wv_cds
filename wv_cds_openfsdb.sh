#!/bin/bash
#====================================================================
# Script Name: wv_cds_openfsdb.sh
# Function: Tell a running wv (Custom WaveView) to open a waveform file.
#
# Usage: ./wv_cds_openfsdb.sh "/path/to/simulation.fsdb"
#   Opens a short TCP connection to 127.0.0.1:61888 - wv's own RPC server,
#   which wv_rpc_server.tcl starts inside wv - and sends the Tcl command
#
#     sx_open_sim_file_read "<file>"
#
#   wv's reply is printed on stdout, which is what the SKILL caller reads
#   back through ipcReadProcess.
#
#   Output is the reply, or the single word "refused" when nothing is
#   listening on the port. Exit status is 0 only when wv answered.
#
#   Called from wvCdsOpenFsdbOnce in wv_cds_ipc.il, and only when
#   WV_CDS_FSDB is set. Otherwise the file is opened inside wv by hand.
#====================================================================
wv1() {
    local filePath="$1"
    local payload r

    # ::wv_cds_lines is wv_cds_plot.sh's name -> line-object map. Opening a
    # file wipes wv's display, so every handle in it is about to go stale;
    # clearing it here makes the next plot re-display everything instead of
    # relying on each probe returning empty. The saved reply is returned
    # unchanged.
    payload="set r [ sx_open_sim_file_read \"${filePath}\" ] ; set ::wv_cds_lines [dict create] ; set r"

    if ! { exec 3<>/dev/tcp/127.0.0.1/61888; } 2>/dev/null; then
        printf 'refused\n'
        printf 'wv_cds_openfsdb.sh: nothing listening on 127.0.0.1:61888 - start wv with the RPC server (./start_wv.sh)\n' >&2
        return 1
    fi

    printf 'RPC:%s\n' "$payload" >&3
    if ! IFS= read -r r <&3; then
        exec 3<&-
        printf 'refused\n'
        printf 'wv_cds_openfsdb.sh: wv closed the connection without answering\n' >&2
        return 1
    fi
    exec 3<&-
    printf '%s\n' "$r"
}
wv1 "$@"
