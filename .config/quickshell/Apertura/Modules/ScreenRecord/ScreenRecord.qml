import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import QtCore
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../.."

//TODO: Fix audio not start
Item {
    id: recordRoot

    implicitWidth: 32
    implicitHeight: 32

    property bool isRecording: false
    property int recordingDuration: 0
    property bool recordAudio: false
    property bool highQualityFps: false
    property bool isLoaded: false

    function saveSettings() {
        if (!isLoaded)
            return;
        let data = {
            "recordAudio": recordRoot.recordAudio,
            "highQualityFps": recordRoot.highQualityFps
        };
        Quickshell.execDetached(["sh", "-c", "mkdir -p ~/.cache/quickshell && echo '" + JSON.stringify(data) + "' > " + Quickshell.env("HOME") + "/.cache/quickshell/recorder_settings.json"]);
    }

    onRecordAudioChanged: saveSettings()
    onHighQualityFpsChanged: saveSettings()

    FileView {
        id: settingsReader
        path: Quickshell.env("HOME") + "/.cache/quickshell/recorder_settings.json"
        preload: true
        onTextChanged: {
            let raw = text();
            if (raw && raw.trim() !== "") {
                try {
                    let parsed = JSON.parse(raw);
                    if (parsed.recordAudio !== undefined)
                        recordRoot.recordAudio = parsed.recordAudio;
                    if (parsed.highQualityFps !== undefined)
                        recordRoot.highQualityFps = parsed.highQualityFps;
                } catch (e) {}
            }
            recordRoot.isLoaded = true;
        }
    }

    Timer {
        id: osdAutohideTimer
        interval: Config.autohideInterval
        running: false
        repeat: false
        onTriggered: drawerTemplate.isOpen = false
    }

    function checkUserActivity() {
        if (iconMouseArea.containsMouse || cardHoverTracker.containsMouse) {
            osdAutohideTimer.stop();
        } else {
            osdAutohideTimer.restart();
        }
    }

    Process {
        id: recordingChecker
        command: ["sh", "-c", "pgrep -x wf-recorder >/dev/null && echo 'true' || echo 'false'"]
        running: false
        stdout: StdioCollector {
            onTextChanged: {
                let active = text.trim() === "true";
                if (recordRoot.isRecording !== active) {
                    recordRoot.isRecording = active;
                }
            }
        }
    }

    Timer {
        id: checkTimer
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            recordingChecker.running = false;
            recordingChecker.running = true;
        }
    }

    Timer {
        id: durationTimer
        interval: 1000
        running: recordRoot.isRecording
        repeat: true
        onTriggered: {
            recordRoot.recordingDuration += 1;
            if (recordRoot.recordingDuration % 20 === 0) {
                Quickshell.execDetached(["notify-send", "-t", "3000", "-a", "Screen Recorder", "-i", "media-record", "Screen Recording", "Recording is ongoing... (" + formatDuration(recordRoot.recordingDuration) + ")"]);
            }
        }
        onRunningChanged: {
            if (!running) {
                recordRoot.recordingDuration = 0;
            }
        }
    }

    function formatDuration(sec) {
        let m = Math.floor(sec / 60);
        let s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/Videos/ScreenRecord"]);
    }

    Rectangle {
        id: recordHitbox
        anchors.fill: parent
        color: "transparent"
        radius: 0

        Text {
            anchors.centerIn: parent
            text: recordRoot.isRecording ? "fiber_manual_record" : "videocam"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 20
            color: recordRoot.isRecording ? "#ff5555" : (rootScope.theme ? rootScope.theme.theme_fg : "#ffffff")

            SequentialAnimation on opacity {
                running: recordRoot.isRecording
                loops: Animation.Infinite
                NumberAnimation {
                    from: 1.0
                    to: 0.4
                    duration: 800
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    from: 0.4
                    to: 1.0
                    duration: 800
                    easing.type: Easing.InOutQuad
                }
            }
        }

        Rectangle {
            id: recordHoverOverlay
            anchors.fill: parent
            radius: 0
            color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
            opacity: iconMouseArea.containsMouse ? 0.3 : 0.0
            z: 1
        }

        MouseArea {
            id: iconMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: drawerTemplate.isOpen = !drawerTemplate.isOpen
            onContainsMouseChanged: checkUserActivity()
        }
    }

    PanelDrawer {
        id: drawerTemplate
        isOpen: false
        drawerHeight: 350
        modalToken: "screenrecord"
        anchorTop: false

        onIsOpenChanged: {
            if (isOpen) {
                checkUserActivity();
                mainContainerLayout.forceActiveFocus();
            }
        }

        MouseArea {
            id: cardHoverTracker
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: checkUserActivity()
            onPressed: mouse => {
                mouse.accepted = true;
                checkUserActivity();
            }
        }

        ColumnLayout {
            id: mainContainerLayout
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    drawerTemplate.isOpen = false;
                    event.accepted = true;
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Screen Recorder"
                    font.family: "Rubik"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                    Layout.alignment: Qt.AlignVCenter
                }
                Item {
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Layout.topMargin: 4
                Layout.bottomMargin: 4

                Rectangle {
                    id: recBtn
                    width: 44
                    height: 44
                    radius: 22
                    color: recordRoot.isRecording ? "#22ff5555" : (recBtnMouse.containsMouse ? "#22ffffff" : "transparent")
                    border.color: recordRoot.isRecording ? "#ff5555" : (rootScope.theme ? rootScope.theme.theme_fg : "#ffffff")
                    border.width: 2

                    Rectangle {
                        width: recordRoot.isRecording ? 16 : 20
                        height: recordRoot.isRecording ? 16 : 20
                        radius: recordRoot.isRecording ? 3 : 10
                        color: "#ff5555"
                        anchors.centerIn: parent

                        Behavior on radius {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                        Behavior on width {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                        Behavior on height {
                            NumberAnimation {
                                duration: 150
                            }
                        }

                        SequentialAnimation on opacity {
                            running: recordRoot.isRecording
                            loops: Animation.Infinite
                            NumberAnimation {
                                from: 1.0
                                to: 0.4
                                duration: 800
                                easing.type: Easing.InOutQuad
                            }
                            NumberAnimation {
                                from: 0.4
                                to: 1.0
                                duration: 800
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }

                    MouseArea {
                        id: recBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!recordRoot.isRecording) {
                                let recordMsg = "Recording Started" + (recordRoot.recordAudio ? " with Audio" : "");
                                Quickshell.execDetached(["notify-send", "-a", "Screen Recorder", "-i", "media-record", recordMsg, "Saving to ~/Videos/ScreenRecord"]);

                                let cmd = "mkdir -p ~/Videos/ScreenRecord && wf-recorder";
                                if (recordRoot.recordAudio) {
                                    cmd += " -a";
                                }
                                if (recordRoot.highQualityFps) {
                                    cmd += " -r 60";
                                }
                                cmd += " -f ~/Videos/ScreenRecord/recording_$(date +%Y%m%d_%H%M%S).mp4";

                                Quickshell.execDetached(["sh", "-c", cmd]);
                                recordRoot.isRecording = true;
                            } else {
                                Quickshell.execDetached(["pkill", "-INT", "wf-recorder"]);
                                Quickshell.execDetached(["notify-send", "-a", "Screen Recorder", "-i", "media-record", "Recording Stopped", "Saved to ~/Videos/ScreenRecord"]);
                                recordRoot.isRecording = false;
                            }
                            checkUserActivity();
                        }
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: recordRoot.isRecording ? "Recording Screen..." : "Ready to record"
                        font.family: "Rubik"
                        font.pixelSize: 12
                        font.bold: true
                        color: recordRoot.isRecording ? "#ff5555" : (rootScope.theme ? rootScope.theme.theme_fg : "#ffffff")
                    }
                    Text {
                        text: recordRoot.isRecording ? formatDuration(recordRoot.recordingDuration) : "Store: ~/Videos/ScreenRecord"
                        font.family: "Rubik"
                        font.pixelSize: 10
                        color: rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff"
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
            }

            Text {
                text: "Recent Recordings"
                font.family: "Rubik"
                font.pixelSize: 12
                font.bold: true
                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
            }

            FolderListModel {
                id: folderModel
                folder: "file://" + Quickshell.env("HOME") + "/Videos/ScreenRecord"
                nameFilters: ["*.mp4", "*.mkv", "*.mov", "*.webm"]
                showDirs: false
                sortField: FolderListModel.Time
                sortReversed: true
            }

            ListView {
                id: videoListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 120
                clip: true
                model: folderModel
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    width: videoListView.width
                    height: 32
                    color: itemMouseArea.containsMouse ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : "transparent"
                    radius: 4

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: "movie"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 16
                            color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                        }

                        Text {
                            text: model.fileName
                            font.family: "Rubik"
                            font.pixelSize: 11
                            color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                        }

                        Rectangle {
                            width: 24
                            height: 24
                            radius: 4
                            color: deleteMouse.containsMouse ? "#33ff5555" : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "delete"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 16
                                color: deleteMouse.containsMouse ? "#ff5555" : (rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff")
                            }

                            MouseArea {
                                id: deleteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["rm", "-f", model.filePath]);
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: itemMouseArea
                        anchors.fill: parent
                        anchors.rightMargin: 30
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["xdg-open", model.filePath]);
                        }
                    }
                }

                Text {
                    visible: folderModel.count === 0
                    anchors.centerIn: parent
                    text: "No recordings found"
                    font.family: "Rubik"
                    font.pixelSize: 11
                    color: rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff"
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Settings"
                    font.family: "Rubik"
                    font.pixelSize: 11
                    font.bold: true
                    color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Record Audio (Mic)"
                        font.family: "Rubik"
                        font.pixelSize: 11
                        color: recordRoot.recordAudio ? (rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa") : (rootScope.theme ? Qt.alpha(rootScope.theme.theme_fg, 0.4) : "#40ffffff")
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        width: 30
                        height: 16
                        radius: 8
                        color: recordRoot.recordAudio ? (rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa") : (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff")
                        opacity: recordRoot.isRecording ? 0.5 : 1.0
                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            color: recordRoot.recordAudio ? (rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b") : "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            x: recordRoot.recordAudio ? 16 : 2
                            Behavior on x {
                                NumberAnimation {
                                    duration: 120
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: recordRoot.isRecording ? Qt.ArrowCursor : Qt.PointingHandCursor
                            enabled: !recordRoot.isRecording
                            onClicked: {
                                recordRoot.recordAudio = !recordRoot.recordAudio;
                                checkUserActivity();
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "High Quality (60 FPS)"
                        font.family: "Rubik"
                        font.pixelSize: 11
                        color: recordRoot.highQualityFps ? (rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa") : (rootScope.theme ? Qt.alpha(rootScope.theme.theme_fg, 0.4) : "#40ffffff")
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        width: 30
                        height: 16
                        radius: 8
                        color: recordRoot.highQualityFps ? (rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa") : (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff")
                        opacity: recordRoot.isRecording ? 0.5 : 1.0
                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            color: recordRoot.highQualityFps ? (rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b") : "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            x: recordRoot.highQualityFps ? 16 : 2
                            Behavior on x {
                                NumberAnimation {
                                    duration: 120
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: recordRoot.isRecording ? Qt.ArrowCursor : Qt.PointingHandCursor
                            enabled: !recordRoot.isRecording
                            onClicked: {
                                recordRoot.highQualityFps = !recordRoot.highQualityFps;
                                checkUserActivity();
                            }
                        }
                    }
                }
            }
        }
    }
}
