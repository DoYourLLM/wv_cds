# wv_cds_config.py - configuration for the Python wv_cds GUI.
#
# Nothing here is machine specific: the package root is resolved from this
# file's own location, so the same copy works wherever you unpack it. The
# WV_CDS_HOME environment variable, when exported, overrides it.
#
# There is no waveform-file setting. wv is started on its own and the file is
# opened inside wv, so plotting uses whatever file is open there.

import os
import re

# This file lives in <package>/python/, so the package root is its parent.
_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_HERE)

# Directory holding the wv_cds_*.sh scripts (the package root). The GUI's
# Save button rewrites this line with whatever is in the Config box; the
# environment override just below still wins.
WV_CDS_SH_DIR = _ROOT

if os.environ.get("WV_CDS_HOME"):
    WV_CDS_SH_DIR = os.environ["WV_CDS_HOME"]

# ---------------------------------------------------------------------------
# External "add" listener.
#
# The GUI listens here for external processes that push net names in with
# one line per message:  "add <name>"  (or a bare "<name>").
#
# NOTE: this must NOT be 61888. That is the port wv's own RPC server
# (wv_rpc_server.tcl) listens on, and the wv_cds_*.sh scripts connect to
# 61888 as CLIENTS. Two servers cannot bind the same port, so the GUI's
# add-listener uses a separate port.
# ---------------------------------------------------------------------------
WV_CDS_LISTEN_HOST = "127.0.0.1"
WV_CDS_LISTEN_PORT = 61889

# wv's RPC server (what the .sh scripts talk to). Kept here for
# documentation only - the .sh scripts hard-code 127.0.0.1:61888.
WV_CDS_RPC_HOST = "127.0.0.1"
WV_CDS_RPC_PORT = 61888

# ---------------------------------------------------------------------------
# SKILL server - how the GUI talks BACK to Virtuoso.
#
# "Send to WV" plots into wv, but the net probes have to be created inside
# Virtuoso (geAddNetProbe). Virtuoso cannot be called from outside, so it runs
# a small server (skill/wv_cds_skill_server.il + python/wv_cds_skill_server.py)
# and the GUI sends it the SKILL command wvCdsProbeFromGui().
#
# Must match WV_CDS_SKILL_PORT in skill/wv_cds_config.il. Cadence's example
# uses 8123. When nothing is listening, the GUI just logs it and carries on.
# ---------------------------------------------------------------------------
WV_CDS_SKILL_HOST = "127.0.0.1"
WV_CDS_SKILL_PORT = 8123

# Poll interval (ms) for draining the add-queue into the table.
WV_CDS_POLL_MS = 100

# Path to the SKILL-side config, relative to this python/ directory. The
# GUI's "Save" button writes the same sh-dir value here too, so Virtuoso and
# the GUI stay in sync. Override with an absolute path if the two sides are
# not deployed side by side.
WV_CDS_SKILL_CONFIG = "../skill/wv_cds_config.il"


# ---------------------------------------------------------------------------
# Persistence helpers (used by the GUI's "Save" button).
# ---------------------------------------------------------------------------
def config_path():
    """Absolute path to this config file."""
    return os.path.abspath(__file__)


def save_config(sh_dir):
    """Write sh_dir back into this file and update the in-memory value."""
    global WV_CDS_SH_DIR
    path = config_path()
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    text = re.sub(r"(?m)^WV_CDS_SH_DIR\s*=.*$",
                  "WV_CDS_SH_DIR = %s" % repr(sh_dir), text, count=1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    WV_CDS_SH_DIR = sh_dir


def skill_config_path():
    """Absolute path to the SKILL config file (<package>/skill/wv_cds_config.il)."""
    return os.path.abspath(
        os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     WV_CDS_SKILL_CONFIG))


def _skill_string(value):
    """Quote a value as a SKILL double-quoted string."""
    return '"%s"' % value.replace("\\", "\\\\").replace('"', '\\"')


def save_skill_config(sh_dir):
    """Write sh_dir into the SKILL config (<package>/skill/wv_cds_config.il).

    Returns the path written, or raises OSError/IOError if it is missing.
    """
    path = skill_config_path()
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    text = re.sub(r"(?m)^WV_CDS_SH_DIR\s*=.*$",
                  "WV_CDS_SH_DIR = %s" % _skill_string(sh_dir), text, count=1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    return path
