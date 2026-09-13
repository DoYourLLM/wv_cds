; wv_cds_probe.il - probe, in the schematic, the nets wv is displaying
;
; Called at the end of a "Send to WV (Direct)" click. wv_cds_names.sh reports
; the signals wv still has on screen (from the ::wv_cds_lines map that
; wv_cds_plot.sh maintains inside wv), and each one gets a net probe:
;
;   geAddNetProbe(win nil "/I0/I1/n1")
;
; geAddNetProbe wants a slash path - the reference says "The string should be
; in the format of /instname/instname/.../objectName" - while the names coming
; out of wv use the dotted form (I0.I1.n1), so wvCdsProbeNet converts.
;
; Checked against the IC23.1 SKILL Reference (skdfref):
;   geAddNetProbe( [w_windowId] [l_lpp] [lt_probeSpec] ) => o_probe
;   geDeleteAllProbe( [w_windowId] [g_crossProbeFlag] ) => t / nil
;
; Verified with:
;   check_new_functions.py wv_cds_probe.il --strict --allow runSyncIPC
;   (runSyncIPC lives in wv_cds_ipc.il, so the checker cannot see it here)

; Add one net probe for the signal name nm, in window win.
; Returns the probe object, or nil when nothing was added.
procedure(wvCdsProbeNet(win nm)
  let((path parts r hit)
    hit = nil
    ; guarded one condition per level: && is not reliably short-circuiting in
    ; SKILL, so rexMatchp must not be reached with a non-string
    when(win
      when(stringp(nm)
        unless(rexMatchp("^$" nm)
          path = ""
          parts = parseString(nm ".")
          when(car(parts)
            foreach(x parts
              path = strcat(path "/" x)))
          r = errset(geAddNetProbe(win nil path))
          hit = when(r car(r))
          if(hit
            then
              printf("wvCds: probe %s -> %s\n" nm path)
            else
              printf("wvCds: probe FAILED %s -> %s\n" nm path)))))
    hit))

; Clear the probes in win, then create one per name.
; Returns the number of probes that were actually created.
;
; The clear is deliberate and unconditional once we are called: it is what
; makes a net that is no longer in wv lose its probe. It also removes probes
; you placed by hand in that window - the caller only reaches this point when
; wv really did report a list, so a failed click never clears anything.
procedure(wvCdsProbeNames(win names)
  let((n)
    n = 0
    cond(
      (!win
        warn("wvCds: no schematic window - nothing probed\n"))
      ((null(names)
        printf("wvCds: nothing to probe - wv reported no signals\n")))
      (t
        errset(geDeleteAllProbe(win))
        foreach(nm names
          when(wvCdsProbeNet(win nm)
            n = n + 1))
        printf("wvCds: probed %d of %d net(s) in the schematic\n"
               n length(names))))
    n))

; Ask wv which signals it is still displaying.
;
; Returns nil when wv did not answer, and otherwise the reply as a token list
; whose FIRST element is the count:
;
;   ("0")                     wv answered; this tool has nothing on screen
;   ("3" "I0.n1" "VDD" "n2")  wv answered; those three are on screen
;
; The count is in the reply precisely so the two cases can be told apart:
; parseString("") and a "refused" reply are both nil here, so without it
; "nothing is displayed any more" (clear the probes) would look identical to
; "wv is not answering" (leave the probes alone). The caller drops the count
; with cdr.
procedure(wvCdsDisplayedNames()
  let((r tok refused)
    r = runSyncIPC(sprintf(nil "%s/wv_cds_names.sh" WV_CDS_SH_DIR))
    ; two steps on purpose: relying on && to short-circuit an argument check
    ; is not safe in SKILL
    tok = if(r car(r) nil)
    refused = if(tok rexMatchp("^refused" tok) nil)
    if(refused nil r)))

printf("wv_cds_probe.il loaded\n")
