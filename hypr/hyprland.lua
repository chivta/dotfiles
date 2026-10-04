-- This is an example Hyprland config file.
-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/

-- Please note not all available settings / options are set here.
-- For a full list, see the wiki

-- You can split this configuration into multiple files
-- Create your files separately and then link them to this file like this:
-- source = ~/.config/hypr/myColors.conf


--###############
--## MONITORS ###
--###############

-- See https://wiki.hypr.land/Configuring/Monitors/
--############
-- Matched by EDID description, not connector name: the connector names
-- (HDMI-A-3, DP-2) change whenever a cable moves to a different port.

-- Main monitor, landscape, left.
local MAIN_MONITOR = "desc:Acer Technologies VG270 TEGEE0018512"
-- Secondary monitor, physically rotated 90 degrees, right.
local SIDE_MONITOR = "desc:Iiyama North America PLX2380H 11177G5900770"

hl.monitor({
  output = MAIN_MONITOR,
  mode = "1920x1080@75",
  position = "0x0",
  scale = 1,
  transform = 0
})
hl.monitor({
  output = SIDE_MONITOR,
  -- This panel tops out at 60Hz at 1080p.
  mode = "1920x1080@60",
  position = "1920x-456",
  scale = 1.25,
  transform = 1
})


--## MY PROGRAMS ###
--##################

local terminal    = "kitty"
local fileManager = "dolphin"
local menu        = "GTK_THEME=Adwaita:dark wofi --show drun --gtk-dark --matching=fuzzy --insensitive"


--################
--## AUTOSTART ###
--################

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:

hl.on("hyprland.start", function ()
  hl.exec_cmd("hyprctl setcursor teto 48")
  hl.exec_cmd("kitty & hyprpaper & waybar & hypridle")
  hl.exec_cmd("exec-once=dbus-update-activation-environment --systemd --all WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
  hl.exec_cmd("exec-once = systemctl --user start graphical-session-pre.target")
  hl.exec_cmd("exec-once = systemctl --user start graphical-session.target")
    hl.exec_cmd("easyeffects --service-mode")
    hl.exec_cmd("brave")
    hl.exec_cmd("spotify")
    hl.exec_cmd("signal-desktop")
    hl.exec_cmd("betterbird")
end)


local launch_workspace = {}

local function exec_on_current(cmd, class_pattern)
    local ws = hl.get_active_workspace()
    launch_workspace[class_pattern] = ws.id
    hl.exec_cmd(cmd)
end

hl.on("window.open", function(w)
    for pattern, ws_id in pairs(launch_workspace) do
        if w.class:match(pattern) then
            hl.dispatch(hl.dsp.window.move({ workspace = ws_id }))
            launch_workspace[pattern] = nil
            break
        end
    end
end)

hl.workspace_rule({ workspace = "1", monitor = MAIN_MONITOR, default = true })
hl.workspace_rule({ workspace = "2", monitor = MAIN_MONITOR })
hl.workspace_rule({ workspace = "3", monitor = MAIN_MONITOR })
hl.workspace_rule({ workspace = "4", monitor = MAIN_MONITOR })
hl.workspace_rule({ workspace = "5", monitor = SIDE_MONITOR, default = true})
hl.workspace_rule({ workspace = "6", monitor = SIDE_MONITOR })
hl.workspace_rule({ workspace = "7", monitor = SIDE_MONITOR })
hl.workspace_rule({ workspace = "8", monitor = SIDE_MONITOR })
hl.workspace_rule({ workspace = "9", monitor = SIDE_MONITOR })

-- kitty: workspace 1
hl.window_rule({
    match = { class = "^kitty$" },
    workspace = "1",
})

-- kitty: opacity
hl.window_rule({
    match = { class = "^kitty$" },
    opacity = "0.85 0.85",
})

-- float rules
hl.window_rule({
    match = { initial_title = "Picture in picture" },
    float = true,
})

hl.window_rule({
    match = { initial_class = "floating" },
    float = true,
})

hl.window_rule({
    match = { initial_class = "org.kde.dolphin" },
    float = true,
})

hl.window_rule({
    match = { class = "xdg-desktop-portal-gtk" },
    float = true,
})

-- "foo wants to..." dialogs — lua patterns, not POSIX regex
hl.window_rule({
    match = { initial_title = ".*wants.*" },
    float = true,
})

-- brave: workspace 2, silent so it doesn't steal focus
hl.window_rule({
    match = { initial_class = "brave-browser" },
    workspace = "2 silent",
})

-- spotify: workspace 1
hl.window_rule({
    match = { initial_class = "^spotify$" },
    workspace = "1 silent",
})

-- signal: workspace 3
hl.window_rule({
    match = { initial_class = "^signal$" },
    workspace = "5 silent",
})

-- betterbird: workspace 4
hl.window_rule({
    match = { initial_class = "^eu.betterbird.Betterbird$" },
    workspace = "5 silent",
})


-- steam: workspace 4
hl.window_rule({
    match = { initial_class = "^.*steam.*$" },
    workspace = "4 silent",
})

hl.window_rule({
    match = { initial_class = "^remmina$" },
    workspace = "4 silent",
})
hl.window_rule({
    match = { initial_class = "^discord$" },
    workspace = "5 silent",
})
--############################
--## ENVIRONMENT VARIABLES ###
--############################

-- See https://wiki.hypr.land/Configuring/Environment-variables/

hl.env("HYPRCURSOR_THEME", "teto")
hl.env("HYPRCURSOR_SIZE", "48")
hl.env("XCURSOR_THEME", "teto-xcursor")
hl.env("XCURSOR_SIZE", "48")

-- Capture gnome-keyring-daemon output and export each VAR=value line
local handle = io.popen("gnome-keyring-daemon --start 2>/dev/null")
if handle then
    for line in handle:lines() do
        local k, v = line:match("^([^=]+)=(.+)$")
        if k and v then
            hl.env(k, v)
        end
    end
    handle:close()
end

--##################
--## PERMISSIONS ###
--##################

-- See https://wiki.hypr.land/Configuring/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- ecosystem {
--   enforce_permissions = 1
-- }

