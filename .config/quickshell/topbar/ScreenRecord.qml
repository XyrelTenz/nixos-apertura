import QtQuick
import Quickshell.Io
import "Singletons"

Item {
    id: recordRoot
    property real s: 1

    implicitWidth: 28 * s
    implicitHeight: 28 * s

    property bool active: false

    Rectangle {
        id: hover
        anchors.fill: parent
        radius: 7 * s
        color: Theme.sheen
        opacity: area.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    // A record icon: a camera or a filled circle
    Rectangle {
        id: outerCircle
        anchors.centerIn: parent
        width: 14 * s
        height: 14 * s
        radius: 7 * s
        color: "transparent"
        border.width: 1.5 * s
        border.color: recordRoot.active ? Theme.vermLit : Theme.cream
        opacity: recordRoot.active ? 1 : 0.82

        Rectangle {
            id: innerDot
            anchors.centerIn: parent
            width: 6 * s
            height: 6 * s
            radius: 3 * s
            color: Theme.vermLit
            visible: recordRoot.active
            
            // Pulsing animation when recording
            SequentialAnimation on opacity {
                running: recordRoot.active
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (recordRoot.active) {
                stopRecord.running = true;
            } else {
                startRecord.running = true;
            }
        }
    }

    Process {
        id: checkStatus
        command: ["pgrep", "-x", "wf-recorder"]
        running: false
        onExited: (exitCode, exitStatus) => {
            recordRoot.active = (exitCode === 0);
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: checkStatus.running = true
    }

    Process {
        id: startRecord
        command: ["sh", "-c", "mkdir -p /home/xyreltenz/Videos/ScreenRecord && wf-recorder -f /home/xyreltenz/Videos/ScreenRecord/recording_$(date +%Y-%m-%d_%H-%M-%S).mp4 >/dev/null 2>&1 & notify-send \"Screen Recorder\" \"Recording started. Saving to ~/Videos/ScreenRecord/\" -i media-record"]
        running: false
        onExited: (code) => {
            checkStatus.running = true;
        }
    }

    Process {
        id: stopRecord
        command: ["sh", "-c", "pkill -INT wf-recorder && notify-send \"Screen Recorder\" \"Recording saved to ~/Videos/ScreenRecord/\" -i media-record"]
        running: false
        onExited: (code) => {
            checkStatus.running = true;
        }
    }
}
