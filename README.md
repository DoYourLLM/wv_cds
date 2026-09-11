# wv_cds — send schematic nets to wv (Custom WaveView)

Right-click a net in a Virtuoso schematic and plot it in wv. Two ways:

| Right-click item | What it does |
|---|---|
| **Send to WV (Direct)** | plots straight in wv, no middle layer |
| **Send to WV_CDS** | pushes the net into a small Python table window; you plot from there when you are ready |

Both items also start what they need — you do **not** have to launch wv, source
`wv_rpc_server.tcl`, or start the Python GUI by hand.

---

## Requirements

- Linux, Virtuoso with the schematic editor (SKILL)
- `wv` (Synopsys Custom WaveView) — it must be startable with
  `wv -ace_gui <script>` so the RPC server comes up inside it
- Python 3 with Tkinter — **only** needed for `Send to WV_CDS`
  (`sudo apt install python3-tk` on Debian/Ubuntu)
- A waveform file (fsdb) you want to look at

## Setup — 3 steps

**1. Unpack anywhere, then run the installer once**

```bash
tar xf wv_cds.tar.gz          # or unzip, or git clone
cd wv_cds
./install.sh
```

`install.sh` makes the scripts executable, writes this package's real
location into the three files that need an absolute path (the distributed
copy contains only placeholders, so nothing is machine specific), checks the
prerequisites, and prints the line for step 2. Re-run it if you ever move the
folder.

**2. Add one line to `~/.cdsinit`**

Use the line `install.sh` printed, which looks like:

```skill
load("/where/you/put/wv_cds/skill/load_wv_cds.il")
```

(Or rename `skill/cdsinit.wv_cds` to `cdsinit` and drop it in your project
directory — Virtuoso auto-loads a file with that name, not with this one.)

**3. Start Virtuoso, open a schematic, right-click a net**

Select the net(s) first (multi-select and descend-into-subcell both work),
then right-click on the net. The two items are at the top of the menu.

### The waveform file (optional)

Start wv - `./start_wv.sh` does it on its own, or the right-click items start
it for you - and open the waveform file there the way you normally would.
Plotting then resolves against whatever file that wv has open, so there is
nothing to configure here.

If you would rather have the tool open a fixed file for you, set it in
`skill/wv_cds_config.il` and the direct path opens exactly that file, once per
session, before plotting:

```skill
WV_CDS_FSDB = "/path/to/your/simulation.fsdb"
```

### Starting wv yourself (optional)

Both right-click items start wv when they need it, so this is only for when
you want wv up *before* you touch Virtuoso, or you want to watch its startup
output:

```bash
./start_wv.sh        # foreground; close wv (or Ctrl-C) to get the prompt back
./start_wv.sh -b     # background; waits for the RPC port, then returns
./start_wv.sh -h     # help, including the environment overrides
```

It runs the same command the right-click items use -
`wv -ace_gui <package>/wv_rpc_server.tcl` - so the RPC server comes up on
61888 and Virtuoso can talk to this wv straight away. If the port is already
answering, nothing is started, so running it twice is harmless.

---

## What you should see

After `load(...)`, the CIW prints seven lines ending with:

```
wv_cds loaded: banner Example > wvcds, RMB net menu > Send to WV (Direct) / Send to WV_CDS
```

On the first `Send to WV (Direct)` click:

```
wvCds: starting wv in the background - plots will work once it is up
wvCds: plot I0.n1 skipped - wv is not answering on the RPC port yet, it may still be starting; click again in a few seconds
...
wvCds: wv "started" - it is ready, click again to plot
```

wv takes a while to come up, so the *first* click starts it and the plot has
nothing to talk to yet - that is why the plot is skipped with an explanation
rather than dumped as a connection error. **Click again** once the ready line
appears; that one plots, and later clicks print
`wvCds: plot I0.n1 => ("1 new, 0 already plotted")`.

(If wv reports that it cannot resolve the signal, no waveform file is open in
it yet; open one there and click again.)

On the first `Send to WV_CDS` click:

```
wvCds: started the wv_cds GUI (/where/you/put/wv_cds/python/wv_cds_gui.py)
wvCds: push I0.n1 to GUI => ("sent")
```

then the net appears in the GUI table. Press **Send to WV** there to plot it -
that button starts wv for you if it is not up yet (it runs `start_wv.sh -b`
and waits for the RPC port), so the first press works instead of failing with
`Connection refused`. On later clicks the GUI is already listening, so nothing
is printed for it - only the push line.

