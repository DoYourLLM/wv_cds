; load_wv_cds.il - load every wv_cds skill file
;
; Add ONE line to the .cdsinit in the directory you start Virtuoso from
; (install.sh prints it with the real path already filled in):
;
;   load("/path/to/wv_cds/skill/load_wv_cds.il")
;
; The base line below is filled in by install.sh, which writes this
; package's real location into it. If WV_CDS_HOME is exported it wins
; anyway, because wv_cds_config.il reads the environment first.

let((base)
  base = "@WV_CDS_SKILL_DIR@"
  load(strcat(base "/wv_cds_config.il"))
  load(strcat(base "/wv_cds_ipc.il"))
  load(strcat(base "/wv_cds_signal.il"))
  load(strcat(base "/wv_cds_probe.il"))
  load(strcat(base "/wv_cds_skill_server.il"))
  load(strcat(base "/wv_cds_table.il"))
  load(strcat(base "/wv_cds_menu.il"))
  load(strcat(base "/schRMB.il"))
  printf("wv_cds loaded: banner Example > wvcds, RMB net menu > Send to WV (Direct) / Send to WV_CDS (Interactive)\n"))
