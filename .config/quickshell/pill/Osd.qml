import QtQuick
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Io
import "Singletons"

Item {
    id: root

    property real s: 1
    property bool suppressed: false
    property bool flashing: false
    property string kind: "volume"
    property bool armed: false
    property string shownTrackLine: ""
    property bool shownPlaying: false
    property string shownArtUrl: ""
    property string lastTrackLine: ""
    property bool lastPlaying: false
    property int batteryPercentage: 0
    property bool batteryCharging: false
    property string batteryStatus: ""
    property bool recordActive: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property real volume: sink && sink.audio ? Math.max(0, Math.min(1, sink.audio.volume)) : 0
    property real brightness: 0.5

    property var stickyPlayer: null
    readonly property var player: {
        var list = Mpris.players.values;
        if (!list || list.length === 0)
            return null;
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].isPlaying)
                return list[i];
        }
        if (stickyPlayer && list.indexOf(stickyPlayer) >= 0)
            return stickyPlayer;
        return list[0];
    }
    readonly property bool playing: player !== null && player.isPlaying
    readonly property string trackLine: {
        if (!player)
            return "";
        var t = player.trackTitle ? player.trackTitle : "";
        var a = Theme.joinArtists(player.trackArtists, player.trackArtist);
        return a.length > 0 ? t + " — " + a : t;
    }

    readonly property real desiredW: kind === "track" ? 332 * s : 248 * s
    readonly property real desiredH: kind === "track" ? 56 * s : 44 * s

    function trackEvent() {
        var line = trackLine;
        var p = playing;
        if (line === lastTrackLine && p === lastPlaying)
            return;
        lastTrackLine = line;
        lastPlaying = p;
        flash("track");
    }

    function flash(which) {
        if (!armed || suppressed || cooldownTimer.running)
            return;
        if (which === "track") {
            shownTrackLine = trackLine;
            shownPlaying = playing;
            shownArtUrl = player && player.trackArtUrl ? player.trackArtUrl : "";
        }
        kind = which;
        flashing = true;
        hideTimer.interval = (which === "battery" || which === "record") ? 2000 : 1400;
        hideTimer.restart();
    }

    function triggerRecordOsd(active) {
        recordActive = active;
        flash("record");
    }

    onSuppressedChanged: {
        if (suppressed) {
            hideTimer.stop();
            flashing = false;
        } else {
            cooldownTimer.restart();
        }
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: root.armed = true
    }

    Timer {
        id: hideTimer
        interval: 1400
        onTriggered: root.flashing = false
    }

    Timer {
        id: cooldownTimer
        interval: 200
    }

    PwObjectTracker {
        objects: [root.sink].filter(Boolean)
    }

    Connections {
        target: root.sink && root.sink.audio ? root.sink.audio : null
        function onVolumesChanged() { root.flash("volume"); }
        function onMutedChanged() { root.flash("volume"); }
    }

    Process {
        id: brightMonitor
        command: ["sh", "-c", "dev=$(ls /sys/class/backlight | head -n1); [ -n \"$dev\" ] || exit 0; max=$(cat /sys/class/backlight/$dev/max_brightness); last=\"\"; while true; do val=$(cat /sys/class/backlight/$dev/brightness); if [ \"$val\" != \"$last\" ]; then echo \"$(( val * 100 / max ))\"; last=\"$val\"; fi; sleep 0.15; done"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                var pct = parseInt(line.trim(), 10);
                if (!isNaN(pct)) {
                    root.brightness = Math.max(0, Math.min(100, pct)) / 100.0;
                    root.flash("brightness");
                }
            }
        }
    }

    onPlayerChanged: {
        Qt.callLater(function() {
            if (stickyPlayer !== player)
                stickyPlayer = player;
        });
        trackEvent();
    }

    Connections {
        target: root.player
        function onTrackTitleChanged() { root.trackEvent(); }
        function onPlaybackStateChanged() { root.trackEvent(); }
    }

    Item {
        id: volRow
        anchors.fill: parent
        opacity: root.kind === "volume" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        GlyphIcon {
            id: volGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 17 * root.s
            height: 17 * root.s
            name: root.muted ? "speaker-off" : "speaker"
            color: root.muted ? Theme.dim : Theme.iconDim
            stroke: 1.7
        }

        Text {
            id: volPct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 32 * root.s
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.volume * 100) + "%"
            color: root.muted ? Theme.dim : Theme.cream
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Rectangle {
            anchors.left: volGlyph.right
            anchors.leftMargin: 12 * root.s
            anchors.right: volPct.left
            anchors.rightMargin: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            height: 4 * root.s
            radius: 2 * root.s
            color: Theme.threadBg

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.volume
                radius: parent.radius
                color: root.muted ? Theme.vermDim : Theme.vermLit
                Behavior on width { NumberAnimation { duration: Motion.fast } }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
        }
    }

    Item {
        id: brightRow
        anchors.fill: parent
        opacity: root.kind === "brightness" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        GlyphIcon {
            id: brightGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 17 * root.s
            height: 17 * root.s
            name: "sun"
            color: Theme.iconDim
            stroke: 1.7
        }

        Text {
            id: brightPct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 32 * root.s
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.brightness * 100) + "%"
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Rectangle {
            anchors.left: brightGlyph.right
            anchors.leftMargin: 12 * root.s
            anchors.right: brightPct.left
            anchors.rightMargin: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            height: 4 * root.s
            radius: 2 * root.s
            color: Theme.threadBg

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.brightness
                radius: parent.radius
                color: Theme.vermLit
                Behavior on width { NumberAnimation { duration: Motion.fast } }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
        }
    }

    Item {
        id: trackRow
        anchors.fill: parent
        opacity: root.kind === "track" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        ClippingRectangle {
            id: coverBox
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 30 * root.s
            height: 30 * root.s
            radius: 8 * root.s
            color: Theme.tileBg

            Image {
                id: cover
                anchors.fill: parent
                source: root.shownArtUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: status === Image.Ready && root.shownArtUrl !== ""
            }
            GlyphIcon {
                anchors.centerIn: parent
                width: parent.width * 0.45
                height: width
                name: "music"
                color: Theme.subtle
                visible: !cover.visible
            }
        }

        GlyphIcon {
            id: trackGlyph
            anchors.left: coverBox.right
            anchors.leftMargin: 11 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * root.s
            height: 16 * root.s
            name: root.shownPlaying ? "play-s" : "pause-s"
            color: Theme.iconDim
            stroke: 1.7
        }

        Text {
            anchors.left: trackGlyph.right
            anchors.leftMargin: 10 * root.s
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.shownTrackLine
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11.5 * root.s
            font.weight: Font.DemiBold
            maximumLineCount: 1
            elide: Text.ElideRight
        }
    }

    Item {
        id: batteryRow
        anchors.fill: parent
        opacity: root.kind === "battery" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        GlyphIcon {
            id: batteryGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 17 * root.s
            height: 17 * root.s
            name: "bolt"
            color: Theme.vermLit
            stroke: 1.7
        }

        Text {
            id: batteryPct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 50 * root.s
            horizontalAlignment: Text.AlignRight
            text: root.batteryPercentage + "%"
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Rectangle {
            anchors.left: batteryGlyph.right
            anchors.leftMargin: 12 * root.s
            anchors.right: batteryPct.left
            anchors.rightMargin: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            height: 4 * root.s
            radius: 2 * root.s
            color: Theme.threadBg

            Rectangle {
                id: fillBar
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * (root.batteryPercentage / 100.0)
                radius: parent.radius
                color: Theme.vermLit
                Behavior on width { NumberAnimation { duration: Motion.fast } }

                // Moving sheen overlay to simulate charging fluid flow
                Rectangle {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 30 * root.s
                    color: "transparent"
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#00ffffff" }
                        GradientStop { position: 0.5; color: "#40ffffff" }
                        GradientStop { position: 1.0; color: "#00ffffff" }
                    }

                    // Animate x position from left to right continuously while charging
                    NumberAnimation on x {
                        from: -30 * root.s
                        to: fillBar.width
                        duration: 1200
                        loops: Animation.Infinite
                        running: root.batteryCharging && root.kind === "battery"
                    }
                }
            }
        }
    }

    Item {
        id: recordRow
        anchors.fill: parent
        opacity: root.kind === "record" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Rectangle {
            id: recordGlyphOuter
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * root.s
            height: 16 * root.s
            radius: 8 * root.s
            color: "transparent"
            border.width: 1.5 * root.s
            border.color: root.recordActive ? Theme.vermLit : Theme.dim

            Rectangle {
                anchors.centerIn: parent
                width: 8 * root.s
                height: 8 * root.s
                radius: 4 * root.s
                color: root.recordActive ? Theme.vermLit : Theme.dim

                // Pulsing animation if recording
                SequentialAnimation on opacity {
                    running: root.recordActive && root.kind === "record"
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                }
            }
        }

        Text {
            anchors.left: recordGlyphOuter.right
            anchors.leftMargin: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            text: root.recordActive ? "Recording Started" : "Recording Stopped"
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11.5 * root.s
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.recordActive ? "REC" : "SAVED"
            color: root.recordActive ? Theme.vermLit : Theme.dim
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1 * root.s
        }
    }

    Process {
        id: batteryMonitor
        command: ["sh", "-c", "dev=$(ls /sys/class/power_supply | grep BAT | head -n1); [ -n \"$dev\" ] || exit 0; last_status=\"\"; last_cap=\"\"; while true; do status=$(cat /sys/class/power_supply/$dev/status); cap=$(cat /sys/class/power_supply/$dev/capacity); if [ \"$status\" != \"$last_status\" ] || [ \"$cap\" != \"$last_cap\" ]; then echo \"$cap|$status\"; last_status=\"$status\"; last_cap=\"$cap\"; fi; sleep 1.0; done"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                var parts = line.trim().split("|");
                if (parts.length === 2) {
                    var cap = parseInt(parts[0], 10);
                    var status = parts[1].trim();
                    var wasCharging = root.batteryCharging;
                    root.batteryPercentage = cap;
                    root.batteryCharging = (status === "Charging");
                    root.batteryStatus = status;
                    
                    // Flash OSD if charging status transitioned to true (plugged in)
                    if (root.batteryCharging && !wasCharging && root.armed) {
                        root.flash("battery");
                    }
                }
            }
        }
    }
}
