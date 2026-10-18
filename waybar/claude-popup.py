#!/usr/bin/env python3
"""Click popup for the Claude usage module: shows the markup claude-usage.sh last wrote."""
import os
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, Gio, Gtk, GtkLayerShell

APP_ID = "dev.arvlas.ClaudePopup"
MARKUP_PATH = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "claude-usage", "popup.markup")
BAR_HEIGHT = 28
GAP_BELOW_BAR = 4
CSS = b"""
window, eventbox { background: transparent; }
.card {
    background-color: #1c1c1e;
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-radius: 12px;
    padding: 12px 14px;
}
.card label { color: #eeeeee; }
"""


def pointer():
    x, y = subprocess.check_output(["hyprctl", "cursorpos"], text=True).split(",")
    return int(x), int(y)


def monitor_at(display, x, y):
    for i in range(display.get_n_monitors()):
        mon = display.get_monitor(i)
        g = mon.get_geometry()
        if g.x <= x < g.x + g.width and g.y <= y < g.y + g.height:
            return mon
    return display.get_primary_monitor()


class Popup(Gtk.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.FLAGS_NONE)
        self.win = None

    def do_activate(self):
        if self.win is not None:
            self.win.destroy()
            return
        self.show()

    def show(self):
        try:
            with open(MARKUP_PATH) as f:
                markup = f.read()
        except OSError:
            markup = "No usage data yet"

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        win = Gtk.Window(application=self)
        win.set_app_paintable(True)
        win.set_visual(win.get_screen().get_rgba_visual())
        card = Gtk.Box()
        card.get_style_context().add_class("card")
        label = Gtk.Label()
        label.set_markup(markup)
        card.add(label)

        px, py = pointer()
        mon = monitor_at(win.get_display(), px, py)
        geo = mon.get_geometry()
        card.set_halign(Gtk.Align.START)
        card.set_valign(Gtk.Align.START)
        card.set_margin_top(BAR_HEIGHT + GAP_BELOW_BAR)

        def place(widget, alloc):
            # Width is only known after the first allocation.
            left = min(max(px - geo.x - alloc.width // 2, 0), max(geo.width - alloc.width, 0))
            if widget.get_margin_start() != left:
                widget.set_margin_start(left)

        card.connect("size-allocate", place)

        # Full-monitor transparent layer so a click anywhere outside the card closes the popup.
        backdrop = Gtk.EventBox()
        backdrop.add(card)
        backdrop.connect("button-press-event", lambda w, e: win.destroy())
        win.add(backdrop)

        GtkLayerShell.init_for_window(win)
        GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_monitor(win, mon)
        GtkLayerShell.set_exclusive_zone(win, -1)
        GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT, GtkLayerShell.Edge.BOTTOM):
            GtkLayerShell.set_anchor(win, edge, True)

        win.connect("key-press-event", lambda w, e: w.destroy() if e.keyval == Gdk.KEY_Escape else None)
        win.connect("destroy", self.on_destroy)
        self.win = win
        win.show_all()

    def on_destroy(self, _win):
        self.win = None
        self.quit()


if __name__ == "__main__":
    sys.exit(Popup().run(sys.argv))
