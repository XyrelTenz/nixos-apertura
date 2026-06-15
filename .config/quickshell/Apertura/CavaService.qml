import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ── Bars data ──────────────────────────────────────────────────────────
    property var bars: []
    property bool active: false

    // Number of bars (matching cava config)
    readonly property int barCount: 32

    // ── Cava process ───────────────────────────────────────────────────────
    property var _proc: Process {
        id: cavaProc
        running: false
        command: ["cava", "-p",
            Quickshell.env("HOME") + "/.config/cava/quickshell_desktop.conf"]

        stdout: SplitParser {
            onRead: function (line) {
                // cava outputs space-separated integers, one per bar
                var parts = line.trim().split(/\s+/)
                if (parts.length < root.barCount) return

                var newBars = []
                for (var i = 0; i < root.barCount; i++) {
                    var v = parseInt(parts[i], 10)
                    // Scale 0-7 range to 0-100 range
                    newBars.push(isNaN(v) ? 0 : Math.min(100, Math.max(0, Math.round(v * 100 / 7))))
                }
                root.bars = newBars
                if (!root.active) root.active = true
            }
        }

        onExited: function (code, status) {
            root.active = false
            root.bars = []
        }
    }

    // ── Start / Stop ───────────────────────────────────────────────────────
    function start() {
        if (cavaProc.running) return
        cavaProc.running = true
    }

    function stop() {
        if (cavaProc.running) {
            cavaProc.running = false
        }
        root.active = false
        root.bars = []
    }

    Component.onDestruction: {
        stop()
    }

    // Initialize empty bars array
    Component.onCompleted: {
        var initial = []
        for (var i = 0; i < barCount; i++) {
            initial.push(0)
        }
        root.bars = initial
    }
}
