import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io
import "Singletons"

Item {
    id: batteryRoot
    property real s: 1

    property int percentage: 0
    property bool charging: false
    
    readonly property bool hovered: area.containsMouse

    implicitWidth: row.implicitWidth
    implicitHeight: 17 * s

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6 * s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: batteryRoot.percentage + "%"
            color: batteryRoot.hovered ? Theme.cream : Theme.iconDim
            font.family: Theme.font
            font.pixelSize: 11.5 * s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            opacity: 0.82
            Behavior on color { ColorAnimation { duration: 100 } }
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
                border.color: batteryRoot.hovered ? Theme.cream : Theme.dim
                opacity: 0.82
                Behavior on border.color { ColorAnimation { duration: 100 } }

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
                color: batteryRoot.hovered ? Theme.cream : Theme.dim
                opacity: 0.82
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            // Lightning bolt icon when charging
            GlyphIcon {
                id: boltGlyph
                anchors.centerIn: parent
                width: 12 * s
                height: 12 * s
                name: "bolt"
                color: Theme.vermLit
                visible: batteryRoot.charging
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
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
