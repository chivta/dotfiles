#!/usr/bin/env bash
# Waybar image module: draws the Claude usage face from the limits claude-statusline.sh saved and saves the popup markup for claude-popup.py.

FONT='Noto Sans Mono'
POPUP_COLS=32
POPUP_SIZE=10000
SVG_W=36
SVG_H=28
GAUGE_X=1
GAUGE_Y=5
GAUGE_W=34
GAUGE_H=9
GAUGE_RADIUS=3
GAUGE_INSET=2
FILL_MIN_W=3
MARKER_W=1.5
LABEL_Y=25
LABEL_SIZE=10
LABEL_FONT='Noto Sans'
COLOR_LABEL='#eeeeee'
COLOR_OUTLINE='#8e8e93'
COLOR_DIM='#8e8e93'
COLOR_TRACK='#3a3a3c'
COLOR_TICK='#32d4e6'
COLOR_BADGE_BG='#3a3a3c'
COLOR_OK='#32d74b'
COLOR_LOW='#98c379'
COLOR_MID='#e5c07b'
COLOR_HIGH='#d19a66'
COLOR_CRITICAL='#e06c75'
THRESHOLD_MID=50
THRESHOLD_HIGH=75
THRESHOLD_CRITICAL=90
SESSION_SECONDS=18000
WEEKLY_SECONDS=604800
SECONDS_PER_DAY=86400
NO_DATA_HINT=$'Send a message in Claude Code\nto load usage.'
SECONDS_PER_HOUR=3600
BAR_LINE_HEIGHT=0.4
BAR_GAP_SIZE=2000
RULE_GLYPH='─'
HEADER_SIZE=large

OUT_DIR=${XDG_CACHE_HOME:-$HOME/.cache}/claude-usage
mkdir -p "$OUT_DIR"

