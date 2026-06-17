import QtQuick
import Quickshell.Io
import "Singletons"

Item {
    id: recordRoot
    property real s: 1

    implicitWidth: 17 * s
    implicitHeight: 17 * s

    property bool active: false
    readonly property bool hovered: area.containsMouse

    GlyphIcon {
        id: icon
        anchors.fill: parent
        name: "video"
        color: recordRoot.active 
            ? Theme.vermLit 
            : (recordRoot.hovered ? Theme.cream : Theme.iconDim)
        stroke: 1.7
    }

    // A small pulsing red recording dot in the corner if recording
    Rectangle {
        visible: recordRoot.active
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -1 * s
        anchors.rightMargin: -1 * s
        width: 5 * s
        height: 5 * s
        radius: width / 2
        color: Theme.vermLit
        
        SequentialAnimation on opacity {
            running: recordRoot.active
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6 * s
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
