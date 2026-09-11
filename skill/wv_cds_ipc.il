; wv_cds_ipc.il - synchronous IPC bridge
;   wvCdsSendToGui(signals) - push selected nets to the Python wv_cds GUI
;   wvCdsSendToWv(signals)  - (legacy) plot nets in wv directly
;
; runSyncIPC(cmd):
;   1. ipcBeginProcess spawns a bash shell running the script in cmd
;   2. ipcWait blocks until the script finishes its TCP RPC round-trip
;   3. ipcReadProcess captures stdout (the one-line RPC reply)
;   4. parseString splits the reply into a SKILL list (nil on failure)
;
; wvCdsSendToWv(signals):
;   opens the fsdb once per session, then plots every selected net.
;   Scripts used (both speak the plain RPC: protocol to 127.0.0.1:61888):
;     wv_cds_openfsdb.sh "<file>"  -> sx_open_sim_file_read "<file>"
;     wv_cds_plot.sh   "<net>"     -> foreach signal [ sx_signal <net> ]
;                                        { sx_display $signal }

procedure(runSyncIPC(cmd)
  let((cid val)
    cid = ipcBeginProcess(cmd)
    ipcWait(cid)
    val = ipcReadProcess(cid 20)
    errset(ipcCloseProcess(cid))
    parseString(val)))

