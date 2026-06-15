import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../.."

Item {
    id: notificationRoot
    implicitWidth: 32
    implicitHeight: 32

    property int unreadCount: 0
    property var visibleBanners: []
    property var activeHistoryReferences: []
    property bool menuOpen: false
    property bool notificationsEnabled: rootScope.notificationsEnabled
    property var server: rootScope.globalNotificationServer
    property var nativeServer: server

    property color primaryColor: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
    property color fgColor: rootScope.theme ? rootScope.theme.theme_fg : "#cdd6f4"
    property color outlineColor: rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff"
    property color onPrimary: rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b"

    Timer {
        id: osdAutohideTimer
        interval: Config.autohideInterval
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
        if (notificationMouseArea.containsMouse || cardHoverTracker.containsMouse) {
            osdAutohideTimer.stop();
        } else if (drawerTemplate.isOpen) {
            osdAutohideTimer.restart();
        }
    }

    function updateCount() {
        if (!notificationRoot.notificationsEnabled) {
            notificationRoot.unreadCount = 0;
            return;
        }
        if (nativeServer && nativeServer.trackedNotifications) {
            notificationRoot.unreadCount = nativeServer.trackedNotifications.rowCount();
        }
    }

    Connections {
        target: notificationRoot.server
        function onNotification(notification) {
            if (!notificationRoot.notificationsEnabled) {
                notification.dismiss();
                return;
            }

            notification.tracked = true;
            notificationRoot.updateCount();
            if (!notificationRoot.activeHistoryReferences.includes(notification)) {
                notificationRoot.activeHistoryReferences = [...notificationRoot.activeHistoryReferences, notification];
            }
            notificationRoot.visibleBanners = [...notificationRoot.visibleBanners, notification];

            let toastTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 5000; running: true; repeat: true }', notificationRoot);
            toastTimer.triggered.connect(() => {
                let idx = notificationRoot.visibleBanners.indexOf(notification);
                if (idx !== -1 && toastRepeater.itemAt(idx) && toastRepeater.itemAt(idx).isHovered) {
                    return;
                }
                notificationRoot.visibleBanners = notificationRoot.visibleBanners.filter(item => item !== notification);
                toastTimer.destroy();
            });
        }
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: notificationRoot.updateCount()
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
        anchors.fill: parent
        color: "transparent"
        radius: 0

        Text {
            anchors.centerIn: parent
            text: !notificationRoot.notificationsEnabled ? "notifications_off" : (notificationRoot.unreadCount > 0 ? "notifications_unread" : "notifications")
            font.family: "Material Symbols Outlined"
            font.pixelSize: 20
            color: notificationRoot.notificationsEnabled ? (notificationMouseArea.containsMouse ? notificationRoot.primaryColor : notificationRoot.fgColor) : notificationRoot.outlineColor

            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 0
            color: notificationRoot.primaryColor
            opacity: notificationMouseArea.containsMouse ? 0.08 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }
        }

        MouseArea {
            id: notificationMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
            onContainsMouseChanged: checkUserActivity()
            onDoubleClicked: {
                if (!notificationRoot.notificationsEnabled)
                    return;
                try {
                    nativeServer.clear();
                } catch (e) {}
                try {
                    nativeServer.dismissAll();
                } catch (e) {}
                for (let i = 0; i < notificationRoot.activeHistoryReferences.length; i++) {
                    try {
                        notificationRoot.activeHistoryReferences[i].dismiss();
                    } catch (e) {}
                    try {
                        nativeServer.dismiss(notificationRoot.activeHistoryReferences[i].id);
                    } catch (e) {}
                }
                notificationRoot.visibleBanners = [];
                notificationRoot.activeHistoryReferences = [];
            }
        }
    }

    PanelWindow {
        id: popupToastWindow
        visible: notificationRoot.visibleBanners.length > 0 && !drawerTemplate.isOpen && notificationRoot.notificationsEnabled && !(typeof rootScope !== 'undefined' && rootScope.screenshotMode)
        color: "transparent"
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: toastInputBounds

        Region {
            id: toastInputBounds
            item: toastColumn
        }

        ColumnLayout {
            id: toastColumn
            width: Config.drawerTargetWidth
            y: 12
            spacing: 6

            states: [
                State {
                    name: "visible"
                    when: notificationRoot.visibleBanners.length > 0
                    PropertyChanges {
                        target: toastColumn
                        x: popupToastWindow.width - toastColumn.width - 12
                    }
                },
                State {
                    name: "hidden"
                    when: notificationRoot.visibleBanners.length === 0
                    PropertyChanges {
                        target: toastColumn
                        x: popupToastWindow.width
                    }
                }
            ]

            transitions: [
                Transition {
                    from: "hidden"
                    to: "visible"
                    NumberAnimation {
                        property: "x"
                        duration: Config.entryDuration
                        easing.type: Config.entryEasing
                    }
                },
                Transition {
                    from: "visible"
                    to: "hidden"
                    NumberAnimation {
                        property: "x"
                        duration: Config.exitDuration
                        easing.type: Config.exitEasing
                    }
                }
            ]

            Repeater {
                id: toastRepeater
                model: notificationRoot.visibleBanners

                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: toastContent.implicitHeight + 24
                    color: "#ee24273a"
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    radius: 16

                    property bool isHovered: toastMouseArea.containsMouse

                    ColumnLayout {
                        id: toastContent
                        anchors {
                            left: parent.left
                            leftMargin: 14
                            right: parent.right
                            rightMargin: 14
                            top: parent.top
                            topMargin: 12
                            bottom: parent.bottom
                            bottomMargin: 12
                        }
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                width: 32
                                height: 32
                                radius: 16
                                color: Qt.rgba(255, 255, 255, 0.05)

                                Text {
                                    anchors.centerIn: parent
                                    text: "notifications"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 14
                                    color: notificationRoot.primaryColor
                                }
                            }

                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true

                                Text {
                                    text: modelData.appName || "Notification"
                                    font.family: "Rubik"
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: "#cdd6f4"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: "Just now"
                                    font.family: "Rubik"
                                    font.pixelSize: 10
                                    color: "#a6adc8"
                                }
                            }

                            Text {
                                text: "close"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 14
                                color: "#80ffffff"
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Layout.topMargin: 2
                            Layout.leftMargin: 2

                            Rectangle {
                                width: 3
                                height: summaryText.implicitHeight + (bodyText.visible ? bodyText.implicitHeight + 2 : 0)
                                Layout.preferredHeight: height
                                Layout.alignment: Qt.AlignTop
                                radius: 1.5
                                color: notificationRoot.primaryColor
                            }

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop

                                Text {
                                    id: summaryText
                                    text: modelData.summary
                                    font.family: "Rubik"
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: "#ffffff"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: bodyText
                                    text: modelData.body
                                    font.family: "Rubik"
                                    font.pixelSize: 11
                                    color: "#a6adc8"
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    visible: modelData.body !== ""
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: toastMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            notificationRoot.visibleBanners = notificationRoot.visibleBanners.filter(item => item !== modelData);
                        }
                    }
                }
            }
        }
    }

    PanelDrawer {
        id: drawerTemplate
        isOpen: false
        modalToken: "notifications"
        anchorTop: false
        drawerHeight: Math.min(panelLayout.implicitHeight + 28, 375)

        onIsOpenChanged: {
            if (isOpen) {
                notificationRoot.menuOpen = true;
                checkUserActivity();
                panelLayout.forceActiveFocus();
            } else {
                notificationRoot.menuOpen = false;
            }
        }

        MouseArea {
            id: cardHoverTracker
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: checkUserActivity()
        }

        MouseArea {
            anchors.fill: parent
            onPressed: mouse => {
                mouse.accepted = true;
                checkUserActivity();
            }
        }

        ColumnLayout {
            id: panelLayout
            anchors.fill: parent
            spacing: 0
            focus: true

            Rectangle {
                Layout.fillWidth: true
                height: 44
                color: "#0dffffff"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 8

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 0
                        color: Qt.rgba(notificationRoot.primaryColor.r, notificationRoot.primaryColor.g, notificationRoot.primaryColor.b, 0.12)

                        Text {
                            anchors.centerIn: parent
                            text: "notifications"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 14
                            color: notificationRoot.primaryColor
                        }
                    }

                    Text {
                        text: "Notifications"
                        font.family: "Rubik"
                        font.pixelSize: 13
                        font.weight: Font.SemiBold
                        color: notificationRoot.fgColor
                    }

                    Rectangle {
                        visible: notificationRoot.unreadCount > 0 && notificationRoot.notificationsEnabled
                        width: Math.max(18, countBadge.implicitWidth + 8)
                        height: 16
                        radius: 0
                        color: Qt.rgba(notificationRoot.primaryColor.r, notificationRoot.primaryColor.g, notificationRoot.primaryColor.b, 0.18)

                        Text {
                            id: countBadge
                            anchors.centerIn: parent
                            text: notificationRoot.unreadCount
                            font.family: "Rubik"
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: notificationRoot.primaryColor
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Item {
                        width: clearText.implicitWidth
                        height: 24
                        visible: notificationRoot.unreadCount > 0 && notificationRoot.notificationsEnabled

                        Text {
                            id: clearText
                            anchors.centerIn: parent
                            text: "Clear all"
                            font.family: "Rubik"
                            font.pixelSize: 11
                            color: clearMouse.containsMouse ? notificationRoot.primaryColor : "#50ffffff"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                try {
                                    nativeServer.clear();
                                } catch (e) {}
                                try {
                                    nativeServer.dismissAll();
                                } catch (e) {}
                                for (let i = 0; i < notificationRoot.activeHistoryReferences.length; i++) {
                                    let item = notificationRoot.activeHistoryReferences[i];
                                    if (item) {
                                        try {
                                            item.dismiss();
                                        } catch (e) {}
                                        try {
                                            nativeServer.dismiss(item.id);
                                        } catch (e) {}
                                    }
                                }
                                notificationRoot.visibleBanners = [];
                                notificationRoot.activeHistoryReferences = [];
                                notificationRoot.updateCount();
                                checkUserActivity();
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 14
                        color: "#20ffffff"
                        visible: notificationRoot.unreadCount > 0 && notificationRoot.notificationsEnabled
                    }

                    RowLayout {
                        spacing: 6

                        Text {
                            text: notificationRoot.notificationsEnabled ? "do_not_disturb_off" : "do_not_disturb_on"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 13
                            color: notificationRoot.notificationsEnabled ? "#40ffffff" : "#f38ba8"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }
                        }

                        Rectangle {
                            width: 36
                            height: 20
                            radius: 0
                            color: notificationRoot.notificationsEnabled ? Qt.rgba(notificationRoot.primaryColor.r, notificationRoot.primaryColor.g, notificationRoot.primaryColor.b, 0.25) : "#20ffffff"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }

                            Rectangle {
                                width: 14
                                height: 14
                                radius: 0
                                color: notificationRoot.notificationsEnabled ? notificationRoot.primaryColor : "#60ffffff"
                                anchors.verticalCenter: parent.verticalCenter
                                x: notificationRoot.notificationsEnabled ? 19 : 3

                                Behavior on x {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutQuad
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 200
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    rootScope.notificationsEnabled = !rootScope.notificationsEnabled;
                                    notificationRoot.updateCount();
                                    checkUserActivity();
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#18ffffff"
            }

            ListView {
                id: notifListView
                Layout.fillWidth: true
                Layout.preferredHeight: count === 0 ? 56 : Math.min(contentHeight + 16, 300)
                clip: true
                spacing: 0
                topMargin: 6
                bottomMargin: 6
                model: nativeServer.trackedNotifications
                visible: notificationRoot.notificationsEnabled
                boundsBehavior: Flickable.StopAtBounds

                Item {
                    anchors.centerIn: parent
                    visible: notifListView.count === 0 && notificationRoot.notificationsEnabled
                    width: parent.width
                    height: 56

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "notifications"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 18
                            color: "#22ffffff"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "No new notifications"
                            font.family: "Rubik"
                            font.pixelSize: 12
                            color: "#40ffffff"
                        }
                    }
                }

                delegate: Rectangle {
                    width: notifListView.width - 12
                    x: 6
                    height: notifItemLayout.implicitHeight + 20
                    color: cellMouse.containsMouse ? "#0effffff" : "transparent"
                    radius: 0

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 2
                        color: notificationRoot.primaryColor
                        opacity: cellMouse.containsMouse ? 0.8 : 0.25

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                    }

                    ColumnLayout {
                        id: notifItemLayout
                        anchors {
                            left: parent.left
                            leftMargin: 12
                            right: parent.right
                            rightMargin: 10
                            top: parent.top
                            topMargin: 10
                        }
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Text {
                                text: (modelData.appName || "App").toUpperCase()
                                font.family: "Rubik"
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: notificationRoot.primaryColor
                                opacity: 0.8
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "close"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 11
                                color: cellMouse.containsMouse ? "#80ffffff" : "#30ffffff"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }
                        }

                        Text {
                            text: modelData.summary
                            font.family: "Rubik"
                            font.pixelSize: 12
                            font.weight: Font.SemiBold
                            color: "#e0ffffff"
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: modelData.body
                            font.family: "Rubik"
                            font.pixelSize: 11
                            color: "#60ffffff"
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            visible: modelData.body !== ""
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: "#0cffffff"
                        visible: index < notifListView.count - 1
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            try {
                                nativeServer.dismiss(modelData.id);
                            } catch (e) {}
                            try {
                                modelData.dismiss();
                            } catch (e) {}
                            notificationRoot.updateCount();
                            checkUserActivity();
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                height: 80
                visible: !notificationRoot.notificationsEnabled

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "do_not_disturb_on"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 22
                        color: "#f38ba8"
                        opacity: 0.6
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Notifications muted"
                        font.family: "Rubik"
                        font.pixelSize: 12
                        color: "#50ffffff"
                    }
                }
            }
        }
    }
}
