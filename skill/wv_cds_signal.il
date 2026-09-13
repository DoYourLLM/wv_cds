; wv_cds_signal.il - collect selected signal names from the schematic
;
; CCSwvPlotSelectedSignals(sch_win) -> list of net names selected in
; sch_win (net/inst/pin/wire/line objects; wire/line shapes report the
; net they belong to). Returns nil when nothing is selected.
;
; Names normally carry the HIERARCHY path of the sch window: when the user
; has descended into instances by edit-in-place, the instance path from
; geGetInstHierPath is prefixed, e.g. I0.I1.net1. Top-level nets keep their
; flat name. This matches the signal paths inside the fsdb, which wv
; resolves with sx_signal.
;
; One exception, the net sitting on a port: when the selected net's name is
; also the name of a pin of the current cellview, that net IS the port net
; and its signal is named one level up. The current level's instance
; segment is therefore dropped - descended two levels, I0.I1.n1 becomes
; I0.n1; with a single level the flat n1 remains. Pin names come from
; schGetPinOrder.
;
; Example, top instantiates I0 whose cell instantiates I1:
;   at top level, select n1                  -> n1
;   descended into I0, select n1             -> I0.n1
;   descended into I1, select n1             -> I0.I1.n1
;   descended into I1, select its port net n1 -> I0.n1

procedure(CCSwvPlotSelectedSignals(sch_win)
  let((r sel names objType nm path pnames pparents pnm cv pins prefix portNet cur)
    r = errset(geGetSelSet(sch_win))
    sel = when(r car(r))
    names = nil
    ; the instances that were descended into, e.g. (I0 I1); empty at top
    r = errset(geGetInstHierPath(sch_win))
    path = when(r car(r))
    ; pnames   = every descended instance
    ; pparents = the same minus the last one, i.e. minus the current level
    pnames = nil
    pparents = nil
    when(path
      foreach(e path
        when(listp(e) && e
          r = errset(car(e)~>name)
          pnm = when(r car(r))
          when(pnm
            ; the list built so far is exactly all-but-the-new-last
            pparents = pnames
            pnames = append1(pnames pnm)))))
    ; the window's cellview: needed for the pin list below, and for the
    ; object-selected set the device terminals come from
    r = errset(geGetEditCellView(sch_win))
    cv = when(r car(r))
    ; Device terminals are CURRENTS, not voltages. They need different names
    ; (see wv_cds_instpin.il) and a probe path that cannot be recovered from
    ; those names afterwards, so it is recorded there as they are built.
    ;
    ; Out here, not inside the geGetSelSet loop below: a selected terminal need
    ; not appear in geGetSelSet at all, and geGetObjectSelectedSet is the call
    ; that was verified to expose it.
    when(cv
      r = errset(geGetObjectSelectedSet(cv))
      when(r
        cur = wvCdsInstPinNames(car(r) pnames)
        when(cur
          ; one line per click that produced currents, so the CIW shows what
          ; was collected as well as what each name probes
          printf("wvCds: device terminals in the selection: %L\n" cur)
          foreach(nm cur
            unless(member(nm names)
              names = append1(names nm))))))
    when(sel
      ; pin names of the cellview currently shown in the window
      pins = nil
      when(cv
        r = errset(schGetPinOrder(cv))
        pins = when(r car(r)))
      foreach(o sel
        r = errset(o~>objType)
        objType = when(r car(r))
        ; wire/line shapes report the net they belong to; fall back to the
        ; object's own name for other types
        r = errset(o~>net~>name)
        nm = when(r car(r))
        unless(nm
          r = errset(o~>name)
          nm = when(r car(r)))
        when(objType && nm && member(objType list("net" "inst" "pin" "wire" "line"))
          ; is this the net sitting on a port of the current cellview?
          ; instances are left out because their name is not a signal name
          portNet = pins && member(nm pins) && !member(objType list("inst"))
          prefix = if(portNet pparents pnames)
          when(prefix
            nm = strcat(buildString(prefix ".") "." nm))
          ; several selected objects can belong to the same net (two wire
          ; segments, a wire and its label), so keep each name once
          unless(member(nm names)
            names = append1(names nm)))))
    names))

printf("wv_cds_signal.il loaded\n")
