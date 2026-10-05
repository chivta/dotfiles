# Custom title segment for tab_title_template's {custom}.
# Shows a bell on tabs where a window set the bell_pending user var (see
# watcher.py for clearing). Defers to kitty's built-in bell_symbol so a tab
# never shows two bells.
from typing import Any

from kitty.boss import get_boss

BELL = '🔔 '
VAR = 'bell_pending'


def draw_title(data: dict[str, Any]) -> str:
    if data.get('bell_symbol'):
        return ''
    tab = get_boss().tab_for_id(data['tab_id'])
    if tab is None:
        return ''
    return BELL if any(VAR in w.user_vars for w in tab) else ''
