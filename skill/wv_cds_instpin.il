; wv_cds_instpin.il - device terminal currents
;
; Plotting a net gives a voltage. Plotting a device *terminal* gives a current,
; and that is a different signal with a different name, so it is handled here
; and wv_cds_signal.il calls in.
;
; Naming, as worked out on the real schematic:
;
;   group = ( figure ( (instance 0 0 0) ) )      from geGetObjectSelectedSet
;     figure~>pin~>net~>name    the net on this terminal
;     instance~>baseName        the instance name
;     instance~>master~>sigNames the master's terminal names
;
;   two terminals ("MINUS" "PLUS")      -> <hier>.<inst>:*
;   three or more terminals             -> <hier>.<inst>:<n>
;                                          n = position of this terminal's net
;                                          in sigNames, counting from 1
;
;   A terminal whose net is not in sigNames has no number to give, so it is
;   skipped with a warning rather than sent as a wrong signal.
;
; A CURRENT IS NOT PROBED. geAddNetProbe wants a net, and the instance terminal
; path that would give the current - the reference script's
; subcktPath + instance~>name + "/" + nodeName, e.g. "/I0/I1/R2/PLUS" - is
; marked in the schematic instead, with the reference script's own marker: a
; small ellipse over the terminal, one and a half snap spacings across.
;
; The markers are rebuilt from the list wv reports, in the same round that
; re-probes the nets, so what is marked is exactly what wv is still showing: a
; current that was sent clicks ago keeps its marker, one you deleted in wv loses
; it. That is why the ellipse is placed per terminal instead of at the point the
; command was invoked at: wv can be showing several currents at once, while that
; point is a single one. Placing it correctly means converting the terminal's
; figure into the schematic's coordinates - see wvCdsInstMarkBox.
;
; The probe step therefore only has to RECOGNISE a current, so that a name like
; "R1:1" is not turned into the nonsense path "/R1:1" - which is exactly what
; geAddNetProbe answered with
;   GE-2133: The object R1:1 does not exist in cellview
; before. Only the names in the table can be marked as well: a current wv holds
; that this session never sent has no figure recorded for it.
;
; Recognition has three routes, and wvCdsIsCurrent tries them in order:
;
;   1. the table below, filled in while the terminal was selected
;   2. the same path worked out from the schematic, for a current this session
;      never sent - typed into wv by hand, or left over from an earlier
;      Virtuoso, when the table is empty
;   3. the shape of the name, ":" followed by digits or "*"
;
; Route 1 has to allow for the name wv REPORTS being different from the one it
; was asked for: wv_cds_plot.sh keys ::wv_cds_lines by sx_get_name of the
; signal sx_signal matched, so a two terminal device - requested as "R1:*" -
; comes back as "R1:1". That name used to miss the table and fall through to
; the plain net conversion; the two terminal case therefore also records its
; path under the name without the terminal suffix (see wvCdsInstEntry).
;
; Checked against the IC23.1 SKILL Reference:
;   geGetObjectSelectedSet( [ d_cellview ] )
;   makeTable( S_name [ g_default_value ] )   arrayref( g_collection g_index )
;   buildString( l_strings [ S_glueCharacters ] )   append1( l_list g_arg )
;   geCreateHilightSet( d_cellview l_layerPurposePair [ g_notGlobal ] )
;   geAddHilightEllipse( g_hlSetId l_bBox )  geDrawHilightSet( [w] [set] )
;   geDeleteHilightSet( g_hlSetId )  geIsValidHilightSet( h_hlSetId )
;   dbGetInstTransform( l_dbInstId )  dbTransformPoint( l_point l_list )
;   hiRedraw( [ w_window ] )
;   schGetEnv( t_variableName )  mapcar( u_func l_arg1 ... )
;
; Verified with:
;   check_new_functions.py wv_cds_instpin.il --strict
;
; One arity warning is a known false positive of the argument counting:
;   errset "3 of 2" - the call is errset(wvCdsInstHlSet->enable = t), one
;                    argument, but the counter splits an assignment into
;                    "wvCdsInstHlSet->enable", "=" and "t"

