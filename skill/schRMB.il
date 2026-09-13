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
; window, and both calls act on all instances of a menu, so a shared menu
; would otherwise end up with the items twice. The delete answers with a
; warning while the item is not there yet, which is the first time each
; category menu is extended; muffleWarnings in wvCdsRmbAddItem is what keeps
; that out of the CIW.
;
; hiGetMenuItems cannot be used to ask first: its reference says it takes a
; menu built by hiCreateMenu, hiCreatePulldownMenu, hiCreateHorizontalFixedMenu
; or hiCreateVerticalFixedMenu and returns nil for anything else, which an
; object-sensitive menu is.
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
;
; Two arity warnings are known false positives of the signature extraction:
;   muffleWarnings  "needs at least 2" - g_expr1 ... is variadic, and one
;                   expression is what progn( g_expr1 ... ) takes too
;   mbRegisterAction "10 of 9" - the escaped quotes inside the printf string
;                   of the Navigator test line split it into extra arguments

; delete-then-insert one item at the top of popMenu; idempotent
;
; The delete is what makes this idempotent: the post-install trigger fires
; once per schematic window, the same menu structure can be reached from more
; than one window, and hiDeleteMenuItem/hiInsertMenuItem act on all instances
; of a menu, so without it a second firing would leave two "Send to WV" lines.
;
; The first time each category menu is extended there is nothing to delete yet,
; and hiDeleteMenuItem answers
;   *WARNING* hiDeleteMenuItem: can't find this item in the menu <name>
; which, with the items registered on five categories, was ten lines in the
; CIW on the first right-click.
;
; muffleWarnings is what silences it. NOT errset: errset controls the printing
; of ERROR messages (and its g_errprint argument already defaults to nil), while
; this message is a warning - the reference for muffleWarnings says it drops the
; output of warn and of C level ilWarn* calls, which is what this one is. The
; delete itself stays unconditional, so a menu that cannot be inspected is
; still cleaned up rather than doubled.
procedure(wvCdsRmbAddItem(popMenu itemName itemText callback)
  muffleWarnings(errset(hiDeleteMenuItem(popMenu itemName)))
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
