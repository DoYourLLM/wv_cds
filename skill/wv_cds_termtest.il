; wv_cds_termtest.il - where does the terminal marker actually land?
;
; A standalone check, NOT loaded by load_wv_cds.il. Paste it in the CIW with
;     load("<the package>/skill/wv_cds_termtest.il")
; then, with one device terminal selected in the schematic:
;     wvTestTerminal()
;
; It draws two circles and prints the numbers behind them:
;
;   small  - where wv_cds_instpin.il draws its marker: the middle of the
;            selected figure, converted out of the instance's coordinate system
;            into the schematic's
;   big    - around the point you clicked, which is ground truth: the editor
;            reports that one in displayed coordinates already
;
; Concentric circles mean the marker is placed correctly. If they are not, the
; two printed deltas say by how much and in which direction each candidate is
; off, which is what decides between "the figure bbox is in the instance's
; coordinates" and "it is in the schematic's".
;
; Each run ADDS its circles and leaves the earlier ones in place, so several
; terminals can be checked one after another - the line at the top of the
; output says how many are drawn. wvTestTermClear() removes all of them.
; Nothing here talks to wv, and nothing here changes any file.
;
; Checked against the IC23.1 SKILL Reference:
;   hiGetCurrentWindow()  geGetEditCellView( [w_windowId] )
;   hiGetCommandPoint( [w_windowId] [g_dontAdjust] )
;   schGetEnv( t_variableName )  geGetObjectSelectedSet( [ d_cellview ] )
;   dbGetInstTransform( l_dbInstId )  dbTransformPoint( l_point l_list )
;   geCreateHilightSet( d_cellview l_layerPurposePair [ g_notGlobal ] )
;   geAddHilightEllipse( g_hlSetId l_bBox )  geDeleteHilightSet( g_hlSetId )
;
; Verified with:
;   check_new_functions.py wv_cds_termtest.il --strict \
;     --allow wvCdsInstPinName
;   (it is in wv_cds_instpin.il, so the checker cannot see it from here)
;
; One arity warning is a known false positive of the argument counting:
;   errset "3 of 2" - the call is errset(set->enable = t), one argument, but
;                    the counter splits an assignment into "set->enable",
;                    "=" and "t"

; the highlight sets this test created, so wvTestTermClear can delete exactly
; those and leave the user's own highlights alone
unless(boundp('wvTestTermSets)
  wvTestTermSets = nil)

; one circle of radius r around the point c, in its own highlight set
procedure(wvTestTermCircle(cv c r)
  let((set)
    set = car(errset(geCreateHilightSet(cv list("hilite" "drawing1") nil)))
    when(set
      errset(set->enable = t)
      errset(geAddHilightEllipse(set
        list(list(car(c) - r car(cdr(c)) - r)
             list(car(c) + r car(cdr(c)) + r))))
      wvTestTermSets = cons(set wvTestTermSets))
    set))

procedure(wvTestTermClear()
  foreach(s wvTestTermSets
    errset(geDeleteHilightSet(s)))
  wvTestTermSets = nil
  printf("wvTestTerm: circles cleared\n"))

; middle of a list of two points
procedure(wvTestTermCentre(bBox)
  let((ll ur)
    ll = car(bBox)
    ur = car(cdr(bBox))
    when(ll && ur
      list((car(ll) + car(ur)) / 2
           (car(cdr(ll)) + car(cdr(ur))) / 2))))

; a - b, as a point, for reading off a printed delta
procedure(wvTestTermDelta(a b)
  list(car(a) - car(b) car(cdr(a)) - car(cdr(b))))

procedure(wvTestTerminal()
  let((win cv pt grid sel g fig inst hier b c xform c2 r)
    win = hiGetCurrentWindow()
    cv = geGetEditCellView(win)
    grid = schGetEnv("schSnapSpacing")
    pt = hiGetCommandPoint(win)
    printf("\n=== wv_cds terminal test ===\n")
    printf("circles drawn : %d from earlier picks - wvTestTermClear() removes them\n"
           length(wvTestTermSets))
    printf("cellview      : %L\n" cv)
    printf("snap spacing  : %L\n" grid)
    printf("click point   : %L\n" pt)
    sel = car(errset(geGetObjectSelectedSet(cv)))
    if(!sel
      then
        printf("nothing selected - select the device terminal first\n")
      else
        foreach(g sel
          fig = car(g)
          hier = car(cdr(g))
          inst = car(car(car(cdr(g))))
          printf("\n-- one selected object --\n")
          printf("figure        : %L  objType %L\n"
                 fig car(errset(fig~>objType)))
          printf("hierarchy path: %L\n" hier)
          printf("instance      : %L  name %L\n"
                 inst car(errset(inst~>name)))
          printf("pin net       : %L\n"
                 car(errset(fig~>pin~>net~>name)))
          printf("figure bBox   : %L\n" car(errset(fig~>bBox)))
          printf("instance bBox : %L\n" car(errset(inst~>bBox)))
          b = car(errset(fig~>bBox))
          c = wvTestTermCentre(b)
          printf("figure centre : %L\n" c)
          xform = car(errset(dbGetInstTransform(mapcar('car hier))))
          printf("transform     : %L\n" xform)
          c2 = car(errset(dbTransformPoint(c xform)))
          printf("transformed   : %L\n" c2)
          when(c && pt
            printf("delta raw     : %L\n" wvTestTermDelta(c pt)))
          when(c2 && pt
            printf("delta xform   : %L\n" wvTestTermDelta(c2 pt)))
          ; which name wv_cds_instpin.il would send for this terminal
          if(boundp('wvCdsInstPinName)
            then
              printf("package name  : %L\n" wvCdsInstPinName(g nil))
            else
              printf("package name  : wv_cds_instpin.il is not loaded\n"))
          r = 1.5 * grid
          when(grid && c2
            ; small: where the marker code puts it
            wvTestTermCircle(cv c2 r))
          r = 4.5 * grid
          when(grid && pt
            ; big: around the click, three times as wide
            wvTestTermCircle(cv pt r))
        )
    )
    printf("=== end: %d circle set(s) drawn, wvTestTermClear() removes them ===\n"
           length(wvTestTermSets))
  ))

printf("wv_cds_termtest.il loaded - wvTestTerminal() with a terminal selected\n")
