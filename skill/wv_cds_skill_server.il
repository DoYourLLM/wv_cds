; wv_cds_skill_server.il - let an outside process send SKILL to Virtuoso
;
; Ported from Cadence's own example, "How to send a SKILL command to Virtuoso
; via a TCP/IP socket" (Troubleshooting Article 2561). The listener below is
; that file's abSkillServerListener, kept as it is - it is Cadence's code and
; it is already exercised in the field.
;
; Only the launch line differs from the original:
;   * it runs python/wv_cds_skill_server.py from this package BY ABSOLUTE PATH
;     (the original needs "skillServer" to be executable and on $PATH),
;   * so no tclsh is needed - the package already requires python3,
;   * and the port comes from WV_CDS_SKILL_PORT, so there is one source of
;     truth instead of an environment variable on the side.
;
; The protocol, and the security warning that matters here, are documented at
; the top of python/wv_cds_skill_server.py. Short version: anything that
; reaches this port is executed as SKILL in this session with no
; authentication, so the server binds 127.0.0.1 only.
;
; Checked against the IC23.1 SKILL Language Reference:
;   when(   g_condition g_expr1 ... )   - a sequence, so several bodies is fine
;   unless( g_condition g_expr1 ... )   - likewise
;   cond(   l_clause1 ... )             - variadic clauses
;   (an earlier note in this package blamed a bug on when/unless taking only
;    one body expression; that came from the OCEAN reference's abbreviated
;    signature and was wrong - the real cause was a stray paren in a cond
;    clause.)
;
; Verified with:
;   check_new_functions.py wv_cds_skill_server.il --strict \
;     --allow wvCdsPython,wvCdsProbeNames,abSkillServerConnection

abSkillServerDebug = nil

procedure(abSkillServerConnection(addr port)
  printf("wvCds: skill server connection from %s, port %s\n" addr port))

; Every line the Python server prints arrives here and is evaluated as SKILL.
; It prefixes each line with the channel id so the reply can be routed back to
; the right client - see the Python file for the format.
procedure(abSkillServerListener(ipcId data)
  let((channel command result)
    ; split lines: buffering can deliver several messages at once
    foreach(line parseString(data "\n")
      rexCompile("^\\([^ ]*\\) \\(.*\\)$")
      channel = rexReplace(line "\\1" 1)
      command = rexReplace(line "\\2" 1)
      when(abSkillServerDebug
        printf("COMMAND: %L\n" command))
      unless(errset(result = evalstring(command))
        when(abSkillServerDebug
          printf("ERROR: %L\n" errset.errset))
        ipcWriteProcess(ipcId sprintf(nil "%s ERROR %L\n"
                                      channel errset.errset)))
      when(abSkillServerDebug
        printf("RESULT: %L\n" result))
      ipcWriteProcess(ipcId sprintf(nil "%s %L\n" channel result)))))

unless(boundp('wvCdsSkillServerId) wvCdsSkillServerId = nil)

; Start the server once. Loading this file twice, or re-running load(), must
; not spawn a second one: it could not bind the port, and the first one's child
; id would be dropped.
;
; Returns the child id, or nil when the feature is switched off in
; skill/wv_cds_config.il.
procedure(wvCdsSkillServerStart()
  let((cmd)
    when(WV_CDS_SKILL_SERVER
      when(wvCdsSkillServerId
        unless(ipcIsAliveProcess(wvCdsSkillServerId)
          wvCdsSkillServerId = nil))
      unless(wvCdsSkillServerId
        ; %s, not %d: WV_CDS_SKILL_PORT is a string like the other ports in
        ; wv_cds_config.il (they end up inside shell command lines), and
        ; sprintf with %d on a string is a hard error, not a coercion.
        cmd = sprintf(nil "%s %s/python/wv_cds_skill_server.py --port %s"
                        wvCdsPython() WV_CDS_SH_DIR WV_CDS_SKILL_PORT)
        wvCdsSkillServerId = ipcBeginProcess(cmd "" 'abSkillServerListener)
        printf("wvCds: skill server listening on 127.0.0.1:%s\n"
               WV_CDS_SKILL_PORT)))
    wvCdsSkillServerId))

wvCdsSkillServerStart()

printf("wv_cds_skill_server.il loaded\n")
