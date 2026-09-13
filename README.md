**English** | [中文](README.zh-CN.md)

# wv_cds — send schematic nets to wv (Custom WaveView)

Right-click a net in a Virtuoso schematic to plot it in wv:

| Right-click item | What it does |
|---|---|
| **Send to WV (Direct)** | plots straight in wv, then probes those nets in the schematic |
| **Send to WV_CDS (Interactive)** | puts the net in a small Python table; you plot from there when you are ready, and the schematic probes update too |

The items sit at the top of the net menu. **Shift-click to select several nets
at once** - one net or n, they are all sent together:

| One net | Several nets (Shift-click) |
|---|---|
| ![The Wire menu: Send to WV (Direct) and Send to WV_CDS (Interactive) at the top](images/wv-cds-rmb-wire.png) | ![The Multiple menu: the same two items at the top](images/wv-cds-rmb-multiple.png) |

Both items start whatever they need - you do not have to launch wv, source
`wv_rpc_server.tcl`, or start the Python GUI by hand.

## Requirements

- Linux, Virtuoso with the schematic editor
- `wv` (Synopsys Custom WaveView), startable as `wv -ace_gui <script>`
- Python 3 with Tkinter, for `Send to WV_CDS (Interactive)` only (`sudo apt install python3-tk`)

## Setup

**1. Get the package, then run the installer once**

```bash
git clone https://github.com/DoYourLLM/wv_cds.git
cd wv_cds
./install.sh
```

**2. Add one line to the `.cdsinit` in the directory you start Virtuoso from**

```skill
load("/where/you/put/wv_cds/skill/load_wv_cds.il")
```

**3. Start Virtuoso, open a schematic, right-click a net**

Select the net(s) first - multi-select and descend-into-subcell both work. The
two items are at the top of the menu. After loading, the CIW prints
`wv_cds loaded: ...`.

**4. In wv, open your fsdb**

The first click starts wv for you, but wv comes up with no waveform file open,
and signal names cannot be resolved until one is. Open your fsdb in wv, then
click the net again - from then on plots resolve against that file.

## The Send to WV_CDS (Interactive) flow

![Right-click a net and pick Send to WV_CDS (Interactive); the net lands in the GUI table; press Send to WV there](images/wv-cds-send-to-wv-cds.png)

1. Right-click the net and pick **Send to WV_CDS (Interactive)**.
2. The net shows up in the table at the top of the **WV_CDS Python GUI**.
3. Select the rows you want and press **Send to WV** to plot them in wv.

## Starting wv yourself (optional)

Both right-click items start wv when they need it, so this is only for bringing
wv up before you touch Virtuoso:

```bash
./start_wv.sh        # foreground
./start_wv.sh -b     # background; returns once the RPC port answers
./start_wv.sh -h     # help
```

It runs the same command the right-click items use -
`wv -ace_gui <package>/wv_rpc_server.tcl` - so the RPC server comes up on 61888
and Virtuoso can talk to this wv.

To have the direct path open a fixed file for you instead of opening it by hand
(step 4), set `WV_CDS_FSDB` in `skill/wv_cds_config.il`.

## How it works

```
right-click a net --> CCSwvPlotSelectedSignals
  |-- Send to WV (Direct) --> wv_cds_openfsdb.sh   (only when WV_CDS_FSDB is set)
  |                           wv_cds_plot.sh  --> 127.0.0.1:61888  (wv's RPC server)
  +-- Send to WV_CDS (Interactive) ------> wv_cds_add.sh   --> 127.0.0.1:61889  (Python GUI)
                              Send to WV in the GUI --> wv_cds_plot.sh --> 61888
```

61888 is wv's own RPC server and 61889 is the Python GUI's listener; they are
separate ports because two servers cannot share one.

## Files

| Path | What it is |
|---|---|
| `install.sh` | one-time setup; run it first |
| `start_wv.sh` | start wv by hand, with the RPC server loaded (optional) |
| `skill/wv_cds_config.il` | **the only file you normally edit** |
| `skill/load_wv_cds.il` | loads the rest; this is what `.cdsinit` calls |
| `python/wv_cds_gui.py` | the table window |
| `wv_cds_*.sh` | the scripts that talk to wv over the RPC port |
| `wv_rpc_server.tcl` | the RPC server that runs inside wv |

`skill/README.md` and `python/README.md` cover those two halves.

## Notes

- **A signal is displayed once.** `wv_cds_plot.sh` asks wv itself, by probing the
  line object it kept, so a curve you deleted in wv is plotted again.
- **Both menu items probe, and the Direct one clears every probe in the window
  first - probes you placed by hand included.** That is what makes a net removed
  from wv lose its probe. If wv does not answer, nothing is touched.
- **`Send to WV_CDS (Interactive)` probes in a different order:** the GUI plots,
  then asks Virtuoso to probe, through a small local server
  (`python/wv_cds_skill_server.py`). **Anyone who can reach that port can run
  SKILL in your session**, so it binds `127.0.0.1` only; set
  `WV_CDS_SKILL_SERVER = nil` to switch it off.
- **A device terminal gives a current, not a voltage.** It is named
  `<hier>.<inst>:*` with two terminals and `<hier>.<inst>:<n>` with three or
  more, and it is probed at its terminal, `/I0/R2/PLUS` - a terminal probe, so
  `geDeleteAllProbe` removes it like any other probe and it does not follow you
  into another level.
- wv takes a while to start: the first `Send to WV (Direct)` click usually only
  starts it, so click again.
- The GUI's `sh dir` box has to point at this package, or **Send to WV** does
  nothing.
- Keep net names to ordinary characters - avoid `"`, `$`, backticks, `\`, `{`,
  `}`, `[`, `]` and whitespace: they are pasted into a Tcl command.
- A net on a pin of the current cellview is the port net, named one level up:
  `I0.I1.n1` becomes `I0.n1`.
- No machine specific path except the three `install.sh` fills in, and the code
  is ASCII apart from em dashes in comments.
