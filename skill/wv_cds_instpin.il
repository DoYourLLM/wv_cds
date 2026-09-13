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
  let((p)
    p = nil
    when(stringp(nm)
      when(tablep(wvCdsInstProbe)
        p = arrayref(wvCdsInstProbe nm)))
    p))

; One selected terminal -> the name to send to wv, or nil to skip it.
; pnames is the list of instances the window has descended into, so the name
; carries the same hierarchy prefix a net from this window would.
procedure(wvCdsInstPinName(g pnames)
  prog((fig inst net sigs instName sig n idx wvName path)
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
                wvName = strcat(buildString(append1(pnames instName) ".") ":" sig)
                path = strcat("/" buildString(append1(pnames instName) "/")
                              "/" net)
                wvCdsInstProbe[wvName] = path
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
