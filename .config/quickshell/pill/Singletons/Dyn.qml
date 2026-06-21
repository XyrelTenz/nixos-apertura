pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Live wallpaper-derived palette. matugen writes a small colour JSON on every
 * wallpaper change (via wallcolors.py) and this singleton watches it, so the
 * tokens update the moment the wallpaper does. Theme reads these only while the
 * dynamic-palette flag is on; otherwise the curated washi hex wins. Defaults are
 * a warm fallback so a missing file still yields a usable scheme. Surfaces and
 * the accent ramp come from here; text stays locked in Theme for contrast.
 */
Singleton {
    id: root

    readonly property string surface: adapter.surface
    readonly property string surfaceContainer: adapter.surface_container
    readonly property string surfaceContainerLow: adapter.surface_container_low
    readonly property string surfaceContainerHigh: adapter.surface_container_high
    readonly property string surfaceContainerHighest: adapter.surface_container_highest
    readonly property string primary: adapter.primary
    readonly property string primaryContainer: adapter.primary_container
    readonly property string onPrimaryContainer: adapter.on_primary_container
    readonly property string outline: adapter.outline
    readonly property string outlineVariant: adapter.outline_variant
    readonly property string cream: adapter.cream
    readonly property string bright: adapter.bright
    readonly property string subtle: adapter.subtle
    readonly property string dim: adapter.dim
    readonly property string faint: adapter.faint
    readonly property string iconDim: adapter.icon_dim
    readonly property string tickRest: adapter.tick_rest

    // Base16 colors
    readonly property string base00: adapter.base00
    readonly property string base01: adapter.base01
    readonly property string base02: adapter.base02
    readonly property string base03: adapter.base03
    readonly property string base04: adapter.base04
    readonly property string base05: adapter.base05
    readonly property string base06: adapter.base06
    readonly property string base07: adapter.base07
    readonly property string base08: adapter.base08
    readonly property string base09: adapter.base09
    readonly property string base0a: adapter.base0a
    readonly property string base0b: adapter.base0b
    readonly property string base0c: adapter.base0c
    readonly property string base0d: adapter.base0d
    readonly property string base0e: adapter.base0e
    readonly property string base0f: adapter.base0f

    FileView {
        id: file
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ricelin/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property string surface: "#18120b"
            property string surface_container: "#251f17"
            property string surface_container_low: "#211b13"
            property string surface_container_high: "#302921"
            property string surface_container_highest: "#3b342b"
            property string primary: "#f5bd6f"
            property string primary_container: "#633f00"
            property string on_primary_container: "#ffddb3"
            property string outline: "#9c8f80"
            property string outline_variant: "#4f4539"
            property string cream: "#e6d6cb"
            property string bright: "#fff6f0"
            property string subtle: "#b9a99e"
            property string dim: "#8a7d74"
            property string faint: "#6f635b"
            property string icon_dim: "#cdbfb4"
            property string tick_rest: "#cbb6a3"

            // Base16 colors fallbacks
            property string base00: "#181818"
            property string base01: "#313131"
            property string base02: "#494949"
            property string base03: "#767676"
            property string base04: "#929292"
            property string base05: "#a6a6a6"
            property string base06: "#c3c3c3"
            property string base07: "#ffffff"
            property string base08: "#c0442b"
            property string base09: "#e0563b"
            property string base0a: "#eeb440"
            property string base0b: "#8ba747"
            property string base0c: "#5fa8a3"
            property string base0d: "#4890c0"
            property string base0e: "#a87fa8"
            property string base0f: "#a3371f"
        }
    }
}
