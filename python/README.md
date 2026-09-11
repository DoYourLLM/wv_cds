# python/ - the wv_cds table window

A small Tkinter table of net names. Nets arrive over TCP from Virtuoso; press
**Send to WV** to plot them in wv. See [../README.md](../README.md) for the
package-wide setup.

## Files

| File | What it is |
|---|---|
| `wv_cds_gui.py` | the window: table, buttons, TCP add-listener, send-to-wv worker |
| `wv_cds_config.py` | configuration; paths are resolved from the file's own location |
| `test_add_client.py` | tiny client that pushes names into the listener |

## Requirements

Python 3 (3.5 or newer) and Tkinter - on Debian/Ubuntu:

    sudo apt install python3-tk

Nothing else; only the standard library is used.

## Running

You normally never start it by hand: the first `Send to WV_CDS` starts it in
the background, in a detached process. To run it yourself:

    python3 wv_cds_gui.py

Starting it yourself is fine - the auto-start probes the port first and reuses
a running instance instead of launching a second one.

## Configuration

`wv_cds_config.py`:

- `WV_CDS_SH_DIR` - the package root, resolved from this file's own location;
  the `WV_CDS_HOME` environment variable overrides it. The Config box plus
  Save rewrites this line.
- `WV_CDS_LISTEN_PORT` - the add-listener, default 61889. It must not be 61888,
  which is wv's own RPC port.
- `WV_CDS_SKILL_CONFIG` - where the SKILL config sits, relative to `python/`.

There is deliberately no waveform-file setting: wv is started separately and
the file is opened inside wv, so plotting resolves against whatever file that
wv has open. `wv_cds_plot.sh` also skips signals wv is already displaying.

## Using it

1. Select nets in the schematic, right-click, choose **Send to WV_CDS** - they
   appear in the table with their hierarchy path
2. Or type a name into the entry box and press **Add**
3. Select rows and press **Remove** to drop them
4. Press **Send to WV** to plot every row in wv. This first runs
   `start_wv.sh -b` from the sh dir, so wv is started (or reused) and the RPC
   port is up before anything is plotted - the first press therefore works
   rather than failing with `Connection refused`. wv is started without a
   waveform file; open the file inside wv, and `wv_cds_plot.sh` will resolve
   against whatever is open there.
5. The log area at the bottom shows what wv replied

Rows can also be pushed from any other process:

    python3 test_add_client.py I0.I1.net1 net2

The line protocol is one message per line: `add <name>`, or a bare `<name>`.

## Notes

- `Send to WV` needs wv running with the RPC server; the SKILL side normally
  starts it for you.
- Only the Tk main thread touches the widgets. The listener and the shell
  calls hand work back through a queue drained with `after()`.