; wv name -> ( probe path  figure  hierarchy path ), filled in as currents are
; built. The figure and its hierarchy path are what mark the terminal later,
; when wv reports the name - see wvCdsInstMarkShow.
unless(boundp('wvCdsInstCurrent)
  wvCdsInstCurrent = makeTable("wvCdsInstCurrent" nil))

; The record for a device current, or nil for anything else (a plain net, say,
; which the caller converts from its own name).
procedure(wvCdsInstEntry(nm)
  let((e parts base acc x)
    e = nil
    when(stringp(nm)
      when(tablep(wvCdsInstCurrent)
        e = arrayref(wvCdsInstCurrent nm)
        unless(e
          ; wv answers with its OWN name for a signal, which is not always the
          ; one it was asked for: a two terminal device is requested as
          ; "R1:*" and wv reports its single current as "R1:1", so the exact
          ; lookup above misses and the probe fell through to the plain net
          ; conversion. Only that case stores a name without the terminal
          ; suffix, so retry the part before the last colon.
          ;
          ; The ":<digits or *>" test is what keeps everything else out. A bus
          ; net called data<0:3>, for instance, ends in "3>", so it is never
          ; cut short and still reaches the caller's own conversion.
          when(rexMatchp(":[0-9*]+$" nm)
            parts = parseString(nm ":")
            base = nil
            acc = nil
            ; base ends up as every part but the last
            foreach(x parts
              base = acc
              if(acc
                then acc = strcat(acc ":" x)
                else acc = x))
            when(base
              e = arrayref(wvCdsInstCurrent base))))))
    e))

; The probe path recorded for a device current, or nil for anything else.
procedure(wvCdsInstProbePath(nm)
  car(wvCdsInstEntry(nm)))

; figure + hierarchy path recorded for a device current, or nil
procedure(wvCdsInstMarkOf(nm)
  cdr(wvCdsInstEntry(nm)))

; The probe path of an instance terminal worked out from the SCHEMATIC rather
; than from the table above. This is the reference script's method (x1,
; CCSgetInstTermNodeName):
;
;   path = subcktPath + instance~>name + "/" + nodeName
;
; where subcktPath is the hierarchy the window descended into, instance is the
; instance the terminal belongs to, and nodeName is the net sitting on that
; terminal. Nothing has to have been selected for this to work: the instance
; lives in the cellview being edited, whatever wv is showing in this window is
; found in it, and the terminal comes from the index the name already carries
; ("R1:2" is terminal 2, counted in the master's sigNames), so a current typed
; into wv by hand - or left over from an earlier Virtuoso session, when the
; table above is empty - still gets a probe.
;
; nil when the name is not <instance>:<number>, or the instance, its terminal
; or that terminal's net cannot be found.
procedure(wvCdsInstProbePathFromSch(win nm)
  let((parts instKey idx hier x instName rest cv r inst term termName names net path)
    path = nil
    parts = parseString(nm ":")
    ; exactly one colon, with a terminal number after it
    when(parts && cdr(parts) && !cdr(cdr(parts))
      instKey = car(parts)
      idx = car(cdr(parts))
      when(rexMatchp("^[0-9]+$" idx)
        idx = atoi(idx)
        hier = parseString(instKey ".")
        when(hier
          ; the last dot separated piece is the instance; everything before it
          ; is the hierarchy, which the path needs but the cellview does not:
          ; geGetEditCellView already returns the level being edited
          instName = nil
          rest = nil
          foreach(x hier
            when(instName
              rest = append1(rest instName))
            instName = x)
          when(instName
            r = errset(geGetEditCellView(win))
            cv = when(r car(r))
            when(cv
              inst = nil
              foreach(i cv~>instances
                ; the name the wv name was built from is baseName; name is the
                ; same for a plain instance, and comparing both costs nothing
                when(i~>name == instName || i~>baseName == instName
                  inst = i))
              when(inst
                names = errset(inst~>master~>sigNames)
                names = when(names car(names))
                when(names
                  termName = nth(idx - 1 names)
                  when(termName
                    term = nil
                    foreach(t inst~>instTerms
                      when(t~>name == termName
                        term = t))
                    when(term
                      net = car(errset(term~>net~>name))
                      when(net
                        path = ""
                        foreach(x hier
                          path = strcat(path "/" x))
                        path = strcat(path "/" net)))))))))))
    path))

; Is this signal name a device current rather than a net?
;
; The probe step uses this to leave currents alone, so the two routes that
; resolve a path come first and the shape of the name is only the last resort.
; That order matters: ":<digits>" is a good guess but it is a guess, and a net
; whose name happens to end that way must not be dropped from the probes.
procedure(wvCdsIsCurrent(win nm)
  let((p)
    p = wvCdsInstProbePath(nm)
    unless(p
      p = wvCdsInstProbePathFromSch(win nm))
    unless(p
      p = rexMatchp(":[0-9*]+$" nm))
    p))

; Every highlight set these markers have been drawn in, NOT just the last one.
;
; A set belongs to the cellview it was created in, and a schematic window shows
; a different cellview once the user edits in place. Keeping only the newest set
; meant an older one could never be found again to delete, so a circle made at
; the top level stayed on screen while a sub-cellview was being edited. Keeping
; them all, and retrying the deletes, is what clears it - see wvCdsInstHlDrop.
unless(boundp('wvCdsInstHlSets)
  wvCdsInstHlSets = nil)

; Straighten that list out: a set that is no longer valid is dropped, and one
; that refuses to be deleted is kept for the next try. Returns how many are
; still waiting, which is normally 0.
procedure(wvCdsInstHlDrop()
  let((keep)
    keep = nil
    foreach(s wvCdsInstHlSets
      if(car(errset(geIsValidHilightSet(s)))
        then
          unless(car(errset(geDeleteHilightSet(s)))
            keep = cons(s keep))
        else
          nil
      )
    )
    wvCdsInstHlSets = reverse(keep)
    length(wvCdsInstHlSets)))

; The box, in the schematic's own coordinates, that marks one terminal: the
; reference script's small ellipse, one and a half snap spacings across.
;
; The conversion is the whole point. geEditToWindowPoint's reference states the
; rule: "Database access inquiries always return coordinate values in terms of
; the coordinate system of the cellview being interrogated", while "coordinate
; values passed to SKILL functions are always expressed with respect to the
; cellview being displayed". A terminal from geGetObjectSelectedSet comes with
; the path of instances it lives under, so its figure - and its bbox - are in
; the coordinate system of the innermost of those and NOT in the schematic's.
; Drawing that bbox straight as an ellipse is what put the marker in the wrong
; place; the reference script never had the problem because it marks the point
; the user clicked, which the editor already reports in displayed coordinates.
;
; dbGetInstTransform concatenates the transforms along that path - "if the
; object is an instance or a mosaic, its transform is also concatenated" - and
; dbTransformPoint applies it, which is the reference's own example: how "a
; certain shape (such as a pin on the master) in an instance of a cell is
; repositioned". With no path to walk (a figure already at the top level) there
; is nothing to convert, and the box is used as it comes.
;
; nil when the figure has no bbox to mark.
procedure(wvCdsInstMarkBox(fig hierPath)
  let((bBox xform ll ur c w g h dw dh box)
    box = nil
    bBox = car(errset(fig~>bBox))
    when(bBox
      ll = car(bBox)
      ur = car(cdr(bBox))
      ; the middle of the shape, in the coordinates it comes in
      c = list((car(ll) + car(ur)) / 2
               (car(cdr(ll)) + car(cdr(ur))) / 2)
      xform = car(errset(dbGetInstTransform(mapcar('car hierPath))))
      when(xform
        w = car(errset(dbTransformPoint(c xform)))
        when(w
          c = w))
      when(c
        ; the size does not depend on the frame, so it is taken from the shape
        dw = (car(ur) - car(ll)) / 2
        dh = (car(cdr(ur)) - car(cdr(ll))) / 2
        g = schGetEnv("schSnapSpacing")
        if(g
          then
            ; the reference script's marker: one and a half snap spacings
            ; across, so it stays a small circle at any zoom
            h = 1.5 * g
            dw = h
            dh = h
        )
        box = list(list(car(c) - dw car(cdr(c)) - dh)
                   list(car(c) + dw car(cdr(c)) + dh))
      )
    )
    box))

; Mark, in the schematic, every device current wv is showing, with the reference
; script's small ellipse over each terminal.
;
; Rebuilt from wv's list on every probe round, exactly like the net probes, and
; NOT drawn once per send: a current that is no longer in wv loses its marker,
; and one that an earlier click put there keeps it as long as wv still shows it.
; It has to be per terminal for that, so it comes from each terminal's recorded
; figure - which is also why the reference script's own use of a point cannot be
; copied: it marks the one point the command was invoked at, and wv can be
; showing several currents at once. wvCdsInstMarkBox is what puts those figures
; into the schematic's coordinates.
;
; Deleted BY SET before rebuilding, not with geDeleteAllHilightSet the way the
; reference script cleans up, which would throw away highlights the user made
; himself. Every set ever drawn is deleted, not just the last one - see
; wvCdsInstHlSets. A round with no currents still deletes, so markers never
; outlive the curves they belong to.
;
; The set is created on the CELLVIEW being edited, the way the reference script
; does it. A window highlight set (geCreateWindowHilightSet) was tried here as
; well, on the reasoning that the ellipse is in displayed coordinates - it drew
; something the user did not recognise as a marker at all, so it is not used.
; The same goes for geEditToWindowPoint, the edit-to-window conversion that was
; added for the descended case: with it the marker moved further off, not
; closer, so the conversion wvCdsInstMarkBox does is the whole of it.
;
; geCreateHilightSet wants a cellview that is displayed in a window, and returns
; a DISABLED set, and the reference says the window has to be refreshed before
; the objects are visible - hence the enable, the geDrawHilightSet and the
; hiRedraw at the end, without which a circle that has just been deleted keeps
; being painted.
;
; Returns how many were marked. A name wv is showing that this session never
; sent has no figure recorded for it, and a figure with no bbox cannot be drawn:
; both are counted as currents but not marked.
procedure(wvCdsInstMarkShow(win names)
  let((r cv set n lpp e nm box)
    ; the layer the reference script marks with
    lpp = list("hilite" "drawing1")
    wvCdsInstHlDrop()
    n = 0
    cv = car(errset(geGetEditCellView(win)))
    when(cv
      r = errset(geCreateHilightSet(cv lpp nil))
      set = when(r car(r))
      when(set
        wvCdsInstHlSets = cons(set wvCdsInstHlSets)
        errset(set->enable = t)
        foreach(nm names
          e = wvCdsInstMarkOf(nm)
          when(e
            box = wvCdsInstMarkBox(car(e) car(cdr(e)))
            when(box
              when(car(errset(geAddHilightEllipse(set box)))
                n = n + 1))))
        errset(geDrawHilightSet(win set)))
      unless(set
        warn("wvCds: could not open a highlight set - terminals left unmarked\n")))
    ; repaint, so a set deleted a moment ago stops being drawn at once
    errset(hiRedraw(win))
    n))

; One selected terminal -> the name to send to wv, or nil to skip it.
; pnames is the list of instances the window has descended into, so the name
; carries the same hierarchy prefix a net from this window would. The probe
; path is recorded as the name is built - wvCdsInstProbePathFromSch can work
; the same path out again from the name alone - and the figure, with the
; instance path it lives in, is left in the table for wvCdsInstMarkShow.
procedure(wvCdsInstPinName(g pnames)
  prog((fig inst net sigs instName sig n idx wvName path instKey)
    wvName = nil
    fig = car(g)
    ; group = (figure ((instance 0 0 0))): car(car(car(cdr(g)))) is the
    ; instance, the same object the reference calls "instance"
    inst = car(car(car(cdr(g))))
    when(fig
      when(inst
        net = car(errset(fig~>pin~>net~>name))
        sigs = car(errset(inst~>master~>sigNames))
        instName = car(errset(inst~>baseName))
        when(net
          when(sigs
            when(instName
              n = length(sigs)
              if(n == 2
                then
                  ; a two terminal device has one current, and wv calls it *
                  sig = "*"
                else
                  sig = nil
                  idx = 0
                  foreach(s sigs
                    idx = idx + 1
                    ; == on strings, as the reference script does
                    when(s == net
                      sig = sprintf(nil "%d" idx)))
                  unless(sig
                    ; no "(...)" after a word here on purpose: the function
                    ; checker reads "word (" inside a string as a call
                    warn("wvCds: %s is not a terminal of %s - skipped, nothing to plot\n"
                         net instName))
              )
              when(sig
                instKey = buildString(append1(pnames instName) ".")
                wvName = strcat(instKey ":" sig)
                path = strcat("/" buildString(append1(pnames instName) "/")
                              "/" net)
                ; the path, plus the figure and the instance path it lives in -
                ; the last two are what draws the terminal's marker once wv
                ; reports the name (wvCdsInstMarkOf, wvCdsInstMarkShow)
                wvCdsInstCurrent[wvName] = list(path fig car(cdr(g)))
                ; The probe step is driven by the names wv reports, and for the
                ; two terminal case that is not the name just asked for: sent
                ; "R1:*", wv answers "R1:1". Same instance, one current, so the
                ; record also answers to the name with the terminal suffix cut
                ; off. Three or more terminals record the exact name only:
                ; there, guessing between several currents is what would pick
                ; the wrong one.
                when(sig == "*"
                  wvCdsInstCurrent[instKey] = list(path fig car(cdr(g))))
                printf("wvCds: current %s -> %s (marked in the schematic once wv shows it)\n"
                       wvName path)
              )
            )
          )
        )
      )
    )
    ; return, not a trailing expression: prog falls through to nil unless a
    ; return is executed (let returns its last expression, prog does not), so
    ; ending on wvName returned nil and silently threw the name away
    return(wvName)
  )
)

; Every selected terminal that produced a name. Terminals that are not pins,
; or that could not be named, contribute nothing.
procedure(wvCdsInstPinNames(sel pnames)
  let((out nm)
    out = nil
    foreach(g sel
      nm = wvCdsInstPinName(g pnames)
      when(nm
        unless(member(nm out)
          out = append1(out nm))))
    out))

printf("wv_cds_instpin.il loaded - terminal currents: names, and a marker per current wv shows\n")
