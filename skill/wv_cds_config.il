; wv_cds_config.il - configuration for the wv_cds integration
;
; This is the only file you normally need to look at.
;
; There is deliberately no machine specific path in this package. The line
; marked "package root" below is filled in by install.sh, which writes this
; package's real location into it - run install.sh once after unpacking, and
; again if you move the package.
;
; Exporting WV_CDS_HOME overrides it without touching this file:
;
;   export WV_CDS_HOME=/home/you/tools/wv_cds

; ---------------------------------------------------------------------------
; package root
; ---------------------------------------------------------------------------
; The directory that holds the wv_cds_*.sh scripts plus the python/ and
; skill/ subdirectories. Everything else is derived from it.
; The Python GUI's Save button also rewrites this line, so the two sides
; stay in sync.
WV_CDS_SH_DIR = "@WV_CDS_HOME@"

when(getShellEnvVar("WV_CDS_HOME")
  WV_CDS_SH_DIR = getShellEnvVar("WV_CDS_HOME"))

; ---------------------------------------------------------------------------
; simulation database (optional)
; ---------------------------------------------------------------------------
; Normally left empty. wv is started on its own - start_wv.sh, or the
; right-click items - and you open the waveform file inside wv, so plotting
; uses whatever file is open there. If you do set it, the direct path opens
; exactly that file, once per session, before plotting.
WV_CDS_FSDB = ""

; ---------------------------------------------------------------------------
; wv auto-start
; ---------------------------------------------------------------------------
; Both right-click items start wv with the RPC server when nothing is
; listening on the RPC port, so there is no manual "source wv_rpc_server.tcl"
; step any more. The command that gets run is
;
;   <wv> <WV_CDS_WV_OPTS> <rpc script>

; wv executable. Leave it empty to resolve it from the environment:
;   ""              -> $WV_HOME/bin/wv when WV_HOME is exported,
;                      otherwise plain "wv" found through PATH
;   "/abs/path/wv"  -> that exact path
; A launcher script is non-interactive, so it cannot see a "wv" alias or a
; shell function from .bashrc; $WV_HOME/bin/wv or an absolute path works.
WV_CDS_WV_BIN = ""

; options passed to wv before the RPC script; space separated if several
WV_CDS_WV_OPTS = "-ace_gui"

; RPC port probed before starting wv; must match the port that
; wv_rpc_server.tcl listens on
WV_CDS_RPC_PORT = "61888"

; optional, only when wv_rpc_server.tcl is not at
; "<package>/wv_rpc_server.tcl"
; WV_CDS_RPC_TCL = "/path/to/wv_rpc_server.tcl"

; ---------------------------------------------------------------------------
; Python GUI auto-start
; ---------------------------------------------------------------------------
; The first push through wvCdsSendToGui starts the Python GUI when it is not
; already listening, so the GUI never has to be launched by hand.

; interpreter used to start the GUI
WV_CDS_PYTHON = "python3"

; port the GUI's add-listener binds; must match WV_CDS_LISTEN_PORT in
; python/wv_cds_config.py
WV_CDS_GUI_PORT = "61889"

; optional, only when wv_cds_gui.py is not at "<package>/python/wv_cds_gui.py"
; WV_CDS_GUI_PY = "/path/to/wv_cds_gui.py"

; ---------------------------------------------------------------------------
; SKILL server (lets the Python GUI talk back to Virtuoso)
; ---------------------------------------------------------------------------
; The right-click "Send to WV (Direct)" probes the schematic itself, because it
; runs inside Virtuoso. The Python GUI cannot - it is a separate process - so
; when you press "Send to WV" there it sends a SKILL command back through this
; server instead, and the probes update the same way.
;
; HOW THIS WORKS: a small server listens on a local port and hands anything it
; receives to Virtuoso, which EVALUATES IT AS SKILL. Cadence's own article on
; this ("How to send a SKILL command to Virtuoso via a TCP/IP socket") warns
; that it has no authentication at all. The server therefore binds 127.0.0.1
; only, so the exposure is limited to processes on this machine. Set
; WV_CDS_SKILL_SERVER = nil below to switch it off entirely - the GUI then
; reports that no skill server answered, and everything else keeps working.
WV_CDS_SKILL_SERVER = t

; port the skill server binds; must match WV_CDS_SKILL_PORT in
; python/wv_cds_config.py. Cadence's example uses 8123.
WV_CDS_SKILL_PORT = "8123"

; ---------------------------------------------------------------------------
; sanity check
; ---------------------------------------------------------------------------
when(rexMatchp("@" WV_CDS_SH_DIR)
  warn("wvCds: the package root is still the install.sh placeholder\n")
  warn("        run install.sh once in the package directory, or export WV_CDS_HOME\n"))

printf("wv_cds_config.il loaded\n")
