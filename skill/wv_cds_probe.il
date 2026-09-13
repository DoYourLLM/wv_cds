; wv_cds_probe.il - probe, in the schematic, the nets wv is displaying
;
; Called at the end of a "Send to WV (Direct)" click. The names come from
; wv_cds_names.py (in python/), which asks wv what it is still showing, and
; each one gets a net probe:
;
;   geAddNetProbe(win nil "/I0/I1/n1")
;
; geAddNetProbe wants a slash path - the reference says "The string should be
; in the format of /instname/instname/.../objectName" - while the names coming
; out of wv use the dotted form (I0.n1), so wvCdsProbeNet converts.
;
; Checked against the IC23.1 SKILL Reference (skdfref):
;   geAddNetProbe( [w_windowId] [l_lpp] [lt_probeSpec] ) => o_probe
;   geDeleteAllProbe( [w_windowId] [g_crossProbeFlag] ) => t / nil
;
; Written with prog + if + foreach only. NOT when/unless/cond: the reference
; gives those a single body expression each -
;   when( g_condition g_expr1 )      unless( g_condition g_expr1 )
; - and hand-writing them with several bodies (or hand-rolling cond, whose
; signature is cond( l_clause1 ), a single list of clauses) is what produced
; "eval: not a function - !names" earlier. prog takes several expressions, so
; straight-line code is both legal and readable.
;
; Verified with:
;   check_new_functions.py wv_cds_probe.il --strict \
;     --allow runSyncIPC,wvCdsPython
;   (runSyncIPC is in wv_cds_ipc.il, so the checker cannot see it here)

; The interpreter used for the python/ helpers: $WV_CDS_PYTHON when it is
; exported, otherwise whatever python3 resolves to. Same rule as
; wv_cds_gui_start.sh.
procedure(wvCdsPython()
  let((p)
    p = getShellEnvVar("WV_CDS_PYTHON")
    if(p p "python3")))

; Add one net probe for the signal name nm, in window win.
; Returns the probe object, or nil when nothing was added.
procedure(wvCdsProbeNet(win nm)
  prog((path parts r hit x)
    hit = nil
    if(stringp(nm)
      then
        path = ""
        parts = parseString(nm ".")
        foreach(x parts
          path = strcat(path "/" x)
        )
        r = errset(geAddNetProbe(win nil path))
        hit = car(r)
        if(hit
          then printf("wvCds: probe %s -> %s\n" nm path)
          else printf("wvCds: probe FAILED %s -> %s\n" nm path)
        )
    )
    return(hit)
  )
)

; Clear the probes in win, then create one per name.
; Returns the number of probes that were actually created.
;
; The clear is unconditional once a list has arrived: it is what makes a net
; that is no longer in wv lose its probe. It also removes probes you placed by
; hand in that window - the caller only reaches this point when wv really did
; report a list, so a failed click never clears anything.
procedure(wvCdsProbeNames(win names)
  prog((n nm)
    n = 0
    if(win == nil
      then
        warn("wvCds: no schematic window - nothing probed\n")
        return(n)
    )
    if(names == nil
      then
        printf("wvCds: nothing to probe - wv reported no signals\n")
        return(n)
    )
    errset(geDeleteAllProbe(win))
    foreach(nm names
      if(wvCdsProbeNet(win nm)
        then n = n + 1
      )
    )
    printf("wvCds: probed %d of %d net(s) in the schematic\n"
           n length(names))
    return(n)
  )
)

; Ask wv which signals it is still displaying.
;
; Returns nil when wv did not answer, and otherwise the reply as a token list
; whose FIRST element is the count:
;
;   ("0")                     wv answered; this tool has nothing on screen
;   ("3" "I0.n1" "VDD" "n2")  wv answered; those three are on screen
;
; The count is in the reply precisely so the two cases can be told apart: an
; empty reply and a "refused" reply are both nil here, so without it "nothing
; is displayed any more" (clear the probes) would look identical to "wv is not
; answering" (leave the probes alone). The caller drops the count with cdr.
procedure(wvCdsDisplayedNames()
  prog((r tok)
    r = runSyncIPC(sprintf(nil "%s %s/python/wv_cds_names.py"
                             wvCdsPython() WV_CDS_SH_DIR))
    tok = car(r)
    if(tok
      then
        if(rexMatchp("^refused" tok)
          then r = nil
        )
    )
    return(r)
  )
)

printf("wv_cds_probe.il loaded\n")
