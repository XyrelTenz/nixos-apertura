import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../.."

Item {
    id: wifiViewRoot
    Layout.fillWidth: true
    Layout.fillHeight: true

    signal backClicked

    property string selectedSsid: ""
    property bool enteringPassword: false
    property bool showingForgetConfirm: false

    property bool hasWifiCard: false
    property int signalStrength: 0
    property string ssid: "Disconnected"
    property bool wifiEnabled: true
    property bool active: false
    readonly property bool isScanning: networkScanner.running

    onActiveChanged: {
        if (active) {
            triggerScan();
        }
    }

    onSsidChanged: {
        for (let i = 0; i < wifiNetworksModel.count; i++) {
            let item = wifiNetworksModel.get(i);
            if (item) {
                item.isActive = (item.ssidName === ssid && ssid !== "Disconnected");
            }
        }
    }

    Timer {
        interval: 4000
        running: wifiViewRoot.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (wifiViewRoot.wifiEnabled && wifiViewRoot.hasWifiCard) {
                statusWatcher.running = false;
                statusWatcher.running = true;
            }
        }
    }

    Process {
        id: hardwareCheck
        command: ["sh", "-c", "if [ -d /sys/class/net ] && expr \"$(ls -d /sys/class/net/*/wireless 2>/dev/null)\" : '.*wireless' >/dev/null; then exit 0; else exit 1; fi"]
        running: true
        onExited: code => {
            if (code === 0) {
                wifiViewRoot.hasWifiCard = true;
                statusWatcher.running = true;
            } else {
                wifiViewRoot.hasWifiCard = false;
                statusWatcher.running = false;
            }
        }
    }

    Process {
        id: statusWatcher
        command: ["nmcli", "-t", "-f", "ACTIVE,SIGNAL,SSID", "dev", "wifi", "list", "--rescan", "no"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!wifiViewRoot.hasWifiCard)
                    return;
                let lines = text.split('\n');
                let foundActive = false;
                for (let line of lines) {
                    let parts = line.split(':');
                    if (parts.length >= 3 && parts[0] === "yes") {
                        wifiViewRoot.signalStrength = parseInt(parts[1]) || 0;
                        wifiViewRoot.ssid = parts[2];
                        foundActive = true;
                        break;
                    }
                }
                if (!foundActive) {
                    wifiViewRoot.signalStrength = 0;
                    wifiViewRoot.ssid = "Disconnected";
                }
            }
        }
    }

    ListModel {
        id: wifiNetworksModel
    }

    Process {
        id: networkScanner
        command: ["nmcli", "-t", "-f", "SSID,SECURITY,BARS,ACTIVE", "dev", "wifi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!wifiViewRoot.hasWifiCard)
                    return;
                wifiNetworksModel.clear();
                let lines = text.split('\n');
                let seenSsids = new Set();
                for (let line of lines) {
                    if (!line.trim())
                        continue;
                    let parts = line.split(':');
                    if (parts.length >= 4 && parts[0].length > 0) {
                        let ssidName = parts[0];
                        let isActive = parts[3] === "yes";
                        if (seenSsids.has(ssidName) && !isActive)
                            continue;
                        if (isActive && seenSsids.has(ssidName)) {
                            for (let i = 0; i < wifiNetworksModel.count; i++) {
                                if (wifiNetworksModel.get(i).ssidName === ssidName) {
                                    wifiNetworksModel.remove(i);
                                    break;
                                }
                            }
                        }
                        seenSsids.add(ssidName);
                        wifiNetworksModel.append({
                            "ssidName": ssidName,
                            "secured": parts[1] !== "" && parts[1] !== "--",
                            "bars": parts[2],
                            "isActive": isActive
                        });
                    }
                }
            }
        }
    }

    Process {
        id: nmcActionExecutor
        command: []
        running: false
        onExited: {
            wifiViewRoot.triggerScan();
        }
    }

    function barsToInt(b) {
        if (b === "▂▄▆█")
            return 4;
        if (b === "▂▄▆_")
            return 3;
        if (b === "▂▄__")
            return 2;
        return 1;
    }

    function triggerScan() {
        if (!wifiViewRoot.wifiEnabled || !wifiViewRoot.hasWifiCard)
            return;
        networkScanner.running = true;
        statusWatcher.running = true;
    }

    function forgetNetwork(targetSsid) {
        nmcActionExecutor.command = ["nmcli", "connection", "delete", targetSsid];
        nmcActionExecutor.running = true;
        wifiViewRoot.showingForgetConfirm = false;
        triggerScan();
    }

    function connectToNetwork(targetSsid, password) {
        nmcActionExecutor.command = password !== "" ? ["nmcli", "dev", "wifi", "connect", targetSsid, "password", password] : ["nmcli", "dev", "wifi", "connect", targetSsid];
        nmcActionExecutor.running = true;
        wifiViewRoot.enteringPassword = false;
        triggerScan();
    }

    component SignalBars: Row {
        property int strength: 0
        property color activeColor: "#1D9E75"
        spacing: 2

        Repeater {
            model: 4
            delegate: Rectangle {
                width: 3
                height: 4 + index * 3
                radius: 1
                anchors.bottom: parent ? parent.bottom : undefined
                color: (index < Math.ceil(strength / 25)) ? activeColor : Qt.rgba(1, 1, 1, 0.15)
            }
        }
    }

    component CustomSwitch: Rectangle {
        id: sw
        width: 44
        height: 24
        radius: 12
        color: checked ? (rootScope.theme ? rootScope.theme.theme_primary : "#378ADD") : Qt.rgba(1, 1, 1, 0.15)
        property bool checked: false
        signal toggled

        Rectangle {
            width: 18
            height: 18
            radius: 9
            color: sw.checked ? (rootScope.theme ? rootScope.theme.theme_onPrimary : "white") : "white"
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? parent.width - width - 3 : 3
            Behavior on x {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.InOutQuad
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled()
        }
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: wifiViewRoot.enteringPassword ? 1 : (wifiViewRoot.showingForgetConfirm ? 2 : 0)

        ColumnLayout {
            spacing: 12
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: backBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 0.5

                    Text {
                        anchors.centerIn: parent
                        text: "arrow_back"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 16
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: backBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wifiViewRoot.backClicked()
                    }
                }

                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: wifiViewRoot.wifiEnabled ? Qt.rgba(55 / 255, 138 / 255, 221 / 255, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                        Text {
                            anchors.centerIn: parent
                            text: wifiViewRoot.wifiEnabled ? "wifi" : "wifi_off"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 18
                            color: wifiViewRoot.wifiEnabled ? (rootScope.theme ? rootScope.theme.theme_primary : "#378ADD") : "#a6adc8"
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "Wi-Fi"
                            font.family: "Rubik"
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: "#ffffff"
                        }
                        Text {
                            text: wifiViewRoot.wifiEnabled ? (wifiViewRoot.ssid !== "Disconnected" ? wifiViewRoot.ssid : "On") : "Off"
                            font.family: "Rubik"
                            font.pixelSize: 11
                            color: "#a6adc8"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                CustomSwitch {
                    checked: wifiViewRoot.wifiEnabled
                    onToggled: {
                        wifiViewRoot.wifiEnabled = !wifiViewRoot.wifiEnabled;
                        if (wifiViewRoot.wifiEnabled)
                            triggerScan();
                    }
                }
            }

            ListView {
                id: wifiList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: wifiNetworksModel
                boundsBehavior: Flickable.DragOverBounds

                onMovementEnded: {
                    if (contentY < -60) {
                        wifiViewRoot.triggerScan();
                    }
                }

                Rectangle {
                    id: refreshIndicator
                    width: parent.width
                    height: 40
                    color: "transparent"
                    y: -height - 10
                    visible: wifiList.contentY < 0
                    z: 10

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: "sync"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 14
                            color: "#a6adc8"
                            RotationAnimator on rotation {
                                running: wifiList.contentY < -60 || wifiViewRoot.isScanning
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 1000
                            }
                        }
                        Text {
                            text: wifiList.contentY < -60 ? "Release to refresh..." : "Pull down to refresh"
                            font.family: "Rubik"
                            font.pixelSize: 11
                            color: "#a6adc8"
                        }
                    }
                }

                delegate: Rectangle {
                    width: wifiList.width
                    height: 44
                    radius: 8
                    color: netMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            text: model.isActive ? "check" : (model.secured ? "lock" : "wifi")
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 16
                            color: model.isActive ? (rootScope.theme ? rootScope.theme.theme_primary : "#378ADD") : "#a6adc8"
                        }

                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true

                            Text {
                                text: model.ssidName
                                font.family: "Rubik"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: model.isActive ? (rootScope.theme ? rootScope.theme.theme_primary : "#378ADD") : "#ffffff"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: model.isActive ? "Connected" : (model.secured ? "Secured" : "Open")
                                font.family: "Rubik"
                                font.pixelSize: 9
                                color: model.isActive ? "#1D9E75" : "#a6adc8"
                            }
                        }

                        SignalBars {
                            strength: wifiViewRoot.barsToInt(model.bars) * 25
                            activeColor: model.isActive ? (rootScope.theme ? rootScope.theme.theme_primary : "#378ADD") : "#a6adc8"
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: netMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton && model.isActive) {
                                wifiViewRoot.selectedSsid = model.ssidName;
                                wifiViewRoot.showingForgetConfirm = true;
                            } else {
                                if (model.secured && !model.isActive) {
                                    wifiViewRoot.selectedSsid = model.ssidName;
                                    wifiViewRoot.enteringPassword = true;
                                } else {
                                    connectToNetwork(model.ssidName, "");
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: wifiList.count === 0 && wifiViewRoot.wifiEnabled
                    anchors.centerIn: parent
                    text: "Scanning for networks..."
                    font.family: "Rubik"
                    font.pixelSize: 11
                    color: "#a6adc8"
                }

                Text {
                    visible: !wifiViewRoot.wifiEnabled
                    anchors.centerIn: parent
                    text: "Wi-Fi is turned off"
                    font.family: "Rubik"
                    font.pixelSize: 11
                    color: "#a6adc8"
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 38
                color: "transparent"

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "settings"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 14
                        color: "#a6adc8"
                    }
                    Text {
                        text: "Wi-Fi Settings"
                        font.family: "Rubik"
                        font.pixelSize: 12
                        color: "#a6adc8"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (wifiViewRoot.hasWifiCard) {
                            ccRoot.closeMenu();
                            Quickshell.execDetached(["nm-connection-editor"]);
                        }
                    }
                }
            }
        }

        ColumnLayout {
            spacing: 12
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: backBtnMousePassword.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 0.5

                    Text {
                        anchors.centerIn: parent
                        text: "arrow_back"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 16
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: backBtnMousePassword
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            wifiViewRoot.enteringPassword = false;
                            passwordInput.text = "";
                        }
                    }
                }

                Text {
                    text: "Connect to Wi-Fi"
                    font.family: "Rubik"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: "#ffffff"
                    Layout.fillWidth: true
                }
            }

            ColumnLayout {
                spacing: 8
                Layout.fillWidth: true
                Layout.topMargin: 12

                Text {
                    text: wifiViewRoot.selectedSsid
                    font.family: "Rubik"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: "#ffffff"
                }

                Text {
                    text: "Password Required"
                    font.family: "Rubik"
                    font.pixelSize: 11
                    color: "#a6adc8"
                }

                TextField {
                    id: passwordInput
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    placeholderText: "Enter password"
                    echoMode: TextInput.Password
                    font.family: "Rubik"
                    font.pixelSize: 12
                    color: "#ffffff"
                    placeholderTextColor: "#a6adc8"
                    background: Rectangle {
                        height: 38
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.color: passwordInput.activeFocus ? (rootScope.theme ? rootScope.theme.theme_primary : "#378ADD") : Qt.rgba(1, 1, 1, 0.1)
                        border.width: 1
                    }

                    onAccepted: {
                        connectToNetwork(wifiViewRoot.selectedSsid, text);
                        text = "";
                    }
                }
            }

            RowLayout {
                spacing: 8
                Layout.fillWidth: true
                Layout.topMargin: 12

                Button {
                    Layout.fillWidth: true
                    text: "Cancel"
                    onClicked: {
                        wifiViewRoot.enteringPassword = false;
                        passwordInput.text = "";
                    }
                    background: Rectangle {
                        height: 36
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#ffffff"
                        font.family: "Rubik"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: "Connect"
                    onClicked: {
                        connectToNetwork(wifiViewRoot.selectedSsid, passwordInput.text);
                        passwordInput.text = "";
                    }
                    background: Rectangle {
                        height: 36
                        radius: 8
                        color: rootScope.theme ? rootScope.theme.theme_primary : "#378ADD"
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#ffffff"
                        font.family: "Rubik"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }

        ColumnLayout {
            spacing: 12
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: backBtnMouseForget.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 0.5

                    Text {
                        anchors.centerIn: parent
                        text: "arrow_back"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 16
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: backBtnMouseForget
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wifiViewRoot.showingForgetConfirm = false
                    }
                }

                Text {
                    text: "Forget Network?"
                    font.family: "Rubik"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: "#ffffff"
                    Layout.fillWidth: true
                }
            }

            Text {
                text: "Are you sure you want to forget " + wifiViewRoot.selectedSsid + "?"
                font.family: "Rubik"
                font.pixelSize: 12
                color: "#a6adc8"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 8
                Layout.fillWidth: true
                Layout.topMargin: 12

                Button {
                    Layout.fillWidth: true
                    text: "Cancel"
                    onClicked: wifiViewRoot.showingForgetConfirm = false
                    background: Rectangle {
                        height: 36
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#ffffff"
                        font.family: "Rubik"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: "Forget"
                    onClicked: forgetNetwork(wifiViewRoot.selectedSsid)
                    background: Rectangle {
                        height: 36
                        radius: 8
                        color: "#ff5555"
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#ffffff"
                        font.family: "Rubik"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