### The Send to WV_CDS flow, in pictures

![Right-click a net and pick Send to WV_CDS; the net lands in the GUI table; press Send to WV there](images/wv-cds-send-to-wv-cds.png)

1. Right-click the net and pick **Send to WV_CDS** (the red box in the menu).
2. The net shows up in the table at the top of the **WV_CDS Python GUI** window.
3. Select the rows you want and press **Send to WV** to plot them in wv.

The log at the bottom of the GUI reports every step. In this shot it also shows
`start_wv.sh` saying `something is already listening on 61888` and then warning
that **2 wv processes** are running. Only one process can bind 61888, so that
second wv has no RPC server and never receives plots - the warning is the
feature working, not a failure.

(In this screenshot the `sh dir` box was deliberately left blank so that no
private path ends up in the picture. It must hold the package directory before
**Send to WV** will do anything - an empty box makes the button report
`set the sh dir first`, and **Save** refuses it too.)

**Closing either window is fine.** Both are started on demand, and the
launchers probe their port first, so a running process is reused and a closed
one is started again on the next click. There is no "already done this
session" latch to get stuck.

---

## How it works

```
right-click a net
  |
  |-- Send to WV (Direct) --> CCSwvPlotSelectedSignals --> wvCdsSendToWv
  |                                                          |
  |                                                          +-- start wv if the RPC port is dead
  |                                                          +-- wv_cds_openfsdb.sh  (only when WV_CDS_FSDB is set)
  |                                                          +-- wv_cds_plot.sh      (per net)
  |                                                                  -> 127.0.0.1:61888
  |
  +-- Send to WV_CDS ------> CCSwvPlotSelectedSignals --> wvCdsSendToGui
                                                             |
                                                             +-- start wv if needed
                                                             +-- start the Python GUI if needed
                                                             +-- wv_cds_add.sh  (per net)
                                                                     -> 127.0.0.1:61889

in the Python GUI:  Send to WV --> start_wv.sh -b (bring wv up, wait for the port)
                                     then wv_cds_plot.sh (per row) --> 127.0.0.1:61888
```

- **61888** is wv's own RPC server, started by `wv_rpc_server.tcl` inside wv.
  The shell scripts are clients of it.
- **61889** is the Python GUI's add-listener, a separate port because two
  servers cannot share one.

## Files

| Path | What it is |
|---|---|
| `install.sh` | one-time setup; run it first |
| `start_wv.sh` | start wv by hand, with the RPC server loaded (optional) |
| `skill/wv_cds_config.il` | **the only file you normally edit** |
| `skill/schRMB.il` | the net right-click menu items |
| `skill/wv_cds_ipc.il` | IPC bridge, and the on-demand starts of wv / the GUI |
| `skill/wv_cds_signal.il` | reads the schematic selection, builds the hierarchy path |
| `skill/wv_cds_menu.il` | banner menu `Example > wvcds` and the selection wrappers |
| `skill/wv_cds_table.il` | Virtuoso form window version of the net list |
| `skill/load_wv_cds.il` | loads all of the above (this is what `.cdsinit` calls) |
| `python/wv_cds_gui.py` | the table window |
| `python/wv_cds_config.py` | its config (paths are resolved from the file's own location) |
| `wv_cds_*.sh` | the scripts that talk to wv over the RPC port |
| `wv_rpc_server.tcl` | the RPC server that runs inside wv |
| `images/` | screenshots used by this README |
| `docs/` | development notes; safe to delete |

## Notes

- **A signal is displayed once.** `wv_cds_plot.sh` remembers the names it has
  already handed to wv, in a Tcl variable that lives *inside* wv
  (`::wv_cds_plotted`), so clicking the same net again does not stack a second
  identical curve. The memory belongs to that wv process: restart wv and
  everything is plotted again, and opening a file resets it. Both right-click
  items and the Python GUI share it, because they all go through the same
  script. The reply says what happened - `1 new, 2 already plotted`. This
  covers what the tool plotted; curves you added inside wv by hand are not
  tracked.
- Net names are wrapped in double quotes when handed to the shell, so avoid
  names containing `"`, `$` or backticks.
- A net that sits on a pin of the current cellview is the port net, and its
  signal is named one level up: descended two levels, `I0.I1.n1` becomes
  `I0.n1`.
- Everything is ASCII, and no file in this package contains a machine
  specific path except the three that `install.sh` fills in.
