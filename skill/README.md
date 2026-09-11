# skill/ - the Virtuoso side

This is the half that runs inside Virtuoso. Read the package-wide
[../README.md](../README.md) first; this file only covers the skill side.

## Loading

`load_wv_cds.il` loads, in order:

| File | What it does |
|---|---|
| `wv_cds_config.il` | configuration - the one file you edit |
| `wv_cds_ipc.il` | IPC bridge, plus the on-demand start of wv and of the Python GUI |
| `wv_cds_signal.il` | reads the schematic selection and builds the hierarchy path |
| `wv_cds_table.il` | Virtuoso form window with the net list (Add / Remove) |
| `wv_cds_menu.il` | banner menu `Example > wvcds`, and the selection wrappers |
| `schRMB.il` | the net right-click menu items |

`cdsinit.wv_cds` is a template. Virtuoso auto-loads a file named `cdsinit` or
`.cdsinit` from the startup directory - it does **not** pick this file up under
this name, so rename it or copy its single `load` line into your own
`~/.cdsinit`.

## Configuration

Only `wv_cds_config.il`. The points worth knowing:

- the package root is filled in by `install.sh`; the `WV_CDS_HOME` environment
  variable overrides it
- `WV_CDS_FSDB` ships empty, which is the normal setup: wv is started on its
  own and the waveform file is opened inside wv, so plotting uses whatever
  file is open there. Set it only if you want the direct path to open a fixed
  file for you
- `WV_CDS_WV_BIN` empty means `$WV_HOME/bin/wv` when `WV_HOME` is exported,
  otherwise plain `wv` found through `PATH`
- the two ports: `WV_CDS_RPC_PORT` (61888, wv's own RPC server) and
  `WV_CDS_GUI_PORT` (61889, the Python GUI's add-listener)

## Right-click menu

`schRMB.il` adds the two items to the object-sensitive menus of the `wire` and
`schMultiple` categories. The editor keeps a **separate menu per object
category**, so registering only `wire` would make the items disappear as soon
as two wires are under the cursor. Add more category names to the list inside
`CCSinsertPopUp` if you want them elsewhere; the accepted names are listed at
the bottom of that file.

## Signal names

`CCSwvPlotSelectedSignals` prefixes the instances returned by
`geGetInstHierPath`, which is what the fsdb uses. The one exception is a net
whose name is also a pin name of the current cellview: that net IS the port
net, so its signal lives one level up and the current level's instance segment
is left off - descended two levels, `I0.I1.n1` becomes `I0.n1`. Pin names come
from `schGetPinOrder(geGetEditCellView(win))`.

## Notes

- `schGetPopUpMenu` is not in the IC23.1 reference index; the documented pair
  `schRegisterPopUpMenu` / `schUnregisterPopUpMenu` *replaces* a category menu
  instead of extending it. The call is wrapped in `errset`, so on a build
  without it the trigger simply adds no items.
- Reading a SKILL global that was never assigned raises `unbound variable`, so
  the session-state flags are all declared at the top of `wv_cds_ipc.il`.
- Everything here is pure ASCII.
