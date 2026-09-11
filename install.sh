#!/bin/bash
#====================================================================
# Script Name: install.sh
# Function: One-time setup for the wv_cds package.
#
#   ./install.sh
#
# What it does
#   1. makes the wv_cds_*.sh scripts executable
#   2. writes this package's real location into the three files that need
#      an absolute path - the package ships with placeholders, so nothing
#      in the distributed copy is machine specific
#   3. checks the prerequisites
#   4. prints the one line to add to your startup directory's .cdsinit
#
# It is safe to re-run, and you should re-run it after moving the package.
#====================================================================
set -u

PKG=$(cd "$(dirname "$0")" && pwd) || exit 1
SKILL="$PKG/skill"

say()  { printf '%s\n' "$*"; }
ok()   { printf '  [ ok ]  %s\n' "$*"; }
warn() { printf '  [warn]  %s\n' "$*"; }

say "wv_cds install"
say "  package root: $PKG"
say ""

# ---------------------------------------------------------------------------
# 1. executable bits (archives and shared folders often lose them)
# ---------------------------------------------------------------------------
say "1. making the shell scripts executable"
for f in "$PKG"/*.sh; do
    [ -f "$f" ] || continue
    if chmod +x "$f" 2>/dev/null; then
        ok "$(basename "$f")"
    else
        warn "$(basename "$f") - chmod failed, the filesystem may not support it"
    fi
done
say ""

# ---------------------------------------------------------------------------
# 2. absolute paths
# ---------------------------------------------------------------------------
say "2. writing this package's location into its config files"

# rewrite the first line matching $2, escaping sed replacement specials
set_path() {
    file="$1"; pattern="$2"; replacement="$3"
    if [ ! -f "$file" ]; then
        warn "missing $file"
        return 1
    fi
    esc=$(printf '%s' "$replacement" | sed 's/[&|\\]/\\&/g')
    if sed -i "s|$pattern|$esc|" "$file" 2>/dev/null; then
        ok "$(basename "$file")"
    else
        warn "$(basename "$file") - could not rewrite it, edit it by hand"
    fi
}

set_path "$SKILL/wv_cds_config.il" '^WV_CDS_SH_DIR = ".*"$' "WV_CDS_SH_DIR = \"$PKG\""
set_path "$SKILL/load_wv_cds.il"   '^  base = ".*"$'        "  base = \"$SKILL\""
set_path "$SKILL/cdsinit.wv_cds"   '^load(".*load_wv_cds\.il")$' \
                                   "load(\"$SKILL/load_wv_cds.il\")"
say ""

# ---------------------------------------------------------------------------
# 3. prerequisites
# ---------------------------------------------------------------------------
say "3. prerequisites"
if command -v python3 >/dev/null 2>&1; then
    ok "python3: $(command -v python3)"
else
    warn "python3 not found - the Python GUI cannot start"
fi
if python3 -c 'import tkinter' >/dev/null 2>&1; then
    ok "tkinter available"
else
    warn "tkinter missing - try: sudo apt install python3-tk"
fi
if [ -n "${WV_HOME:-}" ] && [ -x "${WV_HOME}/bin/wv" ]; then
    ok "wv: $WV_HOME/bin/wv"
elif command -v wv >/dev/null 2>&1; then
    ok "wv: $(command -v wv)"
else
    warn "wv not found - set WV_CDS_WV_BIN in skill/wv_cds_config.il"
    warn "  (a shell alias is not visible to the launcher; use an absolute path)"
fi
if [ -f "$PKG/wv_rpc_server.tcl" ] && [ -f "$SKILL/schRMB.il" ]; then
    ok "package files present"
else
    warn "package looks incomplete - expected wv_rpc_server.tcl and skill/schRMB.il"
fi
say ""

# ---------------------------------------------------------------------------
# 4. what to do next
# ---------------------------------------------------------------------------
say "4. next step - add this line to the .cdsinit in the directory you"
say "   start Virtuoso from (create it if it is not there), or rename"
say "   skill/cdsinit.wv_cds to .cdsinit and drop it in that directory:"
say ""
say "       load(\"$SKILL/load_wv_cds.il\")"
say ""
say "   Nothing else is required. Plotting resolves against whatever"
say "   waveform file that wv has open, so open the file inside wv the way"
say "   you normally would."
say ""
say "   Optional - to have the direct path open one fixed file for you,"
say "   set this in"
say "       $SKILL/wv_cds_config.il"
say ""
say "       WV_CDS_FSDB = \"/path/to/your/simulation.fsdb\""
say ""
say "   Leave it empty (the default) for the normal workflow."
say ""
say "   Then start Virtuoso, open a schematic, right-click a net and pick"
say "   \"Send to WV (Direct)\" or \"Send to WV_CDS\"."
say ""
say "   Both items start wv for you, so normally you never launch it by"
say "   hand. If you would rather have wv up first, there is:"
say ""
say "       $PKG/start_wv.sh"
say ""