result=$(jq -c --argjson raw "$(jq -c . "$OUT_DIR/rate-limits.json" 2>/dev/null || echo null)" --argjson now "$(date +%s)" -n \
  --arg font "$FONT" --arg tsz "$POPUP_SIZE" --argjson cols "$POPUP_COLS" \
  --argjson g "{\"w\":$SVG_W,\"h\":$SVG_H,\"x\":$GAUGE_X,\"y\":$GAUGE_Y,\"gw\":$GAUGE_W,\"gh\":$GAUGE_H,\"r\":$GAUGE_RADIUS,\"inset\":$GAUGE_INSET,\"minw\":$FILL_MIN_W,\"mw\":$MARKER_W,\"ly\":$LABEL_Y,\"ls\":$LABEL_SIZE}" \
  --arg lfont "$LABEL_FONT" --arg clabel "$COLOR_LABEL" --arg coutline "$COLOR_OUTLINE" \
  --arg dim "$COLOR_DIM" --arg track "$COLOR_TRACK" --arg tick "$COLOR_TICK" --arg badgebg "$COLOR_BADGE_BG" \
  --arg ok "$COLOR_OK" --arg hint "$NO_DATA_HINT" \
  --argjson spd "$SECONDS_PER_DAY" --argjson sess "$SESSION_SECONDS" --argjson week "$WEEKLY_SECONDS" \
  --argjson tmid "$THRESHOLD_MID" --argjson thigh "$THRESHOLD_HIGH" --argjson tcrit "$THRESHOLD_CRITICAL" \
  --arg clow "$COLOR_LOW" --arg cmid "$COLOR_MID" --arg chigh "$COLOR_HIGH" --arg ccrit "$COLOR_CRITICAL" \
  --argjson sph "$SECONDS_PER_HOUR" --arg lh "$BAR_LINE_HEIGHT" --arg gapsize "$BAR_GAP_SIZE" \
  --arg ruleg "$RULE_GLYPH" --arg hsize "$HEADER_SIZE" '
def esc: tostring | gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
def rep($s; $n): if $n <= 0 then "" else [range($n) | $s] | join("") end;
def span($attrs; $t): "<span \($attrs)>\($t)</span>";
def clamp($lo; $hi): if . < $lo then $lo elif . > $hi then $hi else . end;
def dimspan($t): span("foreground=\"\($dim)\""; $t | esc);

def face($pct; $elapsed; $color; $label):
  ($g.x + $g.inset) as $ix | ($g.gw - 2 * $g.inset) as $iw
  | ($g.y + $g.inset) as $iy | ($g.gh - 2 * $g.inset) as $ih
  | (if $pct == null then 0 else [($pct | clamp(0; 100)) * $iw / 100, $g.minw] | max end) as $fw
  | "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\($g.w)\" height=\"\($g.h)\" viewBox=\"0 0 \($g.w) \($g.h)\">"
    + "<rect x=\"\($g.x + 0.5)\" y=\"\($g.y + 0.5)\" width=\"\($g.gw - 1)\" height=\"\($g.gh - 1)\" rx=\"\($g.r)\" fill=\"none\" stroke=\"\($coutline)\"/>"
    + (if $pct == null then "" else "<rect x=\"\($ix)\" y=\"\($iy)\" width=\"\($fw)\" height=\"\($ih)\" rx=\"\([$ih / 2, $fw / 2] | min)\" fill=\"\($color)\"/>" end)
    + (if $elapsed == null then "" else
        ($ix + ($elapsed | clamp(0; 100)) * $iw / 100) as $mx
        | "<rect x=\"\($mx - $g.mw / 2)\" y=\"\($g.y)\" width=\"\($g.mw)\" height=\"\($g.gh)\" fill=\"\($tick)\"/>" end)
    + "<text x=\"\($g.w / 2)\" y=\"\($g.ly)\" text-anchor=\"middle\" font-family=\"\($lfont)\" font-size=\"\($g.ls)\" fill=\"\($clabel)\">\($label)</text></svg>";

def bar($pct; $elapsed; $color):
  (($pct | clamp(0; 100)) * $cols / 100 | round) as $fill
  | (if $elapsed == null then $cols else ($elapsed | clamp(0; 100)) * $cols / 100 | floor | clamp(0; $cols - 1) end) as $t0
  | def part($n; $bg): if $n <= 0 then "" else span("font_family=\"\($font)\" bgcolor=\"\($bg)\""; rep(" "; $n)) end;
    def seg($a; $b): (([$b, $fill] | min) - $a | clamp(0; $b - $a)) as $f | part($f; $color) + part($b - $a - $f; $track);
  span("size=\"\($gapsize)\""; " ") + "\n"
  + span("line_height=\"\($lh)\""; seg(0; $t0) + (if $elapsed == null then "" else part(1; $tick) + seg($t0 + 1; $cols) end))
  + "\n" + span("size=\"\($gapsize)\""; " ");

def day($t): ($t | mktime) / $spd | floor;

def when($unix; $fmt):
  ($unix | localtime) as $t
  | (day($now | localtime)) as $dn
  | day($t) as $dr
  | if $dr == $dn then "Today \($t | strftime("%H:%M"))"
    elif $dr == $dn + 1 then "Tomorrow \($t | strftime("%H:%M"))"
    else $t | strftime($fmt) end;

def updated($unix):
  ($unix | localtime) as $t
  | if day($t) == day($now | localtime) then $t | strftime("%H:%M") else $t | strftime("%b %d, %H:%M") end;

def color($pct): if $pct >= $tcrit then $ccrit elif $pct >= $thigh then $chigh elif $pct >= $tmid then $cmid else $clow end;

def section:
  color(.used) as $c
  | (if .id == "session" then "Session Usage" else "All models" end) as $title
  | (if .id == "session" then "" else .label end) as $badge
  | ($title | length) as $tl
  | (if $badge == "" then 0 else ($badge | length) + 3 end) as $bl
  | "\(.used)%" as $pct
  | (rep(" "; $cols - $tl - $bl - ($pct | length))) as $pad
  | span("weight=\"bold\""; $title)
    + (if $badge == "" then "" else " " + span("bgcolor=\"\($badgebg)\" foreground=\"\($dim)\""; " \($badge) ") end)
    + $pad + span("weight=\"bold\" foreground=\"\($c)\""; $pct)
    + "\n"
    + (if .id == "session" then dimspan("\((.secs / $sph) | round)-hour rolling window") + "\n" else "" end)
    + bar(.used; .elapsed; $c) + "\n"
    + dimspan(if .expired then "Window reset" else "Resets " + when(.resets_at; "%b %d, %H:%M") end);

def header($status):
  span("weight=\"bold\" size=\"\($hsize)\""; "Claude")
  + "\n" + span("foreground=\"\($ok)\""; "●") + " " + dimspan($status)
  + "\n" + dimspan(rep($ruleg; $cols));

def wrap($t): span("font_family=\"\($font)\" size=\"\($tsz)\""; $t);

[{id: "session", label: "Session", key: "five_hour", secs: $sess},
 {id: "weekly", label: "Weekly", key: "seven_day", secs: $week}] as $defs
| ($raw // {}) as $d
| [$defs[] | . as $w | ($d[$w.key] // null) as $l | select($l != null)
    | ($l.resets_at <= $now) as $exp
    | $w + {resets_at: $l.resets_at, expired: $exp,
            used: (if $exp then 0 else ($l.used_percentage | round) end),
            elapsed: (if $exp then null else 100 - ($l.resets_at - $now) / $w.secs * 100 | clamp(0; 100) end)}] as $ws
| if ($ws | length) == 0 then
    {face: face(null; null; null; "--%"),
     popup: wrap(header("No usage data") + "\n\n" + $hint)}
  else
    (($ws | map(select(.id == "session")) | first)) as $s
    | {face: (if $s == null then face(null; null; null; "--%") else face($s.used; $s.elapsed; color($s.used); "\($s.used)%") end),
       popup: wrap(header("Updated " + updated($d.saved_at))
         + "\n\n" + ($ws | map(section) | join("\n\n")))}
  end
' 2>/dev/null)

if [ -n "$result" ]; then
    jq -r .face <<<"$result" >"$OUT_DIR/face.svg"
    jq -r .popup <<<"$result" >"$OUT_DIR/popup.markup"
fi
echo "$OUT_DIR/face.svg"
exit 0