; Session state of the lazy steps below. Declared once here so the guards
; can always read them - reading a global that was never assigned raises
; "unbound variable" - and so that re-loading this file keeps the state.
;
; wvCdsFsdbOpened is the only sticky flag: "the file is already open in wv".
; "is wv up" and "is the GUI up" are NOT cached - the launcher scripts probe
; their port every time, so a closed window is restarted on the next click.
;
; wvCdsWvStarting is different again: it only means "a wv launch is in
; flight right now", it is set when the launcher is forked and cleared by the
; asynchronous status callback as soon as that launch reaches a terminal
; state. It stops a second click made while wv is still coming up from
; launching a second wv - two wv processes would fight over the RPC port and
; only one of them would ever receive plots.
unless(boundp('wvCdsFsdbOpened) wvCdsFsdbOpened = nil)
unless(boundp('wvCdsWvStarting) wvCdsWvStarting = nil)

; Open WV_CDS_FSDB before plotting, once per session, when it is configured.
; An EMPTY WV_CDS_FSDB is the normal setup: wv is started separately and the
; waveform file is opened inside wv, so there is nothing to open here and
; plotting just uses whatever file that wv has open - hence t, so the caller
; goes straight on to plot. A failed open (wv not up yet) is not flagged as
; done, so the next click retries it.
procedure(wvCdsOpenFsdbOnce()
  let((r fsdb)
    fsdb = if(boundp('WV_CDS_FSDB) WV_CDS_FSDB "")
    if(rexMatchp("^$" fsdb)
      then
        t
      else
        unless(wvCdsFsdbOpened
          r = runSyncIPC(sprintf(nil "%s/wv_cds_openfsdb.sh \"%s\""
                                  WV_CDS_SH_DIR fsdb))
          when(r && car(r)
            wvCdsFsdbOpened = t))
        wvCdsFsdbOpened)))

; main flow: make sure wv is up, open WV_CDS_FSDB only if one is configured,
; then plot every selected net. Plotting resolves against whatever waveform
; file wv has open, which is normally the one you opened there yourself.
; The wv reply of every plot command is echoed to the CIW, so a signal that
; wv cannot resolve is visible immediately.
procedure(wvCdsSendToWv(signals)
  let((ok r tok refused okreply)
    if(null(signals) then
      warn("wvCds: no nets selected in the schematic\n")
    else
      ; bring wv (with the RPC server) up on the first send if needed
      wvCdsEnsureWv()
      ok = wvCdsOpenFsdbOnce()
      unless(ok
        warn("wvCds: fsdb not opened - wv may still be starting; click again in a few seconds\n"))
      when(ok
        foreach(sig signals
          ; no hiTextDisplayString here: it only works on text windows (it
          ; drives a text cursor and scrolls), so calling it on the
          ; schematic canvas warns "window:N is not a text window"; the
          ; printf below is the CIW echo
          r = runSyncIPC(sprintf(nil "%s/wv_cds_plot.sh \"%s\""
                                    WV_CDS_SH_DIR sig))
          ; wv_cds_plot.sh prints "refused" when nothing is listening, and
          ; nothing at all when it could not run. Either way wv did not take
          ; the plot, so it may have been restarted outside this session and
          ; lost the fsdb: drop the cache and let the next click open it
          ; again. refused is computed in two steps on purpose - relying on
          ; && to short-circuit an argument check is not safe in SKILL.
          tok = if(r car(r) nil)
          refused = if(tok rexMatchp("^refused" tok) nil)
          ; okreply = wv gave us something other than "refused". Computed in
          ; one expression so neither && nor || has to short-circuit.
          okreply = if(tok !refused nil)
          unless(okreply
            wvCdsFsdbOpened = nil)
          if(okreply
            then
              printf("wvCds: plot %s => %L\n" sig r)
            else
              ; do not dump the raw token list here: wv_cds_plot.sh puts a
              ; one-word token on stdout and the explanation on stderr, and
              ; the CIW sees both merged and split into tokens
              warn("wvCds: plot %s skipped - wv is not answering on the RPC port yet, it may still be starting; click again in a few seconds\n" sig)))))))

; new flow: push the selected nets to the Python wv_cds GUI (the GUI's
; "Send to WV" button is what actually plots them). Uses the plain
; "add <net>" line protocol to the GUI's add-listener (127.0.0.1:61889).
procedure(wvCdsSendToGui(signals)
  let((r)
    if(null(signals) then
      warn("wvCds: no nets selected in the schematic\n")
    else
      ; make sure wv (for the plot that follows) and the Python GUI are
      ; both running before the first push
      wvCdsEnsureWv()
      wvCdsEnsureGui()
      foreach(sig signals
        r = runSyncIPC(sprintf(nil "%s/wv_cds_add.sh \"%s\""
                                  WV_CDS_SH_DIR sig))
        printf("wvCds: push %s to GUI => %L\n" sig r)))))

; ---------------------------------------------------------------------------
; Auto-start of the long-lived processes (wv, and the Python GUI).
;
; Both are long-lived, so neither may be a blocking child of Virtuoso. Each
; launcher script probes its port and, when nothing is listening, starts the
; process with nohup + background + all three standard streams redirected;
; only the short launcher script is a child of Virtuoso, and the process
; itself stays detached (it also keeps running after Virtuoso exits). Each
; launcher then waits, bounded, until its port answers, so that a caller
; which does wait gets a usable process instead of a startup race.
; SKILL either waits for that status (the Python GUI, which the push needs
; immediately) or ignores it and picks it up asynchronously (wv, which can
; take tens of seconds) - see the two sections below.
; ---------------------------------------------------------------------------

; absolute path of the wv RPC script: WV_CDS_RPC_TCL when it is set,
; otherwise the copy that ships in the package root
procedure(wvCdsRpcTclPath()
  if(boundp('WV_CDS_RPC_TCL)
     WV_CDS_RPC_TCL
     strcat(WV_CDS_SH_DIR "/wv_rpc_server.tcl")))

; absolute path of the GUI script: WV_CDS_GUI_PY when it is set, otherwise
; the copy that ships next to the shell scripts
procedure(wvCdsGuiPyPath()
  if(boundp('WV_CDS_GUI_PY)
     WV_CDS_GUI_PY
     strcat(WV_CDS_SH_DIR "/python/wv_cds_gui.py")))

; the wv executable:
;   1. WV_CDS_WV_BIN                when it is set to something non-empty
;   2. $WV_HOME/bin/wv              when WV_HOME is exported
;   3. "wv"                         otherwise, resolved through PATH
; Step 2 matters because a launcher script is non-interactive: a shell alias
; or a function defined in .bashrc is invisible to it, an absolute path is
; not. getShellEnvVar returns nil when the variable is not set.
procedure(wvCdsWvBin()
  let((bin home)
    bin  = if(boundp('WV_CDS_WV_BIN) WV_CDS_WV_BIN "")
    home = getShellEnvVar("WV_HOME")
    cond(
      (strlen(bin) > 0  bin)
      (home             strcat(home "/bin/wv"))
      (t                "wv"))))

; run a launcher SYNCHRONOUSLY and return its single status token.
;
; ipcReadProcess hands the child's stdout back as ONE string including the
; trailing newline (the documentation's example returns "foghorn\n"), so it
; must go through parseString to get the bare token: comparing the raw
; string with member would never match "started" and would silently take
; the failure branch every time.
;
; Only the Python GUI uses this: its listener must be up before the nets are
; pushed, and it starts in about a second, so a bounded wait is worth it.
; ipcWait is bounded (message every 5s, give up after timeOut) so that a
; wedged launcher can never freeze the Virtuoso UI.
procedure(wvCdsRunLaunchIPC(cmd timeOut)
  let((r cid val)
    r = errset(ipcBeginProcess(cmd))
    cid = when(r car(r))
    unless(cid
      return(nil))
    errset(ipcWait(cid 5 timeOut))
    r = errset(ipcReadProcess(cid 10))
    val = when(r car(r))
    errset(ipcCloseProcess(cid))
    when(val car(parseString(val)))))

; ---------------------------------------------------------------------------
; Asynchronous launcher.
;
; Starting wv can take tens of seconds, so wv must NEVER be waited for:
; ipcBeginProcess only forks the child and returns its id immediately, and the
; launcher's lines are delivered to a data handler as they arrive.
; The documentation guarantees that handler calls happen at the top level of
; SKILL and do not interrupt the current evaluation, so the Virtuoso UI stays
; responsive however slow wv is.
; ---------------------------------------------------------------------------

; called asynchronously, once per line the wv launcher writes.
; "starting" arrives immediately; already-up / started / started-no-listen end
; the launch and clear wvCdsWvStarting; an unknown token is a configuration
; error and ends it too.
procedure(wvCdsLauncherStatus(cid data)
  let((tok)
    tok = car(parseString(data))
    cond(
      (member(tok list("starting"))
        ; wv is on its way - say so now instead of leaving the user to
        ; wonder why the first plot failed
        printf("wvCds: starting wv in the background - plots will work once it is up\n"))
      (member(tok list("already-up"))
        wvCdsWvStarting = nil
        t)
      (member(tok list("started"))
        wvCdsWvStarting = nil
        wvCdsFsdbOpened = nil
        printf("wvCds: wv %L - it is ready, click again to plot\n" tok))
      (member(tok list("started-no-listen"))
        wvCdsWvStarting = nil
        wvCdsFsdbOpened = nil
        warn("wvCds: wv launched but its RPC port is not answering yet - see /tmp/wv_cds_wv.log\n"))
      (tok
        wvCdsWvStarting = nil
        warn("wvCds: cannot start wv => %L (check WV_CDS_SH_DIR and WV_CDS_WV_BIN)\n" tok)))))

; fork a launcher and return at once - no ipcWait, no ipcReadProcess
procedure(wvCdsLaunchAsync(cmd)
  let((r cid)
    r = errset(ipcBeginProcess(cmd "" 'wvCdsLauncherStatus))
    cid = when(r car(r))
    cid))

; Make sure wv is up, WITHOUT waiting for it. This is what replaces a manual
; "source wv_rpc_server.tcl". The launcher probes the RPC port first, so
; calling it on every click is cheap while wv is alive, and it restarts wv
; after the user closes it - which a sticky flag could not do.
; wvCdsWvStarting only stops a second launch while one is still in flight:
; two wv processes would fight over the single RPC port and only one of them
; would ever receive plots.
procedure(wvCdsEnsureWv()
  let((bin opts port tcl)
    unless(wvCdsWvStarting
      bin  = wvCdsWvBin()
      opts = if(boundp('WV_CDS_WV_OPTS) WV_CDS_WV_OPTS "-ace_gui")
      port = if(boundp('WV_CDS_RPC_PORT) WV_CDS_RPC_PORT "61888")
      tcl  = wvCdsRpcTclPath()
      when(wvCdsLaunchAsync(
             sprintf(nil "%s/wv_cds_wv_start.sh \"%s\" \"%s\" \"%s\" \"%s\""
                       WV_CDS_SH_DIR bin opts tcl port))
        wvCdsWvStarting = t))
    t))

; Make sure the Python GUI is listening. SYNCHRONOUS, because the nets are
; pushed immediately afterwards, so the add-listener has to be up before this
; returns. Like wv, the launcher probes the port first: a running GUI costs
; one quick round trip, and a GUI the user closed is started again.
procedure(wvCdsEnsureGui()
  let((py port gui status)
    py     = if(boundp('WV_CDS_PYTHON) WV_CDS_PYTHON "")
    port   = if(boundp('WV_CDS_GUI_PORT) WV_CDS_GUI_PORT "61889")
    gui    = wvCdsGuiPyPath()
    status = wvCdsRunLaunchIPC(
               sprintf(nil "%s/wv_cds_gui_start.sh \"%s\" \"%s\" \"%s\""
                         WV_CDS_SH_DIR gui py port)
               20)
    cond(
      (member(status list("started"))
        printf("wvCds: started the wv_cds GUI (%s)\n" gui))
      (member(status list("already-up"))
        t)
      (member(status list("started-no-listen"))
        warn("wvCds: GUI launched but not listening - check /tmp/wv_cds_gui.log\n"))
      (t
        warn("wvCds: cannot start the wv_cds GUI (%L) - run %L with %L manually\n"
             status gui py)))))

printf("wv_cds_ipc.il loaded\n")
