import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../.."

Item {
    id: audioRoot
    implicitWidth: 32
    implicitHeight: 32

    property real speakerVol: 0.0
    property bool isMuted: false
    property real micVol: 0.0
    property bool micMuted: false

    property string activeTab: "speaker" // "speaker", "mic", "devices"
    property bool menuOpen: false

    Binding {
        target: rootScope
        property: "audioSliderActive"
        value: globalVolumeSlider.pressed
    }

    Timer {
        interval: 400
        running: true
        repeat: true
        onTriggered: {
            if (!globalVolumeSlider.pressed) {
                syncVolumeQuery.running = false;
                syncVolumeQuery.running = true;
            }
            syncMicQuery.running = false;
            syncMicQuery.running = true;

            if (drawerTemplate.isOpen) {
                syncDevicesQuery.running = false;
                syncDevicesQuery.running = true;
            }
        }
    }

    Process {
        id: syncVolumeQuery
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                try {
                    let cleaned = text.trim();
                    if (cleaned.startsWith("Volume:")) {
                        audioRoot.isMuted = cleaned.includes("[MUTED]");
                        let parts = cleaned.split(" ");
                        if (parts.length >= 2) {
                            let volVal = parseFloat(parts[1]);
                            if (!isNaN(volVal)) {
                                audioRoot.speakerVol = volVal;
                                if (audioRoot.activeTab === "speaker" && !globalVolumeSlider.pressed) {
                                    if (Math.abs(globalVolumeSlider.value - volVal) > 0.01) {
                                        globalVolumeSlider.value = volVal;
                                    }
                                }
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: syncMicQuery
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        running: false
        stdout: StdioCollector {
            onTextChanged: {
                try {
                    let cleaned = text.trim();
                    if (cleaned.startsWith("Volume:")) {
                        audioRoot.micMuted = cleaned.includes("[MUTED]");
                        let parts = cleaned.split(" ");
                        if (parts.length >= 2) {
                            let volVal = parseFloat(parts[1]);
                            if (!isNaN(volVal)) {
                                audioRoot.micVol = volVal;
                                if (audioRoot.activeTab === "mic" && !globalVolumeSlider.pressed) {
                                    if (Math.abs(globalVolumeSlider.value - volVal) > 0.01) {
                                        globalVolumeSlider.value = volVal;
                                    }
                                }
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: syncDevicesQuery
        command: ["wpctl", "status"]
        running: false
        stdout: StdioCollector {
            onTextChanged: {
                try {
                    let lines = text.split("\n");
                    let parsingSinks = false;
                    let currentSinks = [];

                    for (let i = 0; i < lines.length; i++) {
                        let line = lines[i];

                        if (line.includes("Sinks:")) {
                            parsingSinks = true;
                            continue;
                        }

                        if (parsingSinks && (line.includes("Sources:") || line.includes("Filters:") || line.includes("Streams:"))) {
                            parsingSinks = false;
                        }

                        if (parsingSinks) {
                            let match = line.match(/(\*\s*)?\s*(\d+)\.\s+(.*)/);
                            if (match) {
                                let isActive = (match[1] !== undefined && match[1].includes("*"));
                                let devId = match[2].trim();
                                let rawName = match[3].trim();
                                let cleanName = rawName.split("[")[0].trim();

                                currentSinks.push({
                                    "devId": devId,
                                    "name": cleanName,
                                    "active": isActive
                                });
                            }
                        }
                    }

                    for (let m = 0; m < currentSinks.length; m++) {
                        let found = false;
                        for (let n = 0; n < deviceListModel.count; n++) {
                            if (deviceListModel.get(n).devId === currentSinks[m].devId) {
                                found = true;
                                if (deviceListModel.get(n).active !== currentSinks[m].active) {
                                    deviceListModel.setProperty(n, "active", currentSinks[m].active);
                                }
                                if (deviceListModel.get(n).name !== currentSinks[m].name) {
                                    deviceListModel.setProperty(n, "name", currentSinks[m].name);
                                }
                                break;
                            }
                        }
                        if (!found) {
                            deviceListModel.append(currentSinks[m]);
                        }
                    }

                    for (let k = deviceListModel.count - 1; k >= 0; k--) {
                        let keep = false;
                        for (let j = 0; j < currentSinks.length; j++) {
                            if (currentSinks[j].devId === deviceListModel.get(k).devId) {
                                keep = true;
                                break;
                            }
                        }
                        if (!keep) {
                            deviceListModel.remove(k);
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: changeDeviceProcess
        running: false
        function switchSink(sinkId) {
            command = ["wpctl", "set-default", sinkId];
            running = true;
        }
    }

    Process {
        id: adjustVolume
        running: false
        function adjust(tab, val) {
            let target = tab === "mic" ? "@DEFAULT_AUDIO_SOURCE@" : "@DEFAULT_AUDIO_SINK@";
            command = ["wpctl", "set-volume", target, val.toFixed(2)];
            running = true;
        }
    }

    Process {
        id: toggleMuteProcess
        running: false
        function toggle(tab) {
            let target = tab === "mic" ? "@DEFAULT_AUDIO_SOURCE@" : "@DEFAULT_AUDIO_SINK@";
            command = ["wpctl", "set-mute", target, "toggle"];
            running = true;
        }
    }

    Timer {
        id: osdAutohideTimer
        interval: 2000
        running: false
        repeat: false
        onTriggered: closeMenu()
    }

    function toggleMenu(): void {
        drawerTemplate.isOpen = !drawerTemplate.isOpen;
    }

    function closeMenu(): void {
        drawerTemplate.isOpen = false;
    }

    function checkUserActivity() {
        if (globalVolumeSlider.pressed || cardHoverTracker.containsMouse || volumeMouseArea.containsMouse) {
            osdAutohideTimer.stop(); 
        } else {
            osdAutohideTimer.restart(); 
        }
    }

    ListModel {
        id: deviceListModel
    }

    function getActiveSinkName() {
        for (let i = 0; i < deviceListModel.count; i++) {
            if (deviceListModel.get(i).active) {
                return deviceListModel.get(i).name;
            }
        }
        return "Default Audio Controller";
    }

    onActiveTabChanged: {
        if (activeTab === "speaker") {
            globalVolumeSlider.value = audioRoot.speakerVol;
        } else if (activeTab === "mic") {
            globalVolumeSlider.value = audioRoot.micVol;
        }
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== drawerTemplate.modalToken && drawerTemplate.isOpen) {
                closeMenu();
            }
        }
    }

    Rectangle {
        id: volumeHitbox
        anchors.fill: parent
        color: "transparent"
        radius: 0

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Text {
                id: volumeIcon
                Layout.alignment: Qt.AlignHCenter
                text: (audioRoot.isMuted || audioRoot.speakerVol <= 0.01) ? "volume_off" : (audioRoot.speakerVol > 0.50 ? "volume_up" : "volume_down")
                font.family: "Material Symbols Outlined"
                font.pixelSize: 24
                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" 
            }
        }

        Rectangle {
            id: audioHoverOverlay
            anchors.fill: parent
            radius: 0
            color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
            opacity: volumeMouseArea.containsMouse ? 0.3 : 0.0
            z: 1
        }

        MouseArea {
            id: volumeMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
            onContainsMouseChanged: {
                if (containsMouse) {
                    drawerTemplate.isOpen = true;
                }
                checkUserActivity();
            }
            onWheel: (wheel) => {
                let delta = wheel.angleDelta.y;
                let step = 0.02;
                if (audioRoot.activeTab === "mic") {
                    let newVal = audioRoot.micVol + (delta > 0 ? step : -step);
                    audioRoot.micVol = Math.max(0.0, Math.min(1.0, newVal));
                    adjustVolume.adjust("mic", audioRoot.micVol);
                    if (globalVolumeSlider.activeFocus || globalVolumeSlider.visible) {
                        globalVolumeSlider.value = audioRoot.micVol;
                    }
                } else {
                    let newVal = audioRoot.speakerVol + (delta > 0 ? step : -step);
                    audioRoot.speakerVol = Math.max(0.0, Math.min(1.0, newVal));
                    adjustVolume.adjust("speaker", audioRoot.speakerVol);
                    if (globalVolumeSlider.activeFocus || globalVolumeSlider.visible) {
                        globalVolumeSlider.value = audioRoot.speakerVol;
                    }
                }
                checkUserActivity();
                wheel.accepted = true;
            }
        }
    }

    PanelDrawer {
        id: drawerTemplate
        isOpen: false
        drawerWidth: 240
        drawerHeight: 240
        modalToken: "audio"
        anchorTop: false
        anchorRight: true

        onIsOpenChanged: {
            if (isOpen) {
                syncDevicesQuery.running = false;
                syncDevicesQuery.running = true;
                checkUserActivity();
            } else {
                audioRoot.menuOpen = false;
            }
        }

        MouseArea {
            id: cardHoverTracker
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: checkUserActivity()
            onPressed: (mouse) => { mouse.accepted = true; checkUserActivity(); }
        }

        component TabButton : Rectangle {
            id: tabBtn
            property string tabName: ""
            property string iconName: ""
            property bool isSelected: audioRoot.activeTab === tabName

            width: 32
            height: 48
            radius: 16
            color: isSelected ? (rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa") : "transparent"

            Text {
                anchors.centerIn: parent
                text: tabBtn.iconName
                font.family: "Material Symbols Outlined"
                font.pixelSize: 18
                color: tabBtn.isSelected 
                    ? (rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b") 
                    : (tabMouse.containsMouse ? "#ffffff" : (rootScope.theme ? rootScope.theme.theme_outline : "#80ffffff"))
            }

            MouseArea {
                id: tabMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    audioRoot.activeTab = tabBtn.tabName;
                    checkUserActivity();
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 0

            // Left Main content
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: audioRoot.activeTab === "devices" ? 1 : 0

                    // SLIDER VIEW (Speaker or Mic)
                    ColumnLayout {
                        spacing: 4

                        Text {
                            text: Math.round(globalVolumeSlider.value * 100) + "%"
                            font.family: "Rubik"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Slider {
                            id: globalVolumeSlider
                            Layout.preferredHeight: 110
                            Layout.preferredWidth: 32
                            Layout.alignment: Qt.AlignHCenter
                            orientation: Qt.Vertical
                            from: 0.0
                            to: 1.0

                            onPressedChanged: checkUserActivity()
                            onMoved: {
                                adjustVolume.adjust(audioRoot.activeTab, value);
                                checkUserActivity();
                            }

                            background: Rectangle {
                                implicitWidth: 14
                                implicitHeight: 110
                                radius: 7
                                color: "#20ffffff"
                                x: globalVolumeSlider.width / 2 - width / 2
                                y: 0

                                Rectangle {
                                    width: parent.width
                                    height: (1.0 - globalVolumeSlider.visualPosition) * parent.height
                                    color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa" 
                                    radius: 7
                                    anchors.bottom: parent.bottom
                                }
                            }

                            handle: Rectangle {
                                width: 18
                                height: 18
                                radius: 9
                                color: "#ffffff"
                                border.color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
                                border.width: 1.5
                                x: globalVolumeSlider.width / 2 - width / 2
                                y: globalVolumeSlider.visualPosition * (globalVolumeSlider.availableHeight - height)
                            }
                        }

                        // Mute button
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 76
                            height: 24
                            radius: 12
                            color: (audioRoot.activeTab === "mic" ? audioRoot.micMuted : audioRoot.isMuted) ? "#40ff5555" : "#20ffffff"
                            border.color: (audioRoot.activeTab === "mic" ? audioRoot.micMuted : audioRoot.isMuted) ? "#ff5555" : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: audioRoot.activeTab === "mic" ? "mic_off" : "volume_off"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 12
                                    color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                                }
                                Text {
                                    text: "Mute"
                                    font.family: "Rubik"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    toggleMuteProcess.toggle(audioRoot.activeTab);
                                    if (audioRoot.activeTab === "mic") {
                                        syncMicQuery.running = false;
                                        syncMicQuery.running = true;
                                    } else {
                                        syncVolumeQuery.running = false;
                                        syncVolumeQuery.running = true;
                                    }
                                    checkUserActivity();
                                }
                            }
                        }
                    }

                    // DEVICE LIST VIEW
                    ColumnLayout {
                        spacing: 4

                        Text {
                            text: "Outputs"
                            font.family: "Rubik"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: rootScope.theme ? rootScope.theme.theme_outline : "#20ffffff"
                            border.width: 1
                            radius: 6
                            clip: true

                            ListView {
                                id: deviceListView
                                anchors.fill: parent
                                anchors.margins: 4
                                model: deviceListModel
                                spacing: 4

                                delegate: Rectangle {
                                    width: deviceListView.width
                                    height: 28
                                    radius: 4
                                    color: active ? (rootScope.theme ? rootScope.theme.theme_outline : "#40ffffff") : (devMouse.containsMouse ? "#10ffffff" : "transparent")

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        spacing: 6

                                        Rectangle {
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: active ? (rootScope.theme ? rootScope.theme.theme_primary : "#ffffff") : "transparent"
                                        }

                                        Text {
                                            text: name
                                            font.family: "Rubik"
                                            font.pixelSize: 10
                                            color: active ? (rootScope.theme ? rootScope.theme.theme_primary : "#ffffff") : (rootScope.theme ? rootScope.theme.theme_fg : "#a0ffffff")
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    MouseArea {
                                        id: devMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            changeDeviceProcess.switchSink(devId);
                                            syncDevicesQuery.running = false;
                                            syncDevicesQuery.running = true;
                                            checkUserActivity();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Active device name at the very bottom
                Text {
                    text: audioRoot.activeTab === "mic" ? "Default Mic Source" : getActiveSinkName()
                    font.family: "Rubik"
                    font.pixelSize: 9
                    color: rootScope.theme ? rootScope.theme.theme_outline : "#80ffffff"
                    Layout.alignment: Qt.AlignHCenter
                    elide: Text.ElideRight
                    Layout.maximumWidth: 160
                }
            }

            // Separator vertical line
            Rectangle {
                Layout.fillHeight: true
                width: 1
                color: rootScope.theme ? rootScope.theme.theme_outline : "#20ffffff"
                Layout.leftMargin: 4
                Layout.rightMargin: 4
            }

            // Right Sidebar (tabs)
            ColumnLayout {
                Layout.preferredWidth: 36
                Layout.fillHeight: true
                spacing: 12

                Item { Layout.fillHeight: true }

                TabButton {
                    tabName: "speaker"
                    iconName: "volume_up"
                }

                TabButton {
                    tabName: "mic"
                    iconName: "mic"
                }

                TabButton {
                    tabName: "devices"
                    iconName: "speaker_group"
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
