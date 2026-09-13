; wv_cds_instpin.il - device terminal currents
;
; Plotting a net gives a voltage. Plotting a device *terminal* gives a current,
; and that is a different signal with a different name and a different probe,
; so it is handled here and wv_cds_signal.il calls in.
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
; Currents are probed at the INSTANCE TERMINAL path, the way the reference
; script builds it (x1: subcktPath + instance~>name + "/" + nodeName), e.g.
; "/I0/I1/R2/PLUS". That path cannot be recovered from the name we send to wv -
; "R2:*" carries no terminal - so it is recorded here at selection time and
; looked up again when the probe step runs. Both happen inside the same click
; (and, for the GUI route, inside the same Virtuoso session), so the table
; never has to outlive the session.
;
; The lookup is by the name wv REPORTS, and that is not always the name we
; asked for. wv_cds_plot.sh keys ::wv_cds_lines by sx_get_name of the signal
; sx_signal matched, so a two terminal device - requested as "R1:*" - comes
; back as "R1:1". That name used to miss the table and fall through to the
; plain net conversion, which turned it into the path "/R1:1" and made
; geAddNetProbe answer "GE-2133: The object R1:1 does not exist in cellview".
; The two terminal case therefore also records the same path under the name
; without the terminal suffix (see wvCdsInstProbePath).
;
; Checked against the IC23.1 SKILL Reference:
;   geGetObjectSelectedSet( [ d_cellview ] )
;   makeTable( S_name [ g_default_value ] )   arrayref( g_collection g_index )
;   buildString( l_strings [ S_glueCharacters ] )   append1( l_list g_arg )
;
; Verified with:
;   check_new_functions.py wv_cds_instpin.il --strict

; wv name -> probe path, filled in as signals are built
unless(boundp('wvCdsInstProbe)
  wvCdsInstProbe = makeTable("wvCdsInstProbe" nil))

; The probe path recorded for a device current, or nil for anything else
; (a plain net, say, which the caller converts from its own name).
procedure(wvCdsInstProbePath(nm)
  let((p parts base acc x)
    p = nil
    when(stringp(nm)
      when(tablep(wvCdsInstProbe)
        p = arrayref(wvCdsInstProbe nm)
        unless(p
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
              p = arrayref(wvCdsInstProbe base))))))
    p))

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

; One selected terminal -> the name to send to wv, or nil to skip it.
; pnames is the list of instances the window has descended into, so the name
; carries the same hierarchy prefix a net from this window would. The probe
; path is recorded as the name is built, and wvCdsInstProbePathFromSch can
; work the same path out again from the name alone.
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
                wvCdsInstProbe[wvName] = path
                ; The probe is driven by the names wv reports, and for the two
                ; terminal case that is not the name just asked for: sent
                ; "R1:*", wv answers "R1:1". Same instance, one current, so
                ; the path also answers to the name with the terminal suffix
                ; cut off. Three or more terminals record the exact name only:
                ; there, guessing between several currents is what would probe
                ; the wrong one.
                when(sig == "*"
                  wvCdsInstProbe[instKey] = path)
                printf("wvCds: current %s probes %s\n" wvName path)
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

printf("wv_cds_instpin.il loaded\n")
