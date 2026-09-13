; schRMB.il - schematic canvas right-click (object-sensitive) menu additions
;
; Adds two items to the net right-click menu:
;
;   Send to WV (Direct)            -> wvCdsSendSelectionDirect() -> wv RPC      127.0.0.1:61888
;   Send to WV_CDS (Interactive)   -> wvCdsSendSelectionToGui()  -> Python GUI  127.0.0.1:61889
;
; Both callbacks take no arguments and read the schematic selection
; themselves (CCSwvPlotSelectedSignals on the current schematic window).
; They are defined in wv_cds_menu.il, which is loaded before this file.
;
; The schematic editor keeps a SEPARATE object-sensitive menu per object
; category, so the items have to be registered on every category they
; should appear on. Two are needed for nets:
;
;   "wire"        - a single wire/net under the cursor
;   "schMultiple" - more than one object under the cursor, which is the
;                   category the editor uses once two wires are selected
;
; Registering only "wire" makes the items disappear as soon as two wires
; sit under the cursor. To cover more categories, add them to the list in
; CCSinsertPopUp; the valid names are listed at the bottom of this file.
;
; schGetPopUpMenu returns the object-sensitive menu (OSM) for a category
; and hiInsertMenuItem prepends into it, so the built-in entries of the net
; menu are preserved. Deleting an item before inserting it keeps the
; post-install trigger idempotent: the trigger fires once per schematic
; window, while the OSM handle may be shared between windows.
;
; NOTE: schGetPopUpMenu is not indexed in the IC23.1 SKILL reference (the
; documented pair is schRegisterPopUpMenu / schUnregisterPopUpMenu, which
; REPLACES a category menu instead of extending it). It is kept here
; because it is the only variant that appends to the built-in menu; the
; call is wrapped in errset, so a build without it degrades to "no extra
; right-click items" instead of breaking the trigger.
;
; Verified with:
;   check_new_functions.py schRMB.il --strict \
;     --allow schGetPopUpMenu,wvCdsSendSelectionDirect,wvCdsSendSelectionToGui

; delete-then-insert one item at the top of popMenu; idempotent
procedure(wvCdsRmbAddItem(popMenu itemName itemText callback)
  errset(hiDeleteMenuItem(popMenu itemName))
  hiInsertMenuItem(popMenu
    hiCreateMenuItem(?name itemName ?itemText itemText ?callback callback)
    0))

; put both items on one category menu. They are added in reverse so the
; final menu reads "Send to WV (Direct)" first and "Send to WV_CDS
; (Interactive)" second.
;
; "(Interactive)" is part of the visible text only - the item NAME stays
; wvCdsSendGuiRmb, which is what wvCdsRmbAddItem deletes before re-inserting.
procedure(wvCdsRmbAddPair(popMenu)
  wvCdsRmbAddItem(popMenu 'wvCdsSendGuiRmb
                  "Send to WV_CDS (Interactive)" "wvCdsSendSelectionToGui()")
  wvCdsRmbAddItem(popMenu 'wvCdsSendDirectRmb
                  "Send to WV (Direct)" "wvCdsSendSelectionDirect()"))

; post-install trigger: runs after the schematic editor is initialized
procedure(CCSinsertPopUp(args)
  foreach(cat list("wire" "schMultiple" "instPin" "schPin" "symPin")
    let((r popMenu)
      r = errset(schGetPopUpMenu(cat))
      popMenu = when(r car(r))
      when(popMenu
        wvCdsRmbAddPair(popMenu)))))

; register once per view type: deGetAppInfo returns nil for view types this
; build does not have (e.g. schematicXL on some releases), and
; userPostInstallTrigList avoids the duplicate-registration warning when the
; file is loaded again
foreach(vt list("schematic" "schematicXL")
  let((appInfo)
    when(appInfo = deGetAppInfo(vt)
      unless(member('CCSinsertPopUp appInfo->userPostInstallTrigList)
        deRegUserTriggers(vt nil nil 'CCSinsertPopUp)))))

; Navigator RMB (kept as it was)
mbRegisterAction("schematic" "schMenu1" "Custom Menu" "printf(\"This is Schematic test menu item\")" "t")
mbSetContextData("schematic" "schMenu1" "Any" "Navigator Canvas" "Common")

; Other object categories accepted by schGetPopUpMenu, in case more menus
; should carry the items:
; "wire", "instance", "instPin", "label", "marker", "schNone", "schPin",
; "schMultiple", "schUnknown", "shapes", "symPin", "symNone", "symUnknown",
; "symMultiple", "schStandard", "symStandard", "indexDefault",
; "indexInstPin", "indexPin", "indexSheet", "border"

printf("schRMB.il loaded\n")
