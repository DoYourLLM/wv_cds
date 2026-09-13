# python/ — the wv_cds table window

A small Tkinter table of net names. Nets arrive over TCP from Virtuoso; press
**Send to WV** to plot them in wv. Package-wide setup:
[../README.md](../README.md).

| File | What it is |
|---|---|
| `wv_cds_gui.py` | the window: table, buttons, TCP add-listener, send-to-wv worker |
| `wv_cds_config.py` | configuration; paths are resolved from the file's own location |
| `wv_cds_names.py` | asks wv which signals it is still displaying (used by the schematic probes) |
| `wv_cds_skill_server.py` | port that hands SKILL to Virtuoso - **read its security note** |
| `test_add_client.py` | tiny client that pushes names into the listener |

Requires Python 3.5+ with Tkinter (`sudo apt install python3-tk`); standard
library only.

## Running

You normally never start it by hand - the first `Send to WV_CDS (Interactive)`
starts it in the background, detached. To run it yourself:

    python3 wv_cds_gui.py

The auto-start probes the port first and reuses a running instance rather than
launching a second one.

## Configuration

`wv_cds_config.py`:

- `WV_CDS_SH_DIR` - the package root, resolved from this file's own location;
  the `WV_CDS_HOME` environment variable overrides it. The Config box plus
  **Save** rewrites this line.
- `WV_CDS_LISTEN_PORT` - the add-listener, default 61889. It must not be 61888,
  which is wv's own RPC port.
- `WV_CDS_SKILL_CONFIG` - where the SKILL config sits, relative to `python/`.

There is no waveform-file setting here: the file is opened inside wv.

## Using it

1. Select nets in the schematic, right-click, choose **Send to WV_CDS
   (Interactive)** - they appear in the table with their hierarchy path
2. Or type a name into the entry box and press **Add**; select rows and press
   **Remove** to drop them
3. Press **Send to WV** to plot every row. It runs `start_wv.sh -b` from the sh
   dir first, so wv is up before anything is plotted.

Rows can also be pushed from any other process:

    python3 test_add_client.py I0.I1.net1 net2

One message per line: `add <name>`, or a bare `<name>`.
