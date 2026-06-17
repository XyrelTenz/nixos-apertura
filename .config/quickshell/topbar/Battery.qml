import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io
import "Singletons"

Row {
    id: batteryRoot
    spacing: 6 * s
    property real s: 1

    property int percentage: 0
    property bool charging: false

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: batteryRoot.percentage + "%"
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: 11.5 * s
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        opacity: 0.82
    }

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 22 * s
        height: 12 * s

        // Outer body
        Rectangle {
            id: batteryBody
            anchors.fill: parent
            anchors.rightMargin: 2 * s
            radius: 3 * s
            color: "transparent"
            border.width: 1.2 * s
            border.color: Theme.dim
            opacity: 0.82

            // Inner fill
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 2 * s
                anchors.top: parent.top
                anchors.topMargin: 2 * s
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2 * s
                width: Math.max(1, (batteryBody.width - 4 * s) * (batteryRoot.percentage / 100.0))
                radius: 1.5 * s
                color: batteryRoot.percentage < 20 ? Theme.vermLit : Theme.cream
            }
        }

        // Battery tip
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 1.5 * s
            height: 4 * s
            radius: 1 * s
            color: Theme.dim
            opacity: 0.82
        }

        // Lightning bolt icon when charging
        Image {
            id: boltGlyph
            anchors.centerIn: parent
            width: 12 * s
            height: 12 * s
            source: Qt.resolvedUrl("assets/icons/bolt.svg")
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            visible: false
        }

        MultiEffect {
            anchors.fill: boltGlyph
            source: boltGlyph
            colorization: 1.0
            colorizationColor: Theme.vermLit
            visible: batteryRoot.charging
        }
    }

    Process {
        id: reader
        command: ["sh", "-c", "dev=$(ls /sys/class/power_supply | grep BAT | head -n1); [ -n \"$dev\" ] || exit 0; cat /sys/class/power_supply/$dev/capacity && cat /sys/class/power_supply/$dev/status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                if (lines.length >= 2) {
                    batteryRoot.percentage = parseInt(lines[0], 10);
                    batteryRoot.charging = (lines[1].trim() === "Charging");
                }
            }
        }
    }

    Timer {
        interval: 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: reader.running = true
    }
}
