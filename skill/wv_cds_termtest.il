; wv_cds_termtest.il - does this Cadence take the terminal probe path?
;
; Standalone, NOT loaded by load_wv_cds.il. Paste it in the CIW with
;
;     load("<the package>/skill/wv_cds_termtest.il")
;
; then, with one device terminal selected in the schematic:
;
;     wvTestTerminal()
;
; It prints the wv name and the instance terminal path wv_cds_instpin.il works
; out for that selection, and then calls the two probes the marker is built
; from, to see which one this build accepts:
;
;     geAddTermProbe( win nil "/R1/PLUS" )
;     geAddInstProbe( win nil "/R1/PLUS" )
;
; Both are ordinary probes. The schematic draws them in the probe colour on one
; of the reserved layers y0..y9, they are cleared by
; geDeleteAllProbe(hiGetCurrentWindow()) along with every other probe, and being
; attached to the object instead of to coordinates they cannot be left behind on
; another level.
;
; wvTestTermClear() removes the probes this test made and nothing else.
;
; Checked against the IC23.1 SKILL Reference:
;   hiGetCurrentWindow()  geGetEditCellView( [w_windowId] )
;   geGetObjectSelectedSet( [ d_cellview ] )
;   geAddTermProbe( [w_windowId] [l_lpp] [lt_probeSpec] )
;   geAddInstProbe( [w_windowId] [l_lpp] [lt_probeSpec] )
;   geDeleteProbe( w_windowId o_userType [g_crossProbeFlag] )
;
; Verified with:
;   check_new_functions.py wv_cds_termtest.il --strict \
;     --allow wvCdsInstPinName,wvCdsInstProbePath
;   (they are in wv_cds_instpin.il, so the checker cannot see them from here)

; the probes this test created, so wvTestTermClear deletes exactly those
unless(boundp('wvTestTermProbes)
  wvTestTermProbes = nil)

procedure(wvTestTermClear()
  let((win)
    win = hiGetCurrentWindow()
    foreach(p wvTestTermProbes
      errset(geDeleteProbe(win p)))
    wvTestTermProbes = nil
    printf("wvTestTerm: test probes removed\n")))

procedure(wvTestTerminal()
  let((win cv sel g fig inst net instName sigs nm path r p)
    win = hiGetCurrentWindow()
    cv = geGetEditCellView(win)
    wvTestTermClear()
    printf("\n=== wv_cds terminal probe test ===\n")
    printf("cellview      : %L\n" cv)
    sel = car(errset(geGetObjectSelectedSet(cv)))
    if(!sel
      then
        printf("nothing selected - select the device terminal first\n")
      else
        foreach(g sel
          fig = car(g)
          inst = car(car(car(cdr(g))))
          net = car(errset(fig~>pin~>net~>name))
          instName = car(errset(inst~>baseName))
          sigs = car(errset(inst~>master~>sigNames))
          printf("\n-- one selected object --\n")
          printf("figure        : %L\n" fig)
          printf("instance      : %L\n" instName)
          printf("terminal net  : %L\n" net)
          printf("term names    : %L\n" sigs)
          ; what the package works out from the same selection
          path = nil
          if(boundp('wvCdsInstPinName)
            then
              nm = wvCdsInstPinName(g nil)
              printf("package name  : %L\n" nm)
              path = wvCdsInstProbePath(nm)
            else
              printf("package name  : wv_cds_instpin.il is not loaded\n"))
          unless(path
            ; the top level form, for when the package is not loaded
            path = strcat("/" instName "/" net))
          printf("path tried    : %L\n" path)
          r = errset(geAddTermProbe(win nil path))
          p = when(r car(r))
          printf("geAddTermProbe: %L\n" p)
          when(p
            wvTestTermProbes = cons(p wvTestTermProbes))
          r = errset(geAddInstProbe(win nil path))
          p = when(r car(r))
          printf("geAddInstProbe: %L\n" p)
          when(p
            wvTestTermProbes = cons(p wvTestTermProbes))
        )
    )
    printf("=== end: %d added, wvTestTermClear() removes them ===\n"
           length(wvTestTermProbes))
  ))

printf("wv_cds_termtest.il loaded - wvTestTerminal() with a terminal selected\n")
