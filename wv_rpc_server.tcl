# ============================================================================
# wv_rpc_server.tcl — start a TCP RPC server inside a running wv
# (Synopsys Custom WaveView / CustomExplorer) Tcl interpreter, so external
# processes (Linux terminal, Python scripts, AI agents) can execute Tcl
# commands inside wv in real time and receive the results.
#
# Self-contained: does NOT require etc/tcl_socket.tcl to be loaded.
# Wire-compatible with the plain-line protocol of etc/tcl_socket.tcl
# (RPC:/RDO:), and adds a length-prefixed framed protocol (RPC2:/RDO2:)
# that handles multi-line results and distinguishes errors.
#
# Protocol (plain — identical to etc/tcl_socket.tcl):
#   client -> server:  RPC:<tcl command>\n
#   server -> client:  <result>\n          (result must be a single line;
#                                           error message is returned as text)
#   client -> server:  RDO:<tcl command>\n  (fire-and-forget, no reply)
#
# Protocol (framed — use wv_rpc.py default mode):
#   client -> server:  RPC2:<nbytes>\n<tcl command, nbytes utf-8 bytes>
#   server -> client:  OK:<nbytes>\n<result>      on success
#   server -> client:  ERR:<nbytes>\n<error msg>  on command error
#   client -> server:  RDO2:<nbytes>\n<tcl command>  (fire-and-forget)
#
# Usage inside wv (Tcl console) or in a wv startup script:
#   source /path/to/wv_rpc_server.tcl      ;# auto-start on default port 61888
#   ::wv::rpc::start 61888                 ;# manual start on a fixed port
#   ::wv::rpc::start 0                     ;# OS-assigned port (written to
#                                          ;#  $::wv::rpc::portFile)
#   ::wv::rpc::stop                        ;# stop the listener
#
# Config (set BEFORE ::wv::rpc::start):
#   set ::wv::rpc::autoStart  0            ;# don't auto-start on source
#   set ::wv::rpc::bindAddr   "127.0.0.1"  ;# listen address (default loopback)
#   set ::wv::rpc::portFile   "/tmp/wv_rpc_port"
# ============================================================================

namespace eval ::wv::rpc {
    variable listener {}          ;# listening socket channel (or {})
    variable connState [dict create]   ;# sock -> {buf state mode nbytes}
    variable bindAddr "127.0.0.1"
    variable portFile "/tmp/wv_rpc_port"
    variable defaultPort 61888
    variable autoStart 1
    variable maxFrame 10485760    ;# 10 MB per framed request, sanity guard
}

