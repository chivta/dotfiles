# Global watcher: persistent "bell" marker for tabs.
# A program sets the user var bell_pending on its window; tab_bar.py renders it.
# The marker is cleared here, when the user leaves the tab.
from typing import Any

from kitty.boss import Boss
from kitty.window import Window

VAR = 'bell_pending'


def on_set_user_var(boss: Boss, window: Window, data: dict[str, Any]) -> None:
    # Redraw immediately; otherwise the tab bar updates only on its next dirty mark.
    if data['key'] == VAR:
        tab = window.tabref()
        if tab is not None:
            tab.mark_tab_bar_dirty()


def on_focus_change(boss: Boss, window: Window, data: dict[str, Any]) -> None:
    if data['focused']:
        return
    tab = window.tabref()
    if tab is None:
        return
    tm = tab.tab_manager_ref()
    # Still the active tab of its OS window: split change, app switch or OS window
    # switch. Keep the marker.
    if tm is None or tm.active_tab is tab:
        return
    cleared = False
    for w in tab:
        if VAR in w.user_vars:
            del w.user_vars[VAR]
            cleared = True
    if cleared:
        tab.mark_tab_bar_dirty()
