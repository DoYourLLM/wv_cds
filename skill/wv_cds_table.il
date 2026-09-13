; wv_cds_table.il - list window for the wv cds integration
;
; Uses the user-verified idioms (tested on machine):
;   - button callbacks: list("wvCdsXxx(hiGetCurrentForm())") - the form
;     is passed into the callback, like CCSListBoxForm.il
;   - the schematic selection is read via the global sch_win, assigned
;     in wv_cds_menu.il at menu build and refreshed in wvCdsOpenForm
;   - the list box entries are read/written directly:
;       form->lb1->choices  (all entries)
;       form->lb1->value    (entries selected inside the list box)
;
; Flow: menu Example > wvcds -> plain form with the list box lb1.
;   Add    = push the schematic selection to the Python wv_cds GUI
;            (add listener 127.0.0.1:61889) and echo it into lb1
;   Remove = take the selection inside lb1 out
; (sending to wv is decided in the Python GUI's "Send to WV" button)

; Add: push the schematic selection to the Python GUI, then echo it
; into lb1 as a local mirror
procedure(wvCdsAdd(form)
  let((signals lb1Choices)
    signals = CCSwvPlotSelectedSignals(sch_win)
    if(null(signals) then
      warn("wvCds: nothing to plot - select a net, a wire, or a device terminal\n")
    else
      wvCdsSendToGui(signals)
      lb1Choices = form->lb1->choices
      form->lb1->choices = append(lb1Choices signals))))

; Remove: take everything selected inside lb1 out of the list.
; A loop, not car: the list box allows a multi-selection, and taking only the
; first value meant several highlighted nets needed one click each (the Python
; GUI's Remove Selected drops them all, so the two felt different for no
; reason).
procedure(wvCdsRemove(form)
  let((lb1Value lb1Choices)
    lb1Value = form->lb1->value
    when(lb1Value
      lb1Choices = form->lb1->choices
      foreach(v lb1Value
        lb1Choices = remove(v lb1Choices))
      form->lb1->choices = lb1Choices)))

; build the form fresh every time (no dock, no nesting).
; The buttons are hiCreateButtonBoxField, exactly like the working
; CCSListBoxForm.il copy on the user's machine (hiCreateButton did not
; fire there).
procedure(wvCdsBuildForm()
  let((lb1 btnAdd btnRemove)
    lb1 = hiCreateListBoxField(?name 'lb1 ?prompt "Selected Nets"
      ?choices nil ?valueByPosition nil)
    btnAdd = hiCreateButtonBoxField(?name 'add ?choices list("Add")
      ?callback list("wvCdsAdd(hiGetCurrentForm())") ?prompt " ")
    btnRemove = hiCreateButtonBoxField(?name 'remove ?choices list("Remove")
      ?callback list("wvCdsRemove(hiGetCurrentForm())") ?prompt " ")
    hiCreateAppForm(
      ?name 'wvCdsForm
      ?formTitle "wv cds"
      ?fields list(
        list(lb1 10:10 200:150 50)
        list(btnAdd 10:170 90:30 10)
        list(btnRemove 110:170 90:30 10)))))

; open the form window
procedure(wvCdsOpenForm()
  let((form)
    ; refresh the schematic window capture at click time (the banner
    ; menu click makes the schematic current)
    sch_win = hiGetCurrentWindow()
    ; close any stale window left over from the old dock-window version
    when(boundp('wvCdsSessionWin)
      when(wvCdsSessionWin && member(wvCdsSessionWin hiGetWindowList())
        errset(hiCloseWindow(wvCdsSessionWin)))
      wvCdsSessionWin = nil)
    form = wvCdsBuildForm()
    hiDisplayForm(form)))

printf("wv_cds_table.il loaded\n")
