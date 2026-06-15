import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../.."

Item {
    id: bluetoothViewRoot
    Layout.fillWidth: true
    Layout.fillHeight: true

    signal backClicked

    property string selectedDeviceMac: ""
    property string selectedDeviceName: ""
    property int selectedDeviceIndex: -1
    property bool showingForgetConfirm: false

    property bool isPowered: false
    property bool isConnected: false
    property string currentTab: "paired"
    property bool isScanning: false
    property bool isEvicting: false
    property bool active: false

    ListModel {
        id: pairedDevicesModel
    }
    ListModel {
        id: discoveredDevicesModel
    }

    function togglePower() {
        if (!bluetoothToggleAction.running) {
            bluetoothToggleAction.running = true;
            bluetoothViewRoot.isPowered = !bluetoothViewRoot.isPowered;
            if (!bluetoothViewRoot.isPowered) {
                pairedDevicesModel.clear();
                discoveredDevicesModel.clear();
            }
        }
    }

    function connectDevice(macAddress, index) {
        if (!deviceConnectionAction.running) {
            pairedDevicesModel.setProperty(index, "isTransitioning", true);
            deviceConnectionAction.command = ["bash", "-c", "bluetoothctl trust " + macAddress + " && bluetoothctl connect " + macAddress];
            deviceConnectionAction.running = true;
        }
    }

    function disconnectDevice(macAddress, index) {
        if (!deviceConnectionAction.running) {
            pairedDevicesModel.setProperty(index, "isDeviceConnected", false);
            deviceConnectionAction.command = ["bash", "-c", "bluetoothctl disconnect " + macAddress];
            deviceConnectionAction.running = true;
        }
    }

    function forgetDevice(macAddress, index) {
        if (!unpairAction.running) {
            bluetoothViewRoot.isEvicting = true;
            unpairAction.command = ["bash", "-c", "bluetoothctl remove " + macAddress];
            unpairAction.running = true;
            pairedDevicesModel.remove(index);
        }
    }

    function pairDevice(macAddress) {
        if (!pairAction.running) {
            pairAction.command = ["bash", "-c", "bluetoothctl pair " + macAddress + " && bluetoothctl trust " + macAddress + " && bluetoothctl connect " + macAddress];
            pairAction.running = true;
        }
    }

    Component.onCompleted: {
        const localUri = Qt.resolvedUrl("../../..").toString();
        const basePath = localUri.replace("file://", "");

        bluetoothWatcher.command = ["bash", basePath + "/Scripts/bluetooth_control.sh", "status"];
        deviceScraper.command = ["bash", basePath + "/Scripts/bluetooth_control.sh", "paired"];
        scanAction.command = ["timeout", "5s", "bash", basePath + "/Scripts/bluetooth_control.sh", "scan"];
        discoveryScraper.command = ["bash", basePath + "/Scripts/bluetooth_control.sh", "discover"];
        bluetoothToggleAction.command = ["bash", basePath + "/Scripts/bluetooth_control.sh", "toggle"];

        bluetoothWatcher.running = true;
    }

    function refreshStatus() {
        if (bluetoothWatcher.command && bluetoothWatcher.command.length > 0 && !bluetoothWatcher.running) {
            bluetoothWatcher.running = true;
        }
    }

    function refreshPairedList() {
        if (!bluetoothViewRoot.isPowered || bluetoothViewRoot.isEvicting)
            return;
        if (deviceScraper.command && deviceScraper.command.length > 0 && !deviceScraper.running) {
            deviceScraper.running = true;
        }
    }

    function refreshDiscoverList() {
        if (!bluetoothViewRoot.isPowered)
            return;
        if (discoveryScraper.command && discoveryScraper.command.length > 0 && !discoveryScraper.running) {
            discoveryScraper.running = true;
        }
    }

    onActiveChanged: {
        if (active) {
            refreshStatus();
            refreshPairedList();
            if (isPowered)
                triggerScan();
        }
    }

    onCurrentTabChanged: {
        if (currentTab === "paired") {
            refreshPairedList();
        } else if (currentTab === "discover") {
            refreshDiscoverList();
        }
    }

    Process {
        id: bluetoothWatcher
        command: ["true"]
        running: false
        onExited: running = false
        stdout: StdioCollector {
            onTextChanged: {
                const cleanText = text.trim();
                if (!cleanText)
                    return;
                try {
                    const state = JSON.parse(cleanText);
                    bluetoothViewRoot.isPowered = state.powered;
                    bluetoothViewRoot.isConnected = state.connected;
                } catch (e) {}
            }
        }
    }

    Process {
        id: deviceScraper
        command: ["true"]
        running: false
        onExited: running = false
        stdout: StdioCollector {
            onTextChanged: {
                if (bluetoothViewRoot.isEvicting)
                    return;
                const rawOutput = text.trim();
                if (!rawOutput)
                    return;

                const lines = rawOutput.split("\n").map(l => l.trim()).filter(l => l.length > 0);
                pairedDevicesModel.clear();

                for (let i = 0; i < lines.length; i++) {
                    const segments = lines[i].split("|");
                    if (segments.length >= 3) {
                        pairedDevicesModel.append({
                            macAddress: segments[0].trim().toLowerCase(),
                            isDeviceConnected: segments[1].trim() === "true",
                            deviceName: segments[2].trim(),
                            isTransitioning: false
                        });
                    }
                }
            }
        }
    }

    Process {
        id: scanAction
        command: ["true"]
        running: false
        onExited: {
            running = false;
            bluetoothViewRoot.isScanning = false;
            refreshDiscoverList();
        }
    }

    Process {
        id: discoveryScraper
        command: ["true"]
        running: false
        onExited: running = false
        stdout: StdioCollector {
            onTextChanged: {
                const rawOutput = text.trim();
                if (!rawOutput)
                    return;

                const lines = rawOutput.split("\n").map(l => l.trim()).filter(l => l.length > 0);

                const pairedMacSet = new Set();
                for (let j = 0; j < pairedDevicesModel.count; j++) {
                    pairedMacSet.add(pairedDevicesModel.get(j).macAddress.toLowerCase());
                }

                discoveredDevicesModel.clear();

                for (let i = 0; i < lines.length; i++) {
                    const segments = lines[i].split("|");
                    if (segments.length >= 2 && segments[1].trim() !== "") {
                        const targetMac = segments[0].trim().toLowerCase();

                        if (pairedMacSet.has(targetMac)) {
                            continue;
                        }

                        discoveredDevicesModel.append({
                            macAddress: targetMac,
                            deviceName: segments[1].trim()
                        });
                    }
                }
            }
        }
    }

    Process {
        id: bluetoothToggleAction
        command: ["true"]
        running: false
        onExited: {
            running = false;
            refreshStatus();
        }
    }
    Process {
        id: deviceConnectionAction
        command: ["true"]
        running: false
        onExited: {
            running = false;
            refreshStatus();
            refreshPairedList();
        }
    }
    Process {
        id: pairAction
        command: ["true"]
        running: false
        onExited: {
            running = false;
            refreshStatus();
            refreshPairedList();
        }
    }

    Process {
        id: unpairAction
        command: ["true"]
        running: false
        onExited: {
            running = false;
            bluetoothViewRoot.isEvicting = false;
            Qt.callLater(() => {
                refreshStatus();
                refreshPairedList();
            });
        }
    }

    function triggerScan() {
        if (!bluetoothViewRoot.isPowered || bluetoothViewRoot.isScanning || !scanAction.command || scanAction.command.length === 0)
            return;
        bluetoothViewRoot.isScanning = true;
        scanAction.running = true;
    }

    Timer {
        id: activeRefreshTimer
        interval: 4000
        running: bluetoothViewRoot.active
        repeat: true
        onTriggered: {
            refreshStatus();
            if (!bluetoothViewRoot.isEvicting) {
                refreshPairedList();
            }
        }
    }

    Timer {
        id: passiveRefreshTimer
        interval: 5000
        running: !bluetoothViewRoot.active
        repeat: true
        onTriggered: refreshStatus()
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
        currentIndex: bluetoothViewRoot.showingForgetConfirm ? 1 : 0

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
                        onClicked: bluetoothViewRoot.backClicked()
                    }
                }

                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: bluetoothViewRoot.isPowered ? Qt.rgba(55 / 255, 138 / 255, 221 / 255, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                        Text {
                            anchors.centerIn: parent
                            text: bluetoothViewRoot.isPowered ? "bluetooth" : "bluetooth_disabled"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 18
                            color: bluetoothViewRoot.isPowered ? (rootScope.theme ? rootScope.theme.theme_primary : "#378ADD") : "#a6adc8"
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "Bluetooth"
                            font.family: "Rubik"
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: "#ffffff"
                        }
                        Text {
                            text: {
                                if (!bluetoothViewRoot.isPowered)
                                    return "Off";
                                if (bluetoothViewRoot.isConnected) {
                                    for (let i = 0; i < pairedDevicesModel.count; i++) {
                                        let item = pairedDevicesModel.get(i);
                                        if (item && item.isDeviceConnected) {
                                            return item.deviceName || "Connected";
                                        }
                                    }
                                    return "Connected";
                                }
                                return "On";
                            }
                            font.family: "Rubik"
                            font.pixelSize: 11
                            color: "#a6adc8"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                CustomSwitch {
                    checked: bluetoothViewRoot.isPowered
                    onToggled: {
                        togglePower();
                        if (bluetoothViewRoot.isPowered)
                            triggerScan();
                    }
                }
            }

            Flickable {
                id: listScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: mainContentColumn.implicitHeight
                boundsBehavior: Flickable.DragOverBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                onMovementEnded: {
                    if (contentY < -60) {
                        bluetoothViewRoot.triggerScan();
                    }
                }

                Rectangle {
                    id: btRefreshIndicator
                    width: parent.width
                    height: 40
                    color: "transparent"
                    y: -height - 10
                    visible: listScroll.contentY < 0
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
                                running: listScroll.contentY < -60 || bluetoothViewRoot.isScanning
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 1000
                            }
                        }
                        Text {
                            text: listScroll.contentY < -60 ? "Release to refresh..." : "Pull down to refresh"
                            font.family: "Rubik"
                            font.pixelSize: 11
                            color: "#a6adc8"
                        }
                    }
                }

                ColumnLayout {
                    id: mainContentColumn
                    width: listScroll.width - 4
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        visible: bluetoothViewRoot.isPowered && pairedDevicesModel.count > 0
                        Text {
                            text: "Paired Devices"
                            font.family: "Rubik"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: "#a6adc8"
                        }
                    }

                    ListView {
                        id: pairedList
                        Layout.fillWidth: true
                        Layout.preferredHeight: contentHeight
                        interactive: false
                        model: bluetoothViewRoot.isPowered ? pairedDevicesModel : null
                        spacing: 6

                        delegate: Rectangle {
                            width: pairedList.width
                            height: 46
                            radius: 12
                            color: pMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.02)
                            border.color: Qt.rgba(1, 1, 1, 0.05)
                            border.width: 0.5

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Text {
                                    text: {
                                        let name = (model.deviceName || "").toLowerCase();
                                        if (name.includes("bud") || name.includes("ear") || name.includes("head") || name.includes("audio") || name.includes("sound") || name.includes("bass") || name.includes("pro") || name.includes("rockerz") || name.includes("probass")) {
                                            return "headset";
                                        }
                                        return "bluetooth";
                                    }
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 18
                                    color: model.isDeviceConnected ? (rootScope.theme ? rootScope.theme.theme_primary : "#378ADD") : "#a6adc8"
                                }

                                ColumnLayout {
                                    spacing: 1
                                    Layout.fillWidth: true

                                    Text {
                                        text: model.deviceName || "Unknown Device"
                                        font.family: "Rubik"
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        color: model.isDeviceConnected ? (rootScope.theme ? rootScope.theme.theme_primary : "#378ADD") : "#ffffff"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: model.isTransitioning ? "Connecting..." : (model.isDeviceConnected ? "Connected" : "Paired")
                                        font.family: "Rubik"
                                        font.pixelSize: 9
                                        color: "#a6adc8"
                                    }
                                }

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: actMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                                    border.color: Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 0.5
                                    visible: !model.isTransitioning

                                    Text {
                                        anchors.centerIn: parent
                                        text: model.isDeviceConnected ? "link_off" : "link"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 14
                                        color: "#ffffff"
                                    }

                                    MouseArea {
                                        id: actMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (model.isDeviceConnected) {
                                                disconnectDevice(model.macAddress, index);
                                            } else {
                                                connectDevice(model.macAddress, index);
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: pMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        bluetoothViewRoot.selectedDeviceMac = model.macAddress;
                                        bluetoothViewRoot.selectedDeviceName = model.deviceName;
                                        bluetoothViewRoot.selectedDeviceIndex = index;
                                        bluetoothViewRoot.showingForgetConfirm = true;
                                    } else {
                                        if (model.isDeviceConnected) {
                                            disconnectDevice(model.macAddress, index);
                                        } else {
                                            connectDevice(model.macAddress, index);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: bluetoothViewRoot.isPowered && discoveredDevicesModel.count > 0
                        Text {
                            text: "Available Devices"
                            font.family: "Rubik"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: "#a6adc8"
                        }
                    }

                    ListView {
                        id: discList
                        Layout.fillWidth: true
                        Layout.preferredHeight: contentHeight
                        interactive: false
                        model: bluetoothViewRoot.isPowered ? discoveredDevicesModel : null
                        spacing: 6

                        delegate: Rectangle {
                            width: discList.width
                            height: 40
                            radius: 10
                            color: dMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.02)
                            border.color: Qt.rgba(1, 1, 1, 0.05)
                            border.width: 0.5

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Text {
                                    text: "add_circle"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 16
                                    color: "#a6adc8"
                                }

                                Text {
                                    text: model.deviceName || "Unknown Device"
                                    font.family: "Rubik"
                                    font.pixelSize: 12
                                    color: "#ffffff"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: dMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    pairDevice(model.macAddress);
                                }
                            }
                        }
                    }

                    Text {
                        visible: pairedList.count === 0 && discList.count === 0 && bluetoothViewRoot.isPowered
                        text: bluetoothViewRoot.isScanning ? "Scanning for devices..." : "No devices found."
                        font.family: "Rubik"
                        font.pixelSize: 11
                        color: "#a6adc8"
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 20
                    }

                    Text {
                        visible: !bluetoothViewRoot.isPowered
                        text: "Bluetooth is turned off"
                        font.family: "Rubik"
                        font.pixelSize: 11
                        color: "#a6adc8"
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 20
                    }
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
                        text: "Bluetooth Settings"
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
                        if (bluetoothViewRoot.isPowered) {
                            ccRoot.closeMenu();
                            Quickshell.execDetached(["systemsettings"]);
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
                        onClicked: bluetoothViewRoot.showingForgetConfirm = false
                    }
                }

                Text {
                    text: "Forget Device?"
                    font.family: "Rubik"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: "#ffffff"
                    Layout.fillWidth: true
                }
            }

            Text {
                text: "Are you sure you want to forget " + bluetoothViewRoot.selectedDeviceName + "?"
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
                    onClicked: bluetoothViewRoot.showingForgetConfirm = false
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
                    onClicked: {
                        if (bluetoothViewRoot.isPowered) {
                            forgetDevice(bluetoothViewRoot.selectedDeviceMac, bluetoothViewRoot.selectedDeviceIndex);
                            bluetoothViewRoot.showingForgetConfirm = false;
                        }
                    }
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
