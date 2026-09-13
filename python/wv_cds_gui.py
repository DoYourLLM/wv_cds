#!/usr/bin/env python3
"""wv_cds_gui.py - Python/Tkinter replacement for the SKILL wv_cds_table form.

A table window that holds a list of net names ("signals") and mirrors the
flow of the original SKILL form window (wv_cds_table.il):

  * rows are ADDED by an external signal source - a TCP client sends one
    line per message ("add <name>", or a bare "<name>") to the listener;
  * rows can also be ADDED manually from the entry box + Add button;
  * rows are REMOVED with the Remove button (uses the table selection);
  * "Send to WV" plots every name in wv (Custom WaveView) over the plain
    RPC: protocol to 127.0.0.1:61888.

There is no waveform-file setting here on purpose. wv is started separately
(start_wv.sh, or automatically by the right-click items) and the file is
opened inside wv, so plotting resolves against whatever file is open there.
wv_cds_plot.sh additionally skips signals that wv is already displaying.

The sh dir is the one thing in the Config panel; "Save" writes it back to
wv_cds_config.py (and into the SKILL config), and the current value is always
used for sending.

Threading model:
  * only the Tk main thread mutates the Treeview / log widgets;
  * the TCP listener and the .sh subprocess calls run in worker threads
    and hand work back to Tk through a thread-safe queue drained with
    root.after().

Requires only the Python standard library. Tkinter must be installed
(on Debian/Ubuntu:  sudo apt install python3-tk).

Targets Linux (the .sh scripts use bash's /dev/tcp and live on the Linux
side).
"""

import os
import queue
import re
import socket
import subprocess
import threading
import tkinter as tk
from tkinter import ttk

import wv_cds_config as cfg


