--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Confirm Close Rule
hl.window_rule({
	name = "confirm-close",
	match = { class = ".*" },
})

-- Suppress Maximize Rule
local suppressMaximizeRule = hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Fix XWayland Drag & Drop Focus Issue
hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

-- Position Hyprland run dialog launcher
hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move = "20 monitor_h-120",
	float = true,
})

-- Satty (screenshot editor) always floats
hl.window_rule({
	name = "satty-screenshot-floating",
	match = {
		class = "com.gabm.satty",
	},
	float = true,
})

---------------------
---- LAYER RULES ----
---------------------

-- Blur and XRay for Quickshell Desktop Bar
hl.layer_rule({
	name = "quickshell-bar-blur",
	match = { namespace = "quickshell-bar" },
	blur = true,
	xray = true,
})

-- Blur and XRay for Quickshell Drawers & Components
hl.layer_rule({
	name = "quickshell-components-blur",
	match = {
		namespace = "^(quickshell-(overlay|wallpapers|launcher|workspace-preview|detached-note)|desktop-clock-widget)$",
	},
	blur = true,
	xray = true,
	ignore_alpha = 0.5,
})
