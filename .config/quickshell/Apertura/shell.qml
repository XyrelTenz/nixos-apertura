import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml.Models
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import "."
import "Modules/AppLauncher"
import "Modules/Battery"
import "Modules/ControlCenter"
import "Modules/Calendar"
import "Modules/Cava"
import "Modules/Media"
import "Modules/NetMonitor"
import "Modules/Notes"
import "Modules/Notification"
import "Modules/ScreenRecord"
import "Modules/SysMonitor"
import "Modules/Wallpaper"
import "Modules/Workspaces"

import "Widgets/DesktopClock"
import "Widgets/VolumeHud"
import "Widgets/WorkspacePreview"
import "Widgets/DesktopCava"

Scope {
    id: rootScope

    /** @property var configurationAsset: References external localized configuration values */
    property var configurationAsset: Config

    /** @property alias theme: Exposes global Canvas/UI styling metrics to submodules */
    property alias theme: theme 

    /** @property var sharedPinnedApps: Holds application configurations pinned inside the launcher view */
    property var sharedPinnedApps: []

    /** @property var activeModal: Tracks currently active modal context name to ensure singular overlay states */
    property var activeModal: null
    
    /** @property bool audioSliderActive: Flag preventing focus drops when interacting with audio overlays */
    property bool audioSliderActive: false
    
    /** @property var instantiatedBars: Dictionary mapping screen name keys to instantiated PanelWindow configurations */
    property var instantiatedBars: ({})
    
    /** @property bool sessionLocked: Flag indicating if the compositor layer is locked */
    property bool sessionLocked: false

    /** @property var notificationItem: Global reference pointer to the underlying Notification visual server element */
    property var notificationItem: null
    
    /** @property var sysMonitorItem: Global reference pointer to the hardware telemetry analyzer instance */
    property var sysMonitorItem: null
    
    /** @property bool notificationsEnabled: Global toggle for filtering and routing desktop notification servers */
    property bool notificationsEnabled: true

    Theme { id: theme }

    // IO & System Data Services

    /**
     * @fileView pinCacheReader
     * Parses the persistent system launcher configurations.
     * Evaluates local application layout configurations reactively on file changes.
     */
    FileView {
        id: pinCacheReader
        path: Quickshell.env("HOME") + "/.cache/quickshell_launcher_pins.json"
        
        onTextChanged: {
            let cleanText = text().trim();
            if (!cleanText || cleanText === "[]") return;
            try {
                let parsed = JSON.parse(cleanText);
                if (parsed && parsed.pins) {
                    rootScope.sharedPinnedApps = parsed.pins;
                }
            } catch(e) {}
        }
    }

    Component.onCompleted: {
        pinCacheReader.reload();
    }

    /**
     * @notificationServer globalNotificationServer
     * Connects directly with the host system DBus service pipeline to trap inbound desktop notifications.
     */
    NotificationServer {
        id: globalNotificationServer
        bodySupported: true
        actionsSupported: true
        keepOnReload: true
    }

    ControlCenter {
        id: controlCenterItem
        notificationItem: rootScope.notificationItem
        sysMonitorItem: rootScope.sysMonitorItem
    }

    CavaService {
        id: cavaService
    }

    Notification {
        id: notificationItem
        width: 0
        height: 0
        Component.onCompleted: rootScope.notificationItem = this
    }

    /**
     * @function requestOpen
     * @param {string} modalName - Global routing tracker to map modal active focal states.
     */
    function requestOpen(modalName) { activeModal = modalName; }
    
    /** @function dismissAll: Utility wrapper resetting focal states down across modular sub-containers */
    function dismissAll() { activeModal = null; }

    /**
     * @function checkIsVertical
     * @param {int} wsId - Workspace Identifier index.
     * Evaluates screen dimensional aspect configurations dynamically to track rotated/vertical orientation arrays.
     * @returns {bool} True if physical monitor scale target maps vertically.
     */
    function checkIsVertical(wsId) {
        let targetWsObj = Hyprland.workspaces.values.find(ws => ws.id === wsId);
        let monitorObj = targetWsObj ? targetWsObj.monitor : (Hyprland.activeMonitor || null);
        
        if (monitorObj) {
            return monitorObj.height > monitorObj.width;
        }
        return wsId >= 10;
    }

    // Desktop Floating Overlay Windows

    /**
     * @panelWindow globalWorkspacePreview
     * Renders a floating window preview layer when cycling through virtual desktop workspace scopes.
     */
    PanelWindow {
        id: globalWorkspacePreview
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-workspace-preview"
        WlrLayershell.keyboardFocus: WlrLayershell.None

        anchors { left: true; top: true }

        property int targetWorkspace: -1
        property int marginLeft: 0
        property int marginTop: 0

        function requestDismiss() { dismissTimer.restart(); }
        function cancelDismiss() { dismissTimer.stop(); }

        Timer {
            id: dismissTimer
            interval: 150
            running: false
            repeat: false
            onTriggered: globalWorkspacePreview.targetWorkspace = -1
        }

        onMarginLeftChanged: globalWorkspacePreview.WlrLayershell.margins.left = marginLeft
        onMarginTopChanged: globalWorkspacePreview.WlrLayershell.margins.top = marginTop

        visible: targetWorkspace !== -1 || popupCard.state === "visible"

        implicitWidth: previewEngine.implicitWidth
        implicitHeight: previewEngine.implicitHeight
        color: "transparent"

        MouseArea {
            id: globalSurfaceTracker
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            
            onEntered: globalWorkspacePreview.cancelDismiss()
            onExited: globalWorkspacePreview.requestDismiss()

            Rectangle {
                id: popupCard
                width: parent.width
                height: parent.height
                color: "#9911111b" 
                clip: true

                states: [
                    State {
                        name: "visible"; when: previewEngine.active
                        PropertyChanges { target: popupCard; opacity: 1.0 }
                    },
                    State {
                        name: "hidden"; when: !previewEngine.active
                        PropertyChanges { target: popupCard; opacity: 0.0 }
                    }
                ]

                transitions: [
                    Transition {
                        from: "hidden"; to: "visible"
                        NumberAnimation { target: popupCard; property: "opacity"; duration: 150 }
                    },
                    Transition {
                        from: "visible"; to: "hidden"
                        NumberAnimation { target: popupCard; property: "opacity"; duration: 150 }
                    }
                ]

                Flickable {
                    id: scrollViewport
                    anchors.fill: parent
                    contentWidth: previewEngine.implicitWidth
                    contentHeight: previewEngine.implicitHeight
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    WorkspacePreview {
                        id: previewEngine
                        targetWorkspace: globalWorkspacePreview.targetWorkspace
                        theme: rootScope.theme
                        opacity: globalWorkspacePreview.implicitWidth > 50 ? 1.0 : 0.0
                    }
                }
            }
        }
    }

    // Compositor & IPC Event Signal Hooks

    Connections {
        target: Hyprland
        ignoreUnknownSignals: true

        function onWorkspaceChanged() {
            if (Hyprland.activeWorkspace) {
                let currentWsId = Hyprland.activeWorkspace.id;
                if (globalWorkspacePreview.targetWorkspace !== currentWsId) {
                    globalWorkspacePreview.targetWorkspace = currentWsId;
                    globalWorkspacePreview.cancelDismiss();
                    
                    let activeMonitorObj = Hyprland.activeMonitor;
                    if (activeMonitorObj) {
                        globalWorkspacePreview.marginLeft = 54 + 12; 
                        globalWorkspacePreview.marginTop = Math.round((activeMonitorObj.height - (checkIsVertical(currentWsId) ? 700 : 300)) / 2);
                    }
                    globalWorkspacePreview.requestDismiss();
                }
            }
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            for (let s in rootScope.instantiatedBars)
                if (rootScope.instantiatedBars[s].appLauncherModule)
                    rootScope.instantiatedBars[s].appLauncherModule.toggleMenu();
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            for (let s in rootScope.instantiatedBars)
                if (rootScope.instantiatedBars[s].wallpaperModule)
                    rootScope.instantiatedBars[s].wallpaperModule.toggleMenu();
        }
    }

    IpcHandler {
        target: "media"
        function toggle(): void {
            for (let s in rootScope.instantiatedBars)
                if (rootScope.instantiatedBars[s].mediaModule)
                    rootScope.instantiatedBars[s].mediaModule.togglePlayback();
        }
    }

    IpcHandler {
        target: "notes"
        function toggle(): void {
            for (let s in rootScope.instantiatedBars)
                if (rootScope.instantiatedBars[s].notesModule)
                    rootScope.instantiatedBars[s].notesModule.toggleMenu();
        }
    }

    IpcHandler {
        target: "sysmonitor"
        function toggle(): void {
            for (let s in rootScope.instantiatedBars)
                if (rootScope.instantiatedBars[s].sysMonitorModule)
                    rootScope.instantiatedBars[s].sysMonitorModule.toggleMenu();
        }
    }

    IpcHandler {
        target: "netmonitor"
        function toggle(): void {
            for (let s in rootScope.instantiatedBars)
                if (rootScope.instantiatedBars[s].netMonitorModule)
                    rootScope.instantiatedBars[s].netMonitorModule.toggleMenu();
        }
    }

    Instantiator {
        id: barWindows
        model: Quickshell.screens

        delegate: Scope {
            VolumeHud { targetScreen: modelData }

            DesktopClock {
                screen: modelData
            }

            DesktopCava {
                screen: modelData
            }

            PanelWindow {
                id: mainBarWindow
                property string screenKey: modelData.name
                visible: true

                Component.onCompleted: { rootScope.instantiatedBars[screenKey] = mainBarWindow; }
                Component.onDestruction: { delete rootScope.instantiatedBars[screenKey]; }

                property alias appLauncherModule: appLauncherItem
                property alias wallpaperModule: wallpaperItem
                property alias calendarModule: calendarItem
                property alias mediaModule: mediaItem
                property alias notesModule: notesItem
                property alias sysMonitorModule: sysMonitorItem
                property alias netMonitorModule: netMonitorItem
                
                readonly property var previewPopup: globalWorkspacePreview

                screen: modelData
                anchors { left: true; top: true; bottom: true }
                implicitWidth: 54
                color: "transparent"

                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "quickshell-bar"
                WlrLayershell.margins.top: 12; WlrLayershell.margins.bottom: 12; WlrLayershell.margins.left: 12; WlrLayershell.margins.right: 0

                Rectangle {
                    anchors.fill: parent
                    color: "#9911111b"
                    clip: true

                    MouseArea { 
                        anchors.fill: parent
                        hoverEnabled: true
                        z: -1
                        onPressed: rootScope.dismissAll() 
                    }

                    ColumnLayout {
                        id: barMainLayout
                        anchors.fill: parent
                        anchors.topMargin: 16
                        anchors.bottomMargin: 16
                        spacing: 0

                        Column {
                            id: topStackColumn
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 12

                            AppLauncher { id: appLauncherItem; anchors.horizontalCenter: parent.horizontalCenter }
                            Wallpaper { id: wallpaperItem; anchors.horizontalCenter: parent.horizontalCenter; property int barHeight: mainBarWindow.height }
                            Calendar { id: calendarItem; anchors.horizontalCenter: parent.horizontalCenter }
                            
                            Item {
                                width: 32
                                height: 56
                                anchors.horizontalCenter: parent.horizontalCenter

                                Cava {
                                    anchors.centerIn: parent
                                    themeContext: rootScope.theme
                                }
                            }

                            Workspaces { 
                                theme: rootScope.theme 
                                anchors.horizontalCenter: parent.horizontalCenter; z: 1 
                            }
                        }

                        Item { Layout.fillHeight: true }

                        ColumnLayout {
                            id: bottomGroupControls
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumHeight: parent.height - topStackColumn.height - 96
                            spacing: 8 
                            property bool isExpanded: false

                            Rectangle {
                                id: toggleButton
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignHCenter
                                color: "transparent"
                                radius: 0

                                Text {
                                    anchors.centerIn: parent
                                    text: bottomGroupControls.isExpanded ? "arrow_drop_down" : "arrow_drop_up"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 30
                                    color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                                }

                                Rectangle {
                                    id: toggleHoverOverlay
                                    anchors.fill: parent
                                    radius: 0
                                    color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
                                    opacity: toggleMouseArea.containsMouse ? 0.3 : 0.0
                                    z: 1
                                }

                                MouseArea {
                                    id: toggleMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: {
                                        bottomGroupControls.isExpanded = !bottomGroupControls.isExpanded;
                                    }
                                }
                            }

                            Flickable {
                                id: bottomModulesFlickable
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.alignment: Qt.AlignHCenter

                                contentWidth: modulesColumn.width
                                contentHeight: modulesColumn.implicitHeight
                                flickableDirection: Flickable.VerticalFlick
                                boundsBehavior: Flickable.StopAtBounds
                                clip: true

                                ColumnLayout {
                                    id: modulesColumn
                                    width: bottomModulesFlickable.width
                                    spacing: 8

                                    /**
                                     * @component DrawerModule
                                     * Rewritten to derive from Loader. This separates the layout engine 
                                     * constraints from the target execution block cleanly.
                                     */
                                    component DrawerModule : Item {
                                        id: moduleWrapper
                                        property bool isPinned: false
                                        property bool moduleAvailable: true
                                        default property alias moduleData: container.data

                                        readonly property bool shouldBeActive: (bottomGroupControls.isExpanded || isPinned) && moduleAvailable

                                        property int targetHeight: shouldBeActive ? 38 : 0
                                        Behavior on targetHeight {
                                            NumberAnimation {
                                                duration: 200
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        Layout.preferredWidth: shouldBeActive ? 38 : 0
                                        Layout.preferredHeight: targetHeight
                                        Layout.alignment: Qt.AlignHCenter
                                        
                                        visible: targetHeight > 0
                                        opacity: targetHeight / 38

                                        width: 38
                                        height: 38

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 0
                                            color: "transparent"
                                            border.width: isPinned && bottomGroupControls.isExpanded ? 1 : 0
                                            border.color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                                        }

                                        Item {
                                            id: container
                                            width: 32
                                            height: 32
                                            anchors.centerIn: parent
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.RightButton
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: (mouse) => {
                                                if (mouse.button === Qt.RightButton) {
                                                    moduleWrapper.isPinned = !moduleWrapper.isPinned
                                                }
                                            }
                                        }
                                    }

                                    DrawerModule {
                                        id: wrapBattery
                                        moduleAvailable: batteryItem.isLaptop
                                        Battery { id: batteryItem; anchors.centerIn: parent }
                                    }

                                    DrawerModule { 
                                        id: wrapMedia
                                        Media { id: mediaItem; anchors.centerIn: parent } 
                                    }
                                    
                                    DrawerModule { id: wrapNotes; Notes { id: notesItem; anchors.centerIn: parent } }
                                    
                                    DrawerModule { 
                                        id: wrapSys
                                        SysMonitor { 
                                            id: sysMonitorItem
                                            theme: rootScope.theme
                                            anchors.centerIn: parent
                                            active: controlCenterItem.menuOpen
                                            Component.onCompleted: rootScope.sysMonitorItem = this 
                                        } 
                                    }
                                    
                                    DrawerModule { id: wrapNet; NetMonitor { id: netMonitorItem; anchors.centerIn: parent } }
                                    
                                    DrawerModule { id: wrapRecord; ScreenRecord { id: screenRecordItem; anchors.centerIn: parent } }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 8
                            spacing: 8

                            Rectangle {
                                id: fixedSettingsBtn
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignHCenter
                                color: "transparent"
                                radius: 0

                                Text {
                                    anchors.centerIn: parent
                                    text: "settings"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 22
                                    color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 0
                                    color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
                                    opacity: fixedSettingsMouseArea.containsMouse ? 0.3 : 0.0
                                    z: 1
                                }

                                MouseArea {
                                    id: fixedSettingsMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controlCenterItem.toggleMenu()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}