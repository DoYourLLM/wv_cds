; wv_cds_menu.il - "Example" menu in the schematic banner:
;   wvcds       -> open the form window (Add / Remove)
;   Send to GUI -> push the current selection straight to the Python GUI
;
; Mechanism verified on the user's machine: postInstallTrigger receives
; the window in its args, and the pulldown menu is inserted into the
; window banner with hiInsertBannerMenu.

; push the current schematic selection straight to the Python GUI
; (no form window; wvCdsSendToGui warns when nothing is selected)
procedure(wvCdsSendSelectionToGui()
  let((signals)
    sch_win = hiGetCurrentWindow()
    signals = CCSwvPlotSelectedSignals(sch_win)
    wvCdsSendToGui(signals)))

; push the current schematic selection straight to wv, skipping the
; Python GUI middle layer (wvCdsSendToWv brings wv up, optionally opens
; WV_CDS_FSDB, and then plots every selected net through the wv RPC server
; on 61888).
;
; Afterwards the same window gets the net probes: wvCdsDisplayedNames asks wv
; what it is still showing (the whole batch, not just this click's nets, and
; minus anything you deleted in wv), and every one of those names is probed.
; wvCdsDisplayedNames returns nil when wv did not answer, and then the probes
; are deliberately left alone instead of being cleared.
procedure(wvCdsSendSelectionDirect()
  let((signals names)
    sch_win = hiGetCurrentWindow()
    signals = CCSwvPlotSelectedSignals(sch_win)
    wvCdsSendToWv(signals)
    names = wvCdsDisplayedNames()
    if(names
      then
        wvCdsProbeNames(sch_win cdr(names))
      else
        warn("wvCds: wv did not answer - probes left as they were\n"))))

procedure(wvCdsBuildPulldownMenu()
  sch_win=hiGetCurrentWindow()
  hiCreatePulldownMenu('wvCdsPulldownMenu "Example"
    list(
      hiCreateMenuItem(?name 'wvCdsOpen ?itemText "wvcds"
        ?callback "wvCdsOpenForm()")
      hiCreateMenuItem(?name 'wvCdsSendGui ?itemText "Send to GUI"
        ?callback "wvCdsSendSelectionToGui()"))))

procedure(wvCdsMenuInstall(args)
  if(!rexMatchList("wvCdsPulldownMenu" hiGetBannerMenus(args->window))
    then
      hiInsertBannerMenu(
        args->window
        if(!boundp('wvCdsPulldownMenu) wvCdsBuildPulldownMenu() wvCdsPulldownMenu)
        length(hiGetBannerMenus(args->window)))))

; attach the menu to schematic windows (postInstallTrigger fires after
; the window is installed; args->window is the new window).
; deGetAppInfo returns nil for view types this build does not have, and
; userPostInstallTrigList avoids the duplicate-registration warning on reload
foreach(vt list("schematic" "schematicXL")
  let((appInfo)
    when(appInfo = deGetAppInfo(vt)
      unless(member('wvCdsMenuInstall appInfo->userPostInstallTrigList)
        deRegUserTriggers(vt nil nil 'wvCdsMenuInstall)))))

printf("wv_cds_menu.il loaded\n")
