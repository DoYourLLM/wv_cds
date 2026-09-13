; wv_cds_probe.il - probe, in the schematic, the nets wv is displaying
;
; Called at the end of a "Send to WV (Direct)" click. The names come from
; wv_cds_names.py (in python/), which asks wv what it is still showing, and
; each NET among them gets a probe:
;
;   geAddNetProbe(win nil "/I0/I1/n1")
;
; geAddNetProbe wants a slash path - the reference says "The string should be
; in the format of /instname/instname/.../objectName" - while the names coming
; out of wv use the dotted form (I0.n1), so wvCdsProbeNet converts.
;
; Device currents arrive in the same list and are NOT net probes: geAddNetProbe
; wants a net, and sending "R1:1" on as a path is what produced
; "GE-2133: The object R1:1 does not exist in cellview". Each current gets a
; TERMINAL probe on the terminal it came from instead - an ordinary probe, drawn
; on the reserved probe layers, cleared by geDeleteAllProbe with all the others
; (wvCdsInstProbeAdd, in wv_cds_instpin.il).
;
; Checked against the IC23.1 SKILL Reference (skdfref):
;   geAddNetProbe( [w_windowId] [l_lpp] [lt_probeSpec] ) => o_probe
;   geDeleteAllProbe( [w_windowId] [g_crossProbeFlag] ) => t / nil
;
; Verified with:
;   check_new_functions.py wv_cds_probe.il --strict \
;     --allow runSyncIPC,wvCdsPython,wvCdsIsCurrent
;   (they live in wv_cds_ipc.il and wv_cds_instpin.il, so the checker cannot
;   see them from here)

; The interpreter used for the python/ helpers: $WV_CDS_PYTHON when it is
; exported, otherwise whatever python3 resolves to. Same rule as
; wv_cds_gui_start.sh.
procedure(wvCdsPython()
  let((p)
    p = getShellEnvVar("WV_CDS_PYTHON")
    if(p p "python3")))

; Add one net probe for the signal name nm, in window win.
; Returns the probe object, or nil when nothing was added.
;
; Device currents never reach here: the caller keeps them out with
; wvCdsIsCurrent, because geAddNetProbe wants a net and a terminal current gets
; a marker in the schematic instead (see wv_cds_instpin.il). Sending a current
; name on as a path is what produced
;   GE-2133: The object R1:1 does not exist in cellview
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
  prog((n ncur nmark nm)
    n = 0
    ncur = 0
    if(win == nil
      then
        warn("wvCds: no schematic window - nothing probed\n")
        return(n)
    )
    ; names may be nil, and that is NOT "do nothing". The caller only reaches
    ; this point when wv answered, so an empty list means every signal this
    ; tool plotted is gone from wv - and then every probe here goes too.
    ;
    ; An early return used to sit here and made "you deleted everything in wv"
    ; behave exactly like "wv never answered": the probes stayed. The count
    ; prefix exists to keep those two apart in the caller; collapsing them
    ; again in here threw that away.
    errset(geDeleteAllProbe(win))
    foreach(nm names
      ; wv reports currents and nets in one list, and each gets the probe that
      ; fits it: a net probe for a net, a terminal probe for a device current
      ; (wvCdsInstProbeAdd). Both are ordinary probes, so this one
      ; geDeleteAllProbe above clears them both, and both are rebuilt from this
      ; list - a signal still in wv keeps its probe, one you deleted in wv loses
      ; it.
      if(wvCdsIsCurrent(win nm)
        then
          ncur = ncur + 1
          if(wvCdsInstProbeAdd(win nm)
            then nmark = nmark + 1)
        else
          if(wvCdsProbeNet(win nm)
            then n = n + 1
          )
      )
    )
    printf("wvCds: cleared the window, then probed %d net(s) and %d of %d current(s)\n"
           n nmark ncur)
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
;
; The names are echoed to the CIW as they arrive, before anything is probed:
; when a probe comes back FAILED this is what says whether wv handed us a name
; that does not exist in this schematic, or nothing at all.
procedure(wvCdsDisplayedNames()
  prog((r tok names)
    r = runSyncIPC(sprintf(nil "%s %s/python/wv_cds_names.py"
                             wvCdsPython() WV_CDS_SH_DIR))
    tok = car(r)
    if(tok
      then
        if(rexMatchp("^refused" tok)
          then r = nil
          else
            names = cdr(r)
            printf("wvCds: wv is showing %d signal(s): %L\n"
                   length(names) names)
        )
    )
    return(r)
  )
)

; The command the Python GUI sends over the skill server (see
; wv_cds_skill_server.il) after it has finished plotting, so the schematic gets
; the probes too. The GUI is a separate process and cannot touch the schematic
; itself; this runs inside Virtuoso instead.
;
; The skill server evaluates commands from the CIW's context, so there is no
; right-click window here - take the current one. Unlike the Direct path there
; is no way to know which schematic the user meant, so a window that is not
; probeable is refused rather than guessed at.
;
; Same rule as everything else: nil from wvCdsDisplayedNames means wv did not
; answer, and then the probes are left exactly as they were.
procedure(wvCdsProbeFromGui()
  prog((win names)
    win = hiGetCurrentWindow()
    if(win == nil
      then
        warn("wvCds: no current window - probes left as they were\n")
        return(nil)
    )
    names = wvCdsDisplayedNames()
    if(names
      then
        wvCdsProbeNames(win cdr(names))
      else
        warn("wvCds: wv did not answer - probes left as they were\n")
    )
    return(names)
  )
)

; The same round, run by hand. Nothing calls it: it is how to check the probes
; and the terminal markers without clicking anything -
;
;   wvCdsRefresh()
;
; in the CIW, with the schematic window current. The reply and the line
; wvCdsProbeNames prints say how much of what wv is showing got a probe and a
; marker, which is the quickest way to tell a stale load from a real problem.
procedure(wvCdsRefresh()
  let((win names)
    win = hiGetCurrentWindow()
    names = wvCdsDisplayedNames()
    if(names
      then
        wvCdsProbeNames(win cdr(names))
      else
        warn("wvCds: wv did not answer - nothing changed\n")
    )
    names))

printf("wv_cds_probe.il loaded - nets are probed, currents are marked in the schematic\n")