# ----------------------------------------------------------------------------
# exec — run one command in wv's main interpreter and (optionally) reply.
#   sock       connection channel
#   cmd        Tcl command string (already decoded from utf-8)
#   wantReply  0/1
#   mode       "plain" (one-line result) or "framed" (OK/ERR + byte count)
# ----------------------------------------------------------------------------
proc ::wv::rpc::exec {sock cmd wantReply mode} {
    set code [catch {uplevel #0 $cmd} res]
    if {!$wantReply} { return }
    set out [encoding convertto utf-8 $res]
    if {[catch {
        if {$mode eq "framed"} {
            set tag [expr {$code ? "ERR" : "OK"}]
            puts $sock "$tag:[string length $out]"
            puts -nonewline $sock $out
        } else {
            # plain mode: one line, exactly like etc/tcl_socket.tcl's doService
            puts $sock $out
        }
        flush $sock
    } e]} {
        ::wv::rpc::drop $sock
    }
}

# ----------------------------------------------------------------------------
# connection lifecycle
# ----------------------------------------------------------------------------
proc ::wv::rpc::accept {sock addr port} {
    variable connState
    # raw bytes: every Tcl string char == one byte, so byte counts and
    # [string length] line up. Line/CRLF handling is done manually in pump.
    fconfigure $sock -blocking 0 -buffering none -translation binary
    dict set connState $sock state hdr
    dict set connState $sock buf ""
    dict set connState $sock mode ""
    dict set connState $sock nbytes 0
    fileevent $sock readable [list ::wv::rpc::readable $sock]
}

proc ::wv::rpc::readable {sock} {
    variable connState
    if {![dict exists $connState $sock]} { return }
    set data [read $sock]
    if {$data eq ""} {
        if {[eof $sock]} { ::wv::rpc::drop $sock }
        return
    }
    dict set connState $sock buf "[dict get $connState $sock buf]$data"
    ::wv::rpc::pump $sock
}

proc ::wv::rpc::drop {sock} {
    variable connState
    fileevent $sock readable {}
    catch {dict unset connState $sock}
    catch {close $sock}
}

# ----------------------------------------------------------------------------
# pump — incremental frame parser. Fully event-driven (never blocks), so the
# wv GUI event loop keeps running no matter what a client sends.
# ----------------------------------------------------------------------------
proc ::wv::rpc::pump {sock} {
    variable connState
    variable maxFrame
    while 1 {
        if {![dict exists $connState $sock]} { return }
        set st [dict get $connState $sock state]
        set buf [dict get $connState $sock buf]
        if {$st eq "hdr"} {
            set idx [string first "\n" $buf]
            if {$idx < 0} { return }
            set hdr [string trimright [string range $buf 0 [expr {$idx - 1}]] "\r"]
            dict set connState $sock buf [string range $buf [expr {$idx + 1}] end]
            if {[string match "RPC:*" $hdr]} {
                ::wv::rpc::exec $sock \
                    [encoding convertfrom utf-8 [string range $hdr 4 end]] 1 plain
            } elseif {[string match "RDO:*" $hdr]} {
                ::wv::rpc::exec $sock \
                    [encoding convertfrom utf-8 [string range $hdr 4 end]] 0 plain
            } elseif {[string match "RPC2:*" $hdr]} {
                set n [string range $hdr 5 end]
                if {![string is integer -strict $n] || $n < 0 || $n > $maxFrame} {
                    ::wv::rpc::drop $sock; return
                }
                dict set connState $sock state body
                dict set connState $sock mode rpc2
                dict set connState $sock nbytes $n
            } elseif {[string match "RDO2:*" $hdr]} {
                set n [string range $hdr 5 end]
                if {![string is integer -strict $n] || $n < 0 || $n > $maxFrame} {
                    ::wv::rpc::drop $sock; return
                }
                dict set connState $sock state body
                dict set connState $sock mode rdo2
                dict set connState $sock nbytes $n
            } else {
                ::wv::rpc::drop $sock
                return
            }
        } else {
            set n [dict get $connState $sock nbytes]
            if {[string length $buf] < $n} { return }
            set body [string range $buf 0 [expr {$n - 1}]]
            dict set connState $sock buf [string range $buf $n end]
            set mode [dict get $connState $sock mode]
            dict set connState $sock state hdr
            ::wv::rpc::exec $sock \
                [encoding convertfrom utf-8 $body] [expr {$mode eq "rpc2"}] framed
        }
    }
}

# ----------------------------------------------------------------------------
# start / stop
# ----------------------------------------------------------------------------
proc ::wv::rpc::start {{port ""}} {
    variable listener
    variable bindAddr
    variable portFile
    variable defaultPort
    if {$listener ne ""} {
        set p [lindex [fconfigure $listener -sockname] 2]
        puts "wv RPC server already listening on $p"
        return $p
    }
    if {$port eq ""} { set port $defaultPort }
    if {[catch {
        socket -server ::wv::rpc::accept -myaddr $bindAddr $port
    } listener]} {
        error "wv::rpc::start: cannot listen on $bindAddr:$port — $listener"
    }
    set p [lindex [fconfigure $listener -sockname] 2]
    if {[catch {
        set fd [open $portFile w]
        puts $fd $p
        close $fd
    } e]} {
        puts "warning: cannot write port file $portFile: $e"
    }
    puts "wv RPC server listening on $bindAddr:$p (port file: $portFile)"
    return $p
}

proc ::wv::rpc::stop {} {
    variable listener
    variable portFile
    if {$listener ne ""} {
        catch {close $listener}
        set listener ""
        puts "wv RPC server stopped"
    }
    catch {file delete $portFile}
}

# ----------------------------------------------------------------------------
# auto-start on source (safe: failures are reported, never fatal to wv)
# ----------------------------------------------------------------------------
if {$::wv::rpc::autoStart} {
    if {[catch {::wv::rpc::start $::wv::rpc::defaultPort} e]} {
        puts stderr "wv RPC server NOT started: $e"
    }
}
