pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Shared session flags persisted to a small JSON file and watched for external
 * change, so every Ricelin daemon (pill, sidebar) reads and writes the same
 * Do-Not-Disturb and Keep-Awake state live without a second notification server
 * or idle inhibitor. Toggling in one surface updates the others on the next file
 * event, and the state survives a daemon restart.
 *
 * The adapter mirrors the pill's full key set even though this surface only
 * drives dnd and keepAwake: JsonAdapter.writeAdapter() serialises only declared
 * properties and drops every other key, so a partial adapter writing this shared
 * file would wipe the pill's record and display prefs on each reload echo. The
 * extra fields exist purely to round-trip those keys; only dnd and keepAwake are
 * exposed as aliases since nothing here reads the rest.
 */
Singleton {
    id: root

    property alias dnd: adapter.dnd
    property alias keepAwake: adapter.keepAwake

    FileView {
        id: file
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin/flags.json"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter
            property bool dnd: false
            property bool keepAwake: false
            property bool time12h: false
            property bool clockSeconds: false
            property bool showGlyphs: true
            property bool dynamicPalette: false
            property int recordCountdown: 5
            property string recordDir: ""
            property int recordFps: 60
            property string recordQuality: "high"
            property bool recordCursor: true
            property bool recordMic: true
            property bool recordDesktop: true
            property real recordClearedBefore: 0
        }
    }

    Component.onCompleted: if (!file.loaded)
        file.writeAdapter()
}