class SignalTableApp:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("WV_CDS Python GUI")
        self.root.geometry("500x540")

        # thread-safe hand-off from worker threads to the Tk main thread
        self.events = queue.Queue()
        self._stop = threading.Event()

        # config value (editable in the UI, pre-filled from wv_cds_config).
        # There is no fsdb setting: wv is started separately and the waveform
        # file is opened in wv itself, so plotting uses whatever file is open.
        self.sh_dir_var = tk.StringVar(value=cfg.WV_CDS_SH_DIR)

        self._build_ui()
        self._start_listener()
        self.root.protocol("WM_DELETE_WINDOW", self._on_close)
        self.root.after(cfg.WV_CDS_POLL_MS, self._drain_events)

    # ------------------------------------------------------------------ UI
    def _build_ui(self):
        top = ttk.Frame(self.root, padding=8)
        top.pack(fill="both", expand=True)

        # --- config (the directory holding the wv_cds_*.sh scripts)
        cfgf = ttk.LabelFrame(top, text="Config", padding=4)
        cfgf.pack(fill="x", pady=(0, 8))
        cfgf.columnconfigure(1, weight=1)
        ttk.Label(cfgf, text="sh dir:").grid(row=0, column=0, sticky="w",
                                             padx=(0, 4), pady=2)
        sh_entry = ttk.Entry(cfgf, textvariable=self.sh_dir_var)
        sh_entry.grid(row=0, column=1, sticky="ew", pady=2)
        self._bind_edit(sh_entry)
        ttk.Button(cfgf, text="Save", command=self.save_config).grid(
            row=0, column=2, padx=(6, 0), pady=2)

        # --- table (Treeview) + scrollbar
        tbl = ttk.Frame(top)
        tbl.pack(fill="both", expand=True)

        self.tree = ttk.Treeview(tbl, columns=("signal",), show="headings",
                                 selectmode="extended")
        self.tree.heading("signal", text="Signal")
        self.tree.column("signal", width=440, anchor="w")
        vsb = ttk.Scrollbar(tbl, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=vsb.set)
        self.tree.bind("<Control-a>", self._tree_select_all)
        self.tree.bind("<Control-c>", self._tree_copy)
        self.tree.pack(side="left", fill="both", expand=True)
        vsb.pack(side="right", fill="y")

        # --- manual add row (entry + Add button)
        row = ttk.Frame(top)
        row.pack(fill="x", pady=(8, 4))
        self.entry_var = tk.StringVar()
        entry = ttk.Entry(row, textvariable=self.entry_var)
        entry.pack(side="left", fill="x", expand=True)
        entry.bind("<Return>", self.on_manual_add)
        self._bind_edit(entry)
        ttk.Button(row, text="Add", command=self.on_manual_add).pack(
            side="left", padx=(6, 0))

        # --- Remove + Send to WV buttons
        btns = ttk.Frame(top)
        btns.pack(fill="x", pady=(0, 8))
        ttk.Button(btns, text="Remove", command=self.remove_selected).pack(
            side="left")
        ttk.Button(btns, text="Send to WV", command=self.send_to_wv).pack(
            side="left", padx=(6, 0))

        # --- log area
        logf = ttk.LabelFrame(top, text="Log", padding=4)
        logf.pack(fill="both", expand=True)
        self.log = tk.Text(logf, height=8, state="disabled", wrap="word")
        lvsb = ttk.Scrollbar(logf, orient="vertical", command=self.log.yview)
        self.log.configure(yscrollcommand=lvsb.set)
        self._bind_edit(self.log)
        self.log.pack(side="left", fill="both", expand=True)
        lvsb.pack(side="right", fill="y")

    # ------------------------------------------------------------ helpers
    def _insert_row(self, name):
        self.tree.insert("", "end", values=(name,))

    def _append_log(self, text):
        self.log.configure(state="normal")
        self.log.insert("end", text)
        self.log.see("end")
        self.log.configure(state="disabled")

    # --------------------------------------------------- keyboard editing
    @staticmethod
    def _is_text(w):
        return isinstance(w, tk.Text)

    def _select_all(self, event):
        w = event.widget
        if self._is_text(w):
            w.tag_add("sel", "1.0", "end-1c")
            w.mark_set("insert", "1.0")
            w.see("insert")
        else:
            # ttk.Entry only supports selection 'clear'/'present'/'range'
            # (not 'from'/'to'), so select-all must use selection_range.
            try:
                w.selection_range(0, "end")
            except Exception:
                try:
                    w.event_generate("<<SelectAll>>")
                except Exception:
                    pass
        return "break"

    def _copy(self, event):
        w = event.widget
        try:
            if self._is_text(w):
                if not w.tag_ranges("sel"):
                    return "break"
                text = w.get("sel.first", "sel.last")
            else:
                text = w.selection_get()
        except Exception:
            return "break"
        self.root.clipboard_clear()
        self.root.clipboard_append(text)
        return "break"

    def _cut(self, event):
        w = event.widget
        try:
            if self._is_text(w):
                if not w.tag_ranges("sel"):
                    return "break"
                text = w.get("sel.first", "sel.last")
                w.delete("sel.first", "sel.last")
            else:
                text = w.selection_get()
                w.delete("sel.first", "sel.last")
        except Exception:
            return "break"
        self.root.clipboard_clear()
        self.root.clipboard_append(text)
        return "break"

    def _paste(self, event):
        w = event.widget
        try:
            text = self.root.clipboard_get()
        except Exception:
            return "break"
        try:
            if self._is_text(w):
                if w.tag_ranges("sel"):
                    w.delete("sel.first", "sel.last")
                w.insert("insert", text)
            else:
                if w.selection_present():
                    w.delete("sel.first", "sel.last")
                w.insert("insert", text)
        except Exception:
            pass
        return "break"

    def _bind_edit(self, widget):
        widget.bind("<Control-a>", self._select_all)
        widget.bind("<Control-c>", self._copy)
        widget.bind("<Control-x>", self._cut)
        widget.bind("<Control-v>", self._paste)

    def _tree_select_all(self, event=None):
        self.tree.selection_set(self.tree.get_children())
        return "break"

    def _tree_copy(self, event=None):
        names = [self.tree.item(iid, "values")[0]
                 for iid in self.tree.selection()]
        if names:
            self.root.clipboard_clear()
            self.root.clipboard_append("\n".join(names))
        return "break"

    # ------------------------------------------------------------- config
    def save_config(self):
        sh_dir = self.sh_dir_var.get().strip()
        if not sh_dir:
            self._append_log("[config] sh dir must not be empty\n")
            return
        try:
            cfg.save_config(sh_dir)
            self._append_log("[config] saved to %s\n" % cfg.config_path())
        except Exception as e:
            self._append_log("[config] save failed: %s\n" % e)
        try:
            skill_path = cfg.save_skill_config(sh_dir)
            self._append_log("[config] saved to SKILL %s\n" % skill_path)
        except Exception as e:
            self._append_log("[config] SKILL save failed: %s\n" % e)

    # ---------------------------------------------------------- table ops
    def on_manual_add(self, _event=None):
        name = self.entry_var.get().strip()
        if name:
            self._insert_row(name)
            self.entry_var.set("")

    def remove_selected(self):
        for iid in self.tree.selection():
            self.tree.delete(iid)

    # ------------------------------------------------------- send to wv
    def send_to_wv(self):
        rows = self.tree.get_children()
        if not rows:
            self._append_log("[wv] the list is empty - add signals first\n")
            return
        sh_dir = self.sh_dir_var.get().strip()
        if not sh_dir:
            self._append_log("[wv] set the sh dir first\n")
            return
        names = [self.tree.item(iid, "values")[0] for iid in rows]
        threading.Thread(target=self._send_worker,
                         args=(names, sh_dir), daemon=True).start()

    # wv_cds_plot.sh answers exactly "<n> new, <m> already plotted"
    _PLOT_RE = re.compile(r"^(\d+) new, (\d+) already plotted$")

    def _send_worker(self, names, sh_dir):
        """Make sure wv is up, then plot every name.

        Nothing is opened file-wise: wv is started on its own and the waveform
        file is chosen inside wv, so sx_signal resolves against whatever is
        open there. wv_cds_plot.sh also skips signals wv already displays.

        start_wv.sh -b is what brings wv up, exactly like the right-click
        items do. It does nothing when a wv is already listening, and waits
        for the port otherwise - so the first Send to WV works instead of
        failing with "Connection refused".

        The log reports one line per send, not one per net: the per-net replies
        are added up, and only the ones that failed get their own line. This is
        the normal path, taken on every Send to WV, so it has to stay quiet.
        """
        starter = os.path.join(sh_dir, "start_wv.sh")
        if os.path.isfile(starter):
            rc, out, err = self._run_sh(sh_dir, "start_wv.sh", "-b")
            if rc != 0:
                self.events.put(("log",
                                 self._fmt_result("start wv", rc, out, err)))
                self.events.put(("log",
                    "[wv] wv is not up - see /tmp/wv_cds_wv.log\n"))
                return
            # rc == 0 is the normal outcome, and start_wv.sh is chatty about it
            # (package, binary, command line, "already listening"), so say
            # nothing here rather than paste all of that into the log.
        else:
            self.events.put(("log",
                "[wv] start_wv.sh not found in the sh dir - plotting without "
                "starting wv\n"))

        new = skipped = 0
        failed = []
        for name in names:
            rc, out, err = self._run_sh(sh_dir, "wv_cds_plot.sh", name)
            m = self._PLOT_RE.match((out or "").strip())
            if rc == 0 and m:
                new += int(m.group(1))
                skipped += int(m.group(2))
            else:
                failed.append(self._fmt_result("plot %s" % name, rc, out, err))

        line = "[wv] %d nets: %d new, %d already on screen" % (
            len(names), new, skipped)
        if failed:
            line += ", %d failed" % len(failed)
        problem = self._ask_virtuoso_to_probe()
        if problem:
            self.events.put(("log", line + "\n"))
            self.events.put(("log", problem))
        else:
            self.events.put(("log", line + ", probes updated\n"))
        for entry in failed:
            self.events.put(("log", entry))

    def _ask_virtuoso_to_probe(self):
        """Tell the running Virtuoso to refresh its net probes.

        Returns "" when it worked, or a message to log when it did not.

        The probes have to be created inside Virtuoso (geAddNetProbe) and
        Virtuoso cannot be called from outside, so it runs a small server that
        evaluates whatever arrives on this port as SKILL - see
        skill/wv_cds_skill_server.il. The command sent is exactly the step the
        right-click "Send to WV (Direct)" runs after plotting, so both routes
        leave the schematic showing whatever wv has on screen.

        Best effort on purpose: the server is switched off by default in some
        setups and a GUI that plotted fine must not look broken because nobody
        was listening.
        """
        try:
            with socket.create_connection(
                    (cfg.WV_CDS_SKILL_HOST, cfg.WV_CDS_SKILL_PORT),
                    timeout=5) as sock:
                sock.sendall(b"wvCdsProbeFromGui()\n")
                stream = sock.makefile("r", encoding="utf-8", errors="replace")
                stream.readline()   # reply to the server's connection notice
                stream.readline()   # reply to our command
        except OSError as exc:
            return ("[skill] no skill server on %s:%d - wv is plotted but the "
                    "schematic probes were not updated (%s)\n"
                    % (cfg.WV_CDS_SKILL_HOST, cfg.WV_CDS_SKILL_PORT, exc))
        return ""

    def _run_sh(self, sh_dir, script, arg):
        path = os.path.join(sh_dir, script)
        try:
            # stdout/stderr=PIPE + universal_newlines keeps this working on
            # Python 3.5/3.6 (capture_output= / text= need 3.7+)
            proc = subprocess.run(["/bin/bash", path, arg],
                                  stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE,
                                  universal_newlines=True, timeout=30)
            return proc.returncode, proc.stdout, proc.stderr
        except Exception as e:  # report any launch failure (missing bash, ...)
            return -1, "", str(e)

    @staticmethod
    def _one_line(text):
        """Collapse a script's multi-line output into one line.

        start_wv.sh and wv_cds_plot.sh print several lines, and joining them
        verbatim produced a single enormous log line.
        """
        return " ".join((text or "").split())

    @classmethod
    def _fmt_result(cls, label, rc, out, err):
        """One log line for a step that failed.

        stderr is kept even when stdout has something, because the scripts
        print a short token on stdout ("refused") and the explanation on
        stderr - dropping it would leave only the bare token.
        """
        parts = [p for p in (cls._one_line(out), cls._one_line(err)) if p]
        tail = " ".join(parts)
        if rc != 0:
            tail = ("%s (exit=%d)" % (tail, rc)).strip()
        return "[wv] %s => %s\n" % (label, tail)

    # ------------------------------------------------------ TCP listener
    def _start_listener(self):
        threading.Thread(target=self._listen, daemon=True).start()

    def _listen(self):
        srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            srv.bind((cfg.WV_CDS_LISTEN_HOST, cfg.WV_CDS_LISTEN_PORT))
            srv.listen(5)
        except OSError as e:
            self.events.put(("log",
                "[listen] cannot bind %s:%d - %s\n"
                % (cfg.WV_CDS_LISTEN_HOST, cfg.WV_CDS_LISTEN_PORT, e)))
            return
        self.events.put(("log",
            "[listen] listening on %s:%d\n"
            % (cfg.WV_CDS_LISTEN_HOST, cfg.WV_CDS_LISTEN_PORT)))
        srv.settimeout(0.5)
        while not self._stop.is_set():
            try:
                conn, addr = srv.accept()
            except socket.timeout:
                continue
            except OSError:
                break
            threading.Thread(target=self._handle_conn, args=(conn, addr),
                             daemon=True).start()
        srv.close()

    def _handle_conn(self, conn, addr):
        with conn:
            # No per-connection log line: every pushed net opens its own
            # connection, so this used to add one line per net while carrying
            # no information. Arrivals are visible as rows in the table.
            stream = conn.makefile("r", encoding="utf-8", errors="replace")
            try:
                for line in stream:
                    name = self._parse_add(line)
                    if name:
                        self.events.put(("add", name))
                    else:
                        self.events.put(("log",
                            "[listen] ignored line: %r\n" % line.strip()))
            except OSError:
                pass

    @staticmethod
    def _parse_add(line):
        s = line.strip()
        if not s:
            return None
        if s.lower().startswith("add "):
            return s[4:].strip() or None
        # a bare single token is also accepted as an add
        if " " not in s and "\t" not in s:
            return s
        return None

    # ---------------------------------------------------- event dispatch
    def _drain_events(self):
        try:
            while True:
                evt = self.events.get_nowait()
                kind = evt[0]
                if kind == "add":
                    self._insert_row(evt[1])
                elif kind == "log":
                    self._append_log(evt[1])
        except queue.Empty:
            pass
        if not self._stop.is_set():
            self.root.after(cfg.WV_CDS_POLL_MS, self._drain_events)

    # ------------------------------------------------------------ close
    def _on_close(self):
        self._stop.set()
        self.root.destroy()


def main():
    app = SignalTableApp()
    app.root.mainloop()


if __name__ == "__main__":
    main()
