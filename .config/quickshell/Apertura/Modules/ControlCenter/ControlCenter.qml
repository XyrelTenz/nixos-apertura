import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import "../.."
import "Wifi"
import "Bluetooth"
import "Power"

Item {
    id: ccRoot
    width: 0
    height: 0

    property bool menuOpen: false
    property bool caffeineEnabled: false

    property var notificationItem: null
    property var sysMonitorItem: null

    property real currentVol: 0.0
    property bool isMuted: false
    property bool nightLightActive: false

    Timer {
        interval: 1000
        running: drawerTemplate.isOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!volumeSlider.pressed) {
                syncVolumeQuery.running = false;
                syncVolumeQuery.running = true;
            }
        }
    }

    Process {
        id: syncVolumeQuery
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: false
        stdout: StdioCollector {
            onTextChanged: {
                try {
                    let cleaned = text.trim();
                    if (cleaned.startsWith("Volume:")) {
                        isMuted = cleaned.includes("[MUTED]");
                        let parts = cleaned.split(" ");
                        if (parts.length >= 2) {
                            let volVal = parseFloat(parts[1]);
                            if (!isNaN(volVal) && !volumeSlider.pressed) {
                                ccRoot.currentVol = volVal;
                                volumeSlider.value = volVal;
                            }
                        }
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: adjustVolume
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", volumeSlider.value.toFixed(2)]
        running: false
    }

    Process {
        id: toggleMuteProcess
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        running: false
        onExited: code => {
            syncVolumeQuery.running = false;
            syncVolumeQuery.running = true;
        }
    }

    Process {
        id: toggleNightLight
        command: ["sh", "-c", ccRoot.nightLightActive ? "pkill -f 'gammastep|wlsunset' || true; gammastep -O 4000 -l 0:0 &" : "pkill -f 'gammastep|wlsunset' || true"]
        running: false
    }

    property bool volumeChangePending: false
    Timer {
        id: volumeThrottleTimer
        interval: 100
        repeat: false
        running: false
        onTriggered: {
            if (volumeChangePending) {
                adjustVolume.running = false;
                adjustVolume.running = true;
                volumeChangePending = false;
                volumeThrottleTimer.start();
            }
        }
    }

    property real currentBrightness: 0

    Timer {
        interval: 1000
        running: drawerTemplate.isOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!brightnessSlider.pressed) {
                syncBrightnessQuery.running = false;
                syncBrightnessQuery.running = true;
            }
        }
    }

    Process {
        id: syncBrightnessQuery
        command: ["brightnessctl", "-m"]
        running: false
        stdout: StdioCollector {
            onTextChanged: {
                try {
                    let cleaned = text.trim();
                    let lines = cleaned.split("\n");
                    if (lines.length > 0) {
                        let parts = lines[0].split(",");
                        if (parts.length >= 5) {
                            let pctStr = parts[4].replace("%", "");
                            let pctVal = parseInt(pctStr);
                            if (!isNaN(pctVal) && !brightnessSlider.pressed) {
                                ccRoot.currentBrightness = pctVal;
                                brightnessSlider.value = pctVal / 100.0;
                            }
                        }
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: adjustBrightness
        command: ["brightnessctl", "set", Math.round(brightnessSlider.value * 100) + "%"]
        running: false
    }

    property bool brightnessChangePending: false
    Timer {
        id: brightnessThrottleTimer
        interval: 100
        repeat: false
        running: false
        onTriggered: {
            if (brightnessChangePending) {
                adjustBrightness.running = false;
                adjustBrightness.running = true;
                brightnessChangePending = false;
                brightnessThrottleTimer.start();
            }
        }
    }

    Process {
        id: caffeineProcess
        command: ["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=Caffeine", "sleep", "infinity"]
        running: false
    }

    onCaffeineEnabledChanged: {
        if (caffeineEnabled) {
            caffeineProcess.running = true;
        } else {
            caffeineProcess.running = false;
            Quickshell.execDetached(["pkill", "-f", "systemd-inhibit --what=idle --who=quickshell"]);
        }
    }

    property var activePlayer: null

    function updateActivePlayer() {
        let playersList = Mpris.players.values;
        if (!playersList || playersList.length === 0) {
            activePlayer = null;
            return;
        }

        for (let i = 0; i < playersList.length; i++) {
            let p = playersList[i];
            if (p && p.playbackState === MprisPlaybackState.Playing) {
                activePlayer = p;
                return;
            }
        }

        if (activePlayer) {
            for (let i = 0; i < playersList.length; i++) {
                if (playersList[i] === activePlayer) {
                    return;
                }
            }
        }

        activePlayer = playersList[0];
    }

    Timer {
        id: mprisSyncTimer
        interval: 500
        running: drawerTemplate.isOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: ccRoot.updateActivePlayer()
    }

    property date currentDateTime: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: ccRoot.currentDateTime = new Date()
    }

    function toggleMenu(): void {
        drawerTemplate.isOpen = !drawerTemplate.isOpen;
    }

    function closeMenu(): void {
        drawerTemplate.isOpen = false;
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== drawerTemplate.modalToken && drawerTemplate.isOpen) {
                closeMenu();
            }
        }
    }

    component CircularProgress: Canvas {
        id: canvas
        width: 54
        height: 54
        property real value: 0.0 // 0.0 to 1.0
        property color progressColor: "#378ADD"
        property color bgColor: Qt.rgba(1, 1, 1, 0.08)

        onValueChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var centerX = width / 2;
            var centerY = height / 2;
            var radius = Math.min(width, height) / 2 - 3;

            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI, false);
            ctx.lineWidth = 3.5;
            ctx.strokeStyle = bgColor;
            ctx.stroke();

            ctx.beginPath();
            var startAngle = -Math.PI / 2;
            var endAngle = startAngle + (value * 2 * Math.PI);
            ctx.arc(centerX, centerY, radius, startAngle, endAngle, false);
            ctx.lineWidth = 3.5;
            ctx.strokeStyle = progressColor;
            ctx.stroke();
        }
    }

    PanelDrawer {
        id: drawerTemplate
        isOpen: false
        drawerHeight: 700
        drawerWidth: 350
        modalToken: "controlcenter"
        anchorTop: false

        onIsOpenChanged: {
            if (isOpen) {
                ccRoot.menuOpen = true;
                rootScope.requestOpen(modalToken);
                mainContainerLayout.forceActiveFocus();
                ccStackLayout.currentIndex = 0;
            } else {
                ccRoot.menuOpen = false;
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            clip: true

            Item {
                id: ccStackLayout
                anchors.fill: parent
                property int currentIndex: 0

                Item {
                    id: mainDashboardView
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width
                    visible: opacity > 0.01
                    opacity: ccStackLayout.currentIndex === 0 ? 1.0 : 0.0
                    x: ccStackLayout.currentIndex === 0 ? 0 : -parent.width
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutQuad
                        }
                    }
                    Behavior on x {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }

                    ColumnLayout {
                        id: mainContainerLayout
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12
                        focus: true

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 4

                            ColumnLayout {
                                spacing: 2
                                Text {
                                    text: Qt.formatDateTime(ccRoot.currentDateTime, "H:mm")
                                    font.family: "Rubik"
                                    font.pixelSize: 34
                                    font.weight: Font.Bold
                                    color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                                }
                                Text {
                                    text: Qt.formatDateTime(ccRoot.currentDateTime, "dddd, MMMM d")
                                    font.family: "Rubik"
                                    font.pixelSize: 12
                                    color: "#a6adc8"
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                spacing: 8

                                HeaderButton {
                                    iconName: "settings"
                                    onClicked: {
                                        drawerTemplate.isOpen = false;
                                        Quickshell.execDetached(["systemsettings"]);
                                    }
                                }

                                HeaderButton {
                                    iconName: "menu"
                                    onClicked: {
                                        drawerTemplate.isOpen = false;
                                        appLauncherItem.toggleMenu();
                                    }
                                }

                                HeaderButton {
                                    iconName: "power_settings_new"
                                    onClicked: {
                                        ccStackLayout.currentIndex = 3;
                                    }
                                }
                            }
                        }

                        GridLayout {
                            columns: 2
                            columnSpacing: 10
                            rowSpacing: 10
                            Layout.fillWidth: true

                            Rectangle {
                                Layout.fillWidth: true
                                height: 48
                                radius: 24
                                color: wifiView.wifiEnabled ? (rootScope.theme ? rootScope.theme.theme_outline : "#378ADD") : Qt.rgba(1, 1, 1, 0.05)
                                border.color: Qt.rgba(1, 1, 1, 0.08)
                                border.width: 0.5

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: wifiView.wifiEnabled ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                                        Text {
                                            anchors.centerIn: parent
                                            text: wifiView.wifiEnabled ? "wifi" : "wifi_off"
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 15
                                            color: wifiView.wifiEnabled ? "#ffffff" : "#a6adc8"
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 1
                                        Layout.fillWidth: true
                                        Text {
                                            text: "Wi-Fi"
                                            font.family: "Rubik"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: wifiView.wifiEnabled ? "#ffffff" : "#cdd6f4"
                                        }
                                        Text {
                                            text: wifiView.wifiEnabled ? (wifiView.ssid !== "Disconnected" ? wifiView.ssid : "On") : "Off"
                                            font.family: "Rubik"
                                            font.pixelSize: 9
                                            color: wifiView.wifiEnabled ? "#e6e9ef" : "#a6adc8"
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        ccStackLayout.currentIndex = 1;
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 48
                                radius: 24
                                color: bluetoothView.isPowered ? (rootScope.theme ? rootScope.theme.theme_outline : "#378ADD") : Qt.rgba(1, 1, 1, 0.05)
                                border.color: Qt.rgba(1, 1, 1, 0.08)
                                border.width: 0.5

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: bluetoothView.isPowered ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                                        Text {
                                            anchors.centerIn: parent
                                            text: bluetoothView.isPowered ? "bluetooth" : "bluetooth_disabled"
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 15
                                            color: bluetoothView.isPowered ? "#ffffff" : "#a6adc8"
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 1
                                        Layout.fillWidth: true
                                        Text {
                                            text: "Bluetooth"
                                            font.family: "Rubik"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: bluetoothView.isPowered ? "#ffffff" : "#cdd6f4"
                                        }
                                        Text {
                                            text: bluetoothView.isPowered ? (bluetoothView.isConnected ? "Connected" : "On") : "Off"
                                            font.family: "Rubik"
                                            font.pixelSize: 9
                                            color: bluetoothView.isPowered ? "#e6e9ef" : "#a6adc8"
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        ccStackLayout.currentIndex = 2;
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 48
                                radius: 24
                                color: !rootScope.notificationsEnabled ? (rootScope.theme ? rootScope.theme.theme_outline : "#378ADD") : Qt.rgba(1, 1, 1, 0.05)
                                border.color: Qt.rgba(1, 1, 1, 0.08)
                                border.width: 0.5

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: !rootScope.notificationsEnabled ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                                        Text {
                                            anchors.centerIn: parent
                                            text: !rootScope.notificationsEnabled ? "do_not_disturb_on" : "do_not_disturb_off"
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 15
                                            color: !rootScope.notificationsEnabled ? "#ffffff" : "#a6adc8"
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 1
                                        Layout.fillWidth: true
                                        Text {
                                            text: "Do Not Disturb"
                                            font.family: "Rubik"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: !rootScope.notificationsEnabled ? "#ffffff" : "#cdd6f4"
                                        }
                                        Text {
                                            text: !rootScope.notificationsEnabled ? "On" : "Off"
                                            font.family: "Rubik"
                                            font.pixelSize: 9
                                            color: !rootScope.notificationsEnabled ? "#e6e9ef" : "#a6adc8"
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        rootScope.notificationsEnabled = !rootScope.notificationsEnabled;
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 48
                                radius: 24
                                color: ccRoot.caffeineEnabled ? (rootScope.theme ? rootScope.theme.theme_outline : "#378ADD") : Qt.rgba(1, 1, 1, 0.05)
                                border.color: Qt.rgba(1, 1, 1, 0.08)
                                border.width: 0.5

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: ccRoot.caffeineEnabled ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "local_cafe"
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 15
                                            color: ccRoot.caffeineEnabled ? "#ffffff" : "#a6adc8"
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 1
                                        Layout.fillWidth: true
                                        Text {
                                            text: "Caffeine"
                                            font.family: "Rubik"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: ccRoot.caffeineEnabled ? "#ffffff" : "#cdd6f4"
                                        }
                                        Text {
                                            text: ccRoot.caffeineEnabled ? "On" : "Off"
                                            font.family: "Rubik"
                                            font.pixelSize: 9
                                            color: ccRoot.caffeineEnabled ? "#e6e9ef" : "#a6adc8"
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        ccRoot.caffeineEnabled = !ccRoot.caffeineEnabled;
                                    }
                                }
                            }

                            Rectangle {
                                Layout.columnSpan: 2
                                Layout.fillWidth: true
                                height: 48
                                radius: 24
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.color: Qt.rgba(1, 1, 1, 0.08)
                                border.width: 0.5

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 8

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "screenshot"
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 15
                                            color: "#a6adc8"
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 1
                                        Layout.fillWidth: true
                                        Text {
                                            text: "Screenshot"
                                            font.family: "Rubik"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: "#cdd6f4"
                                        }
                                        Text {
                                            text: "Capture Screen"
                                            font.family: "Rubik"
                                            font.pixelSize: 9
                                            color: "#a6adc8"
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        rootScope.triggerScreenshot();
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Layout.topMargin: 4
                            Layout.bottomMargin: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Slider {
                                    id: volumeSlider
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    from: 0.0
                                    to: 1.0
                                    value: 0.0

                                    onMoved: {
                                        if (!volumeThrottleTimer.running) {
                                            adjustVolume.running = false;
                                            adjustVolume.running = true;
                                            volumeThrottleTimer.start();
                                        } else {
                                            volumeChangePending = true;
                                        }
                                    }

                                    background: Rectangle {
                                        id: volTrack
                                        height: 36
                                        radius: 18
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                        width: volumeSlider.availableWidth
                                        x: volumeSlider.leftPadding
                                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                        clip: true

                                        Rectangle {
                                            height: parent.height
                                            width: volumeSlider.visualPosition * parent.width
                                            color: rootScope.theme ? rootScope.theme.theme_primary : "#378ADD"
                                            radius: 18
                                        }

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: (ccRoot.isMuted || ccRoot.currentVol <= 0.01) ? "\ue04f" : (ccRoot.currentVol > 0.50 ? "\ue050" : "\ue04d")
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 18
                                            color: (volumeSlider.visualPosition * parent.width > 32) ? (rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b") : "#ffffff"
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Math.round(volumeSlider.value * 100) + "%"
                                            font.family: "Rubik"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: (volumeSlider.visualPosition * parent.width > parent.width - 40) ? (rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b") : "#cdd6f4"
                                        }

                                        MouseArea {
                                            anchors.top: volumeSlider.top
                                            anchors.bottom: volumeSlider.bottom
                                            x: 0
                                            width: parent.width
                                            preventStealing: true

                                            function updateValue(mouse) {
                                                let val = volumeSlider.from + (mouse.x / width) * (volumeSlider.to - volumeSlider.from);
                                                volumeSlider.value = Math.max(volumeSlider.from, Math.min(volumeSlider.to, val));
                                                volumeSlider.moved();
                                            }

                                            onPressed: mouse => updateValue(mouse)
                                            onPositionChanged: mouse => {
                                                if (pressed)
                                                    updateValue(mouse);
                                            }
                                        }
                                    }

                                    handle: Item {
                                        width: 0
                                        height: 0
                                    }
                                }

                                Rectangle {
                                    width: 36
                                    height: 36
                                    radius: 18
                                    color: ccRoot.isMuted ? "#ff5555" : Qt.rgba(1, 1, 1, 0.08)
                                    border.color: Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 0.5

                                    Text {
                                        anchors.centerIn: parent
                                        text: ccRoot.isMuted ? "\ue04f" : "\ue050"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 18
                                        color: "#ffffff"
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            toggleMuteProcess.running = false;
                                            toggleMuteProcess.running = true;
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Slider {
                                    id: brightnessSlider
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    from: 0.05
                                    to: 1.0
                                    value: 0.5

                                    onMoved: {
                                        if (!brightnessThrottleTimer.running) {
                                            adjustBrightness.running = false;
                                            adjustBrightness.running = true;
                                            brightnessThrottleTimer.start();
                                        } else {
                                            brightnessChangePending = true;
                                        }
                                    }

                                    background: Rectangle {
                                        id: brightTrack
                                        height: 36
                                        radius: 18
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                        width: brightnessSlider.availableWidth
                                        x: brightnessSlider.leftPadding
                                        y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                                        clip: true

                                        Rectangle {
                                            height: parent.height
                                            width: brightnessSlider.visualPosition * parent.width
                                            color: rootScope.theme ? rootScope.theme.theme_primary : "#378ADD"
                                            radius: 18
                                        }

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: brightnessSlider.value > 0.5 ? "\ue1ac" : "\ue1ad"
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 18
                                            color: (brightnessSlider.visualPosition * parent.width > 32) ? (rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b") : "#ffffff"
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Math.round(brightnessSlider.value * 100) + "%"
                                            font.family: "Rubik"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: (brightnessSlider.visualPosition * parent.width > parent.width - 40) ? (rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b") : "#cdd6f4"
                                        }

                                        MouseArea {
                                            anchors.top: brightnessSlider.top
                                            anchors.bottom: brightnessSlider.bottom
                                            x: 0
                                            width: parent.width
                                            preventStealing: true

                                            function updateValue(mouse) {
                                                let val = brightnessSlider.from + (mouse.x / width) * (brightnessSlider.to - brightnessSlider.from);
                                                brightnessSlider.value = Math.max(brightnessSlider.from, Math.min(brightnessSlider.to, val));
                                                brightnessSlider.moved();
                                            }

                                            onPressed: mouse => updateValue(mouse)
                                            onPositionChanged: mouse => {
                                                if (pressed)
                                                    updateValue(mouse);
                                            }
                                        }
                                    }

                                    handle: Item {
                                        width: 0
                                        height: 0
                                    }
                                }

                                Rectangle {
                                    width: 36
                                    height: 36
                                    radius: 18
                                    color: ccRoot.nightLightActive ? "#378ADD" : Qt.rgba(1, 1, 1, 0.08)
                                    border.color: Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 0.5

                                    Text {
                                        anchors.centerIn: parent
                                        text: ccRoot.nightLightActive ? "\uf1ac" : "\uf1ad"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 18
                                        color: "#ffffff"
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            ccRoot.nightLightActive = !ccRoot.nightLightActive;
                                            toggleNightLight.running = false;
                                            toggleNightLight.running = true;
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 78
                            radius: 16
                            color: Qt.rgba(1, 1, 1, 0.03)
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 0.5

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 0

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 4

                                    Item {
                                        Layout.preferredWidth: 54
                                        Layout.preferredHeight: 54
                                        Layout.alignment: Qt.AlignHCenter

                                        CircularProgress {
                                            anchors.centerIn: parent
                                            value: (sysMonitorItem ? sysMonitorItem.cpuPercent : 0) / 100.0
                                            progressColor: "#378ADD"
                                        }

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 0
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: (sysMonitorItem ? sysMonitorItem.cpuPercent : 0) + "%"
                                                font.family: "Rubik"
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                color: "#ffffff"
                                            }
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: "CPU"
                                                font.family: "Rubik"
                                                font.pixelSize: 8
                                                color: "#a6adc8"
                                            }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 4

                                    Item {
                                        Layout.preferredWidth: 54
                                        Layout.preferredHeight: 54
                                        Layout.alignment: Qt.AlignHCenter

                                        CircularProgress {
                                            anchors.centerIn: parent
                                            value: (sysMonitorItem ? sysMonitorItem.ramPercent : 0) / 100.0
                                            progressColor: "#a6e3a1"
                                        }

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 0
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: (sysMonitorItem ? sysMonitorItem.ramPercent : 0) + "%"
                                                font.family: "Rubik"
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                color: "#ffffff"
                                            }
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: "RAM"
                                                font.family: "Rubik"
                                                font.pixelSize: 8
                                                color: "#a6adc8"
                                            }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 4

                                    Item {
                                        Layout.preferredWidth: 54
                                        Layout.preferredHeight: 54
                                        Layout.alignment: Qt.AlignHCenter

                                        CircularProgress {
                                            anchors.centerIn: parent
                                            value: (sysMonitorItem ? sysMonitorItem.diskPercent : 0) / 100.0
                                            progressColor: "#f9e2af"
                                        }

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 0
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: (sysMonitorItem ? sysMonitorItem.diskPercent : 0) + "%"
                                                font.family: "Rubik"
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                color: "#ffffff"
                                            }
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: "Disk"
                                                font.family: "Rubik"
                                                font.pixelSize: 8
                                                color: "#a6adc8"
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 72
                            radius: 16
                            color: "#000000"
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 0.5
                            visible: ccRoot.activePlayer !== null

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Rectangle {
                                    width: 52
                                    height: 52
                                    radius: 8
                                    color: "#1e1e2e"
                                    clip: true

                                    Image {
                                        id: albumArtImage
                                        anchors.fill: parent
                                        source: (ccRoot.activePlayer && ccRoot.activePlayer.trackArtUrl) ? ccRoot.activePlayer.trackArtUrl : ""
                                        fillMode: Image.PreserveAspectCrop
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "music_note"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 20
                                        color: "#a6adc8"
                                        visible: albumArtImage.status !== Image.Ready
                                    }
                                }

                                ColumnLayout {
                                    spacing: 2
                                    Layout.fillWidth: true

                                    Text {
                                        text: (ccRoot.activePlayer && ccRoot.activePlayer.trackTitle) ? ccRoot.activePlayer.trackTitle : "No Media"
                                        font.family: "Rubik"
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        color: "#ffffff"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: {
                                            if (!ccRoot.activePlayer)
                                                return "";
                                            let artists = ccRoot.activePlayer.trackArtist || ccRoot.activePlayer.trackArtists;
                                            if (Array.isArray(artists))
                                                return artists.join(", ");
                                            return artists || "Unknown Artist";
                                        }
                                        font.family: "Rubik"
                                        font.pixelSize: 10
                                        color: "#a6adc8"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                RowLayout {
                                    spacing: 8

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "skip_previous"
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 18
                                            color: (ccRoot.activePlayer && ccRoot.activePlayer.canGoPrevious) ? "#ffffff" : "#555555"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            enabled: ccRoot.activePlayer && ccRoot.activePlayer.canGoPrevious
                                            onClicked: ccRoot.activePlayer.previous()
                                        }
                                    }

                                    Rectangle {
                                        width: 34
                                        height: 34
                                        radius: 17
                                        color: "#ffffff"
                                        Text {
                                            anchors.centerIn: parent
                                            text: (ccRoot.activePlayer && ccRoot.activePlayer.playbackState === MprisPlaybackState.Playing) ? "pause" : "play_arrow"
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 20
                                            color: "#000000"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (ccRoot.activePlayer) {
                                                    ccRoot.activePlayer.playPause();
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "skip_next"
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 18
                                            color: (ccRoot.activePlayer && ccRoot.activePlayer.canGoNext) ? "#ffffff" : "#555555"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            enabled: ccRoot.activePlayer && ccRoot.activePlayer.canGoNext
                                            onClicked: ccRoot.activePlayer.next()
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Notifications"
                                    font.family: "Rubik"
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: "#ffffff"
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "Clear All"
                                    font.family: "Rubik"
                                    font.pixelSize: 10
                                    color: clearMouse.containsMouse ? (rootScope.theme ? rootScope.theme.theme_primary : "#378ADD") : "#a6adc8"
                                    visible: (rootScope.globalNotificationServer && rootScope.globalNotificationServer.trackedNotifications) ? rootScope.globalNotificationServer.trackedNotifications.rowCount() > 0 : false

                                    MouseArea {
                                        id: clearMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (rootScope.globalNotificationServer) {
                                                try {
                                                    rootScope.globalNotificationServer.clear();
                                                } catch (e) {}
                                                try {
                                                    rootScope.globalNotificationServer.dismissAll();
                                                } catch (e) {}
                                            }
                                        }
                                    }
                                }
                            }

                            ListView {
                                id: notifList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredHeight: count === 0 ? 50 : 100
                                clip: true
                                spacing: 6
                                model: rootScope.globalNotificationServer ? rootScope.globalNotificationServer.trackedNotifications : null

                                delegate: Rectangle {
                                    width: notifList.width
                                    height: 48
                                    radius: 12
                                    color: Qt.rgba(1, 1, 1, 0.03)
                                    border.color: Qt.rgba(1, 1, 1, 0.05)
                                    border.width: 0.5

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        Rectangle {
                                            width: 20
                                            height: 20
                                            radius: 10
                                            color: Qt.rgba(1, 1, 1, 0.05)
                                            Text {
                                                anchors.centerIn: parent
                                                text: "notifications"
                                                font.family: "Material Symbols Outlined"
                                                font.pixelSize: 12
                                                color: "#a6adc8"
                                            }
                                        }

                                        ColumnLayout {
                                            spacing: 1
                                            Layout.fillWidth: true

                                            Text {
                                                text: modelData.summary || "Notification"
                                                font.family: "Rubik"
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: "#ffffff"
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: modelData.body || ""
                                                font.family: "Rubik"
                                                font.pixelSize: 9
                                                color: "#a6adc8"
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                                visible: text !== ""
                                            }
                                        }

                                        Rectangle {
                                            width: 16
                                            height: 16
                                            radius: 8
                                            color: closeMouse.containsMouse ? Qt.rgba(255, 85, 85, 0.15) : "transparent"
                                            Text {
                                                anchors.centerIn: parent
                                                text: "close"
                                                font.family: "Material Symbols Outlined"
                                                font.pixelSize: 12
                                                color: closeMouse.containsMouse ? "#ff5555" : "#a6adc8"
                                            }
                                            MouseArea {
                                                id: closeMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    try {
                                                        modelData.dismiss();
                                                    } catch (e) {}
                                                    if (rootScope.globalNotificationServer) {
                                                        try {
                                                            rootScope.globalNotificationServer.dismiss(modelData.id);
                                                        } catch (e) {}
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: notifList.count === 0
                                    anchors.centerIn: parent
                                    text: "No new notifications"
                                    font.family: "Rubik"
                                    font.pixelSize: 11
                                    color: "#a6adc8"
                                }
                            }
                        }
                    }
                }

                Item {
                    id: wifiViewContainer
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width
                    visible: opacity > 0.01
                    opacity: ccStackLayout.currentIndex === 1 ? 1.0 : 0.0
                    x: ccStackLayout.currentIndex === 1 ? 0 : (ccStackLayout.currentIndex < 1 ? parent.width : -parent.width)
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutQuad
                        }
                    }
                    Behavior on x {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                    WifiView {
                        id: wifiView
                        anchors.fill: parent
                        anchors.margins: 14
                        active: ccRoot.menuOpen
                        onBackClicked: ccStackLayout.currentIndex = 0
                    }
                }

                Item {
                    id: bluetoothViewContainer
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width
                    visible: opacity > 0.01
                    opacity: ccStackLayout.currentIndex === 2 ? 1.0 : 0.0
                    x: ccStackLayout.currentIndex === 2 ? 0 : (ccStackLayout.currentIndex < 2 ? parent.width : -parent.width)
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutQuad
                        }
                    }
                    Behavior on x {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                    BluetoothView {
                        id: bluetoothView
                        anchors.fill: parent
                        anchors.margins: 14
                        active: ccRoot.menuOpen
                        onBackClicked: ccStackLayout.currentIndex = 0
                    }
                }

                Item {
                    id: powerViewContainer
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width
                    visible: opacity > 0.01
                    opacity: ccStackLayout.currentIndex === 3 ? 1.0 : 0.0
                    x: ccStackLayout.currentIndex === 3 ? 0 : parent.width
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutQuad
                        }
                    }
                    Behavior on x {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                    PowerView {
                        anchors.fill: parent
                        anchors.margins: 14
                        onBackClicked: ccStackLayout.currentIndex = 0
                        onActionTriggered: ccRoot.closeMenu()
                    }
                }
            }
        }
    }

    component HeaderButton: Rectangle {
        id: hBtn
        width: 32
        height: 32
        radius: 16
        color: hBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 0.5
        property string iconName: ""
        signal clicked

        Text {
            anchors.centerIn: parent
            text: hBtn.iconName
            font.family: "Material Symbols Outlined"
            font.pixelSize: 16
            color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
        }

        MouseArea {
            id: hBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hBtn.clicked()
        }
    }
}