-- permission = /usr/(bin|local/bin)/grim, screencopy, allow
-- permission = /usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland, screencopy, allow
-- permission = /usr/(bin|local/bin)/hyprpm, plugin, allow


--####################
--## LOOK AND FEEL ###
--####################

hl.config({
  cursor = {
    no_hardware_cursors = true
  },
  xwayland = {
    force_zero_scaling = true
  },
	general = {
        gaps_in  = 5,
        gaps_out = 20,

        border_size = 2,

        col = {
            active_border   = { colors = {"rgba(f84e7aee)", "rgba(800928ee)"}, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },

    binds = {
        allow_workspace_cycles = true,
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = false,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

hl.animation({ leaf = "global",        enabled = true, speed = 2,  bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 3,  bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 3,  bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 3,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 2,  bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1,  bezier = "default",      style = "fade" })
hl.animation({ leaf = "layers",        enabled = true, speed = 2,  bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 2,  bezier = "easeOutQuint" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 3,  bezier = "linear" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1,  bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1,  bezier = "almostLinear" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 3,  bezier = "quick" })

-- hl.config({
   -- dwindle = {
     --   pseudotile     = true,
       -- preserve_split = true,
--    },
--})

hl.config({
    master = {
        new_status = "master",
    },
})

--############
--## INPUT ###
--############
hl.config({
    input = {
        kb_layout  = "us,ua",
        kb_options = "grp:alt_shift_toggle",
        kb_variant = "",
        kb_model   = "",
        kb_rules   = "",

        follow_mouse = 1,
        sensitivity  = -0.35,

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -1,
})
--##################
--## KEYBINDINGS ###
--##################

local mainMod = "SUPER"

-- Apps
hl.bind(mainMod .. " + T",           hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + K",           hl.dsp.window.close())
hl.bind(mainMod .. " + M",           hl.dsp.exit())
hl.bind(mainMod .. " + E",           hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V",           hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + space",       hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P",           hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J",           hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F",           hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + L",           hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + Q",           hl.dsp.focus({ workspace = "previous" }))

-- Hyprshot
hl.bind(mainMod .. " + SHIFT + S",   hl.dsp.exec_cmd("hyprshot --silent --freeze --clipboard-only -m region"))
hl.bind("PRINT",                     hl.dsp.exec_cmd("hyprshot --silent --clipboard-only -m output"))
hl.bind(mainMod .. " + PRINT",       hl.dsp.exec_cmd("hyprshot --silent -m region"))

-- Focus
hl.bind(mainMod .. " + left",        hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right",       hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",          hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",        hl.dsp.focus({ direction = "down" }))

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Audio output toggle
hl.bind(mainMod .. " + SHIFT + a",   hl.dsp.exec_cmd(
    "pactl set-default-sink \"$(pactl get-default-sink | grep -q '00_1f.3' " ..
    "&& echo alsa_output.pci-0000_01_00.1.pro-output-3 " ..
    "|| echo alsa_output.pci-0000_00_1f.3.pro-output-0)\""
))

-- Scroll workspaces
hl.bind(mainMod .. " + mouse_down",  hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",    hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize with mouse
hl.bind(mainMod .. " + mouse:272",   hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",   hl.dsp.window.resize(), { mouse = true })

-- Volume / brightness (bindel → repeating = true)
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Playerctl (bindl → locked = true, no repeating)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),        { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"),  { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"),  { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),    { locked = true })

--#############################
--## WINDOWS AND WORKSPACES ###
--#############################


-- Ignore maximize requests from apps
hl.window_rule({
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
    name  = "xwayland",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})
