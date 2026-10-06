# Tab history with two movements, ported from ~/Projects/prevtab (the Chrome
# extension) so ctrl+q / ctrl+shift+q behave the same in kitty and the browser.
#
# kitty loads this file twice: as a global watcher (kitty.conf `watcher`), which
# records tab visits, and as a no-UI kitten bound to the shortcuts, which kitty
# re-executes on every press. The two loads don't share globals, so the state
# lives on the Boss object, which both see and which lasts until kitty quits.
#
# previous toggles between the current tab and the one before it: each jump
# promotes its target to the head of the list, so pressing it twice lands you
# back where you started.
#
# walk goes further back without touching the list. It starts at WALK_START
# (skipping the tab previous is aimed at) and steps one deeper per press. The
# next previous ends the walk: the tab the walk landed on is promoted as a
# normal visit, then the toggle runs from there.
#
# Tabs are ranked across all OS windows, and jumping to a tab in another OS
# window focuses it. kitty's own goto_tab -1 keeps a separate history per OS
# window.
from dataclasses import dataclass, field
from typing import Any

from kittens.tui.handler import result_handler
from kitty.boss import Boss
from kitty.window import Window

STATE_ATTR = 'prevtab_state'
MRU_LIMIT = 10
PREVIOUS = 1
WALK_START = 2


@dataclass
class State:
    # Tab ids, newest first. Index 0 is where navigation is measured from, which
    # during a walk is the tab the walk started at, not the visible tab.
    mru: list[int] = field(default_factory=list)
    # Index into mru while walking back, None when not walking.
    cursor: int | None = None
    # Tab this kitten just activated. Its own focus events must not count as a
    # user switch. Cleared by the first event naming a different tab.
    pending: int | None = None


def load_state(boss: Boss) -> State:
    state = getattr(boss, STATE_ATTR, None)
    if state is None:
        state = State()
        setattr(boss, STATE_ATTR, state)
    return state


# Moves a tab to the head of the list. Every caller clears the cursor first, so
# this never has to keep a walk position valid.
def promote(state: State, tab_id: int) -> None:
    if tab_id in state.mru:
        state.mru.remove(tab_id)
    state.mru.insert(0, tab_id)
    del state.mru[MRU_LIMIT:]


def drop(state: State, tab_id: int) -> None:
    if tab_id not in state.mru:
        return
    at = state.mru.index(tab_id)
    del state.mru[at]
    if state.cursor is not None and at < state.cursor:
        state.cursor -= 1


# kitty has no tab-closed event for watchers, so closed tabs are removed before
# every use, and a dead entry never shifts the position a shortcut counts to.
def prune_closed(boss: Boss, state: State) -> None:
    for tab_id in list(state.mru):
        if boss.tab_for_id(tab_id) is None:
            drop(state, tab_id)


# Ends a walk by promoting the tab it landed on, so the list measures from the
# tab actually on screen rather than from where the walk began.
def commit_walk(state: State) -> None:
    if state.cursor is None:
        return
    landed = state.mru[state.cursor] if state.cursor < len(state.mru) else None
    state.cursor = None
    if landed is not None:
        promote(state, landed)


# A real tab switch by the user: it ends any walk and reorders the list.
def record_visit(boss: Boss, tab_id: int) -> None:
    state = load_state(boss)
    if tab_id == state.pending:
        return
    state.pending = None
    prune_closed(boss, state)
    commit_walk(state)
    promote(state, tab_id)


def go_to(boss: Boss, state: State, tab_id: int) -> None:
    # Set before switching: kitty fires the focus change synchronously.
    state.pending = tab_id
    tab = boss.tab_for_id(tab_id)
    window = tab.active_window if tab is not None else None
    if window is not None:
        boss.set_active_window(window, switch_os_window_if_needed=True)


def switch_previous(boss: Boss) -> None:
    state = load_state(boss)
    prune_closed(boss, state)
    commit_walk(state)
    if len(state.mru) <= PREVIOUS:
        return
    target = state.mru[PREVIOUS]
    promote(state, target)
    go_to(boss, state, target)


def walk(boss: Boss) -> None:
    state = load_state(boss)
    prune_closed(boss, state)
    step = WALK_START if state.cursor is None else state.cursor + 1
    if step >= len(state.mru):
        return  # already at the oldest tab we track
    state.cursor = step
    go_to(boss, state, state.mru[step])


COMMANDS = {
    'previous': switch_previous,
    'walk': walk,
}


# Watcher entry point. Switching OS windows fires this too, for the tab shown
# there, the same way switching tabs does.
def on_focus_change(boss: Boss, window: Window, data: dict[str, Any]) -> None:
    if not data['focused']:
        return
    tab = window.tabref()
    if tab is not None:
        record_visit(boss, tab.id)


# Kitten entry points: `kitten prevtab.py previous|walk`.
def main(args: list[str]) -> None:
    pass


@result_handler(no_ui=True)
def handle_result(args: list[str], answer: Any, target_window_id: int, boss: Boss) -> None:
    COMMANDS[args[1]](boss)
