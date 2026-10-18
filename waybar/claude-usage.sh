#!/usr/bin/env bash
# Waybar module: Claude usage from `claudebar --json` (one call, always exits 0 with valid JSON).

FONT='Noto Sans Mono'
TOOLTIP_COLS=32
TOOLTIP_SIZE=10000
FACE_GAUGE_COLS=12
FACE_GAUGE_SIZE=3750      # pango size units (1/1024 pt); 0.6 em col = 3 px
FACE_FILL='#ffffff'
FACE_MIN_COLS=1
COLOR_DIM='#8e8e93'
COLOR_TRACK='#3a3a3c'
COLOR_TICK='#32d4e6'
COLOR_BADGE_BG='#3a3a3c'
COLOR_OK='#32d74b'
COLOR_STALE='#ffb340'
SECONDS_PER_HOUR=3600
BAR_LINE_HEIGHT=0.4
BAR_GAP_SIZE=2000
RULE_GLYPH='─'
HEADER_SIZE=large

FACE=${1:-pct}

raw=$(claudebar --json 2>/dev/null)

jq -c --argjson raw "$(jq -c . <<<"$raw" 2>/dev/null || echo null)" -n \
  --arg font "$FONT" --arg tsz "$TOOLTIP_SIZE" --argjson cols "$TOOLTIP_COLS" \
  --argjson gcols "$FACE_GAUGE_COLS" --arg gsize "$FACE_GAUGE_SIZE" --argjson mincols "$FACE_MIN_COLS" --arg face "$FACE" \
  --arg ffill "$FACE_FILL" \
  --arg dim "$COLOR_DIM" --arg track "$COLOR_TRACK" --arg tick "$COLOR_TICK" --arg badgebg "$COLOR_BADGE_BG" \
  --arg ok "$COLOR_OK" --arg stalec "$COLOR_STALE" \
  --argjson sph "$SECONDS_PER_HOUR" --arg lh "$BAR_LINE_HEIGHT" --arg gapsize "$BAR_GAP_SIZE" \
  --arg ruleg "$RULE_GLYPH" --arg hsize "$HEADER_SIZE" '
def esc: tostring | gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
def rep($s; $n): if $n <= 0 then "" else [range($n) | $s] | join("") end;
def span($attrs; $t): "<span \($attrs)>\($t)</span>";
def clamp($lo; $hi): if . < $lo then $lo elif . > $hi then $hi else . end;
def dimspan($t): span("foreground=\"\($dim)\""; $t | esc);

def face($pct; $text):
  if $face == "gauge" then
    (($pct // 0 | clamp(0; 100)) * $gcols / 100 | round | if . < $mincols then $mincols else . end) as $n
    | span("font_family=\"\($font)\" size=\"\($gsize)\" bgcolor=\"\($ffill)\""; rep(" "; $n))
      + span("font_family=\"\($font)\" size=\"\($gsize)\""; rep(" "; $gcols - $n))
  else $text end;

def bar($pct; $elapsed; $color):
  (($pct | clamp(0; 100)) * $cols / 100 | round) as $fill
  | (($elapsed | clamp(0; 100)) * $cols / 100 | floor | clamp(0; $cols - 1)) as $t0
  | def part($n; $bg): if $n <= 0 then "" else span("font_family=\"\($font)\" bgcolor=\"\($bg)\""; rep(" "; $n)) end;
    def seg($a; $b): (([$b, $fill] | min) - $a | clamp(0; $b - $a)) as $f | part($f; $color) + part($b - $a - $f; $track);
  span("size=\"\($gapsize)\""; " ") + "\n"
  + span("line_height=\"\($lh)\""; seg(0; $t0) + part(1; $tick) + seg($t0 + 1; $cols))
  + "\n" + span("size=\"\($gapsize)\""; " ");

def reset_line($unix):
  ($unix | localtime) as $t
  | (now | localtime | mktime) as $nowl
  | ($t | mktime) as $tl
  | (($nowl / 86400 | floor)) as $dn
  | (($tl / 86400 | floor)) as $dr
  | (if $dr == $dn then "Today \($t | strftime("%H:%M"))"
     elif $dr == $dn + 1 then "Tomorrow \($t | strftime("%H:%M"))"
     else $t | strftime("%b %d, %H:%M") end)
  | "Resets " + .;

def section($pal):
  ($pal[.state] // $pal.low // $ok) as $c
  | (if .id == "session" then "Session Usage"
     elif .group == null then "All models"
     else .group end) as $title
  | (if .id == "session" then "" else .label // "" end) as $badge
  | ($title | length) as $tl
  | (if $badge == "" then 0 else ($badge | length) + 3 end) as $bl
  | "\(.used_pct)%" as $pct
  | (rep(" "; $cols - $tl - $bl - ($pct | length))) as $pad
  | span("weight=\"bold\""; $title | esc)
    + (if $badge == "" then "" else " " + span("bgcolor=\"\($badgebg)\" foreground=\"\($dim)\""; " \($badge | esc) ") end)
    + $pad + span("weight=\"bold\" foreground=\"\($c)\""; $pct)
    + "\n"
    + (if .id == "session" then dimspan("\((.window_seconds / $sph) | round)-hour rolling window") + "\n" else "" end)
    + bar(.used_pct; .elapsed_pct // 0; $c) + "\n"
    + dimspan(reset_line(.reset_at_unix));

def header($d; $dot; $status):
  span("weight=\"bold\" size=\"\($hsize)\""; "Claude" + (if $d.plan then " \($d.plan | esc)" else "" end))
  + "\n" + span("foreground=\"\($dot)\""; "●") + " " + dimspan($status)
  + "\n" + dimspan(rep($ruleg; $cols));

def wrap($t): span("font_family=\"\($font)\" size=\"\($tsz)\""; $t);

($raw // {error: {message: "claudebar unavailable"}}) as $d
| ($d.palette // {}) as $pal
| ($d.windows // []) as $ws
| if $d.loading == true then
    {text: face(0; "…"), class: "loading",
     tooltip: wrap(header($d; $stalec; "Loading…") + "\n\nLoading…")}
  elif $d.error != null or ($ws | length) == 0 then
    {text: face(0; "--%"), class: "error",
     tooltip: wrap(header($d; $stalec; "Unavailable") + "\n\n" + ($d.error.message // "No usage data" | esc))}
  else
    (($ws | map(select(.id == "session")) | first) // $ws[0]) as $s
    | ($d.updated_at | fromdate | localtime | strftime("%H:%M")) as $upd
    | (if $d.stale == true
       then "Stale data" + (if $d.last_error.message then ": \($d.last_error.message)" else "" end)
       else "Updated \($upd)" end) as $status
    | {text: face($s.used_pct; "\($s.used_pct)%"), class: ($d.state // "low"),
       tooltip: wrap(header($d; (if $d.stale == true then $stalec else $ok end); $status)
         + "\n\n" + ($ws | map(section($pal)) | join("\n\n")))}
  end
' 2>/dev/null || echo '{"text":"--%","tooltip":"claude-usage failed","class":"error"}'
exit 0
