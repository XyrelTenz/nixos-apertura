import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../.."

Item {
    id: wallpaperModuleRoot
    implicitWidth: 32
    implicitHeight: 32

    property string wallpaperDir: ""
    property bool menuOpen: false
    property point globalMousePos: Qt.point(-1, -1)
    property int barHeight: 1080 // fallback to avoid property not found if referenced

    function toggleMenu(): void {
        menuOpen = !menuOpen;
        if (menuOpen) {
            rootScope.requestOpen("wallpaper");
        } else {
            rootScope.dismissAll();
        }
    }

    function closeMenu(): void {
        menuOpen = false;
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== "wallpaper" && wallpaperModuleRoot.menuOpen) {
                closeMenu();
            }
        }
    }

    Rectangle {
        id: triggerButton
        anchors.fill: parent
        radius: 0
        color: "transparent"

        Text {
            anchors.centerIn: parent
            text: "wallpaper"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 26
            color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
        }

        Rectangle {
            id: hoverOverlay
            anchors.fill: parent
            radius: 0
            color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
            opacity: wallpaperMouseArea.containsMouse ? 0.3 : 0.0
            z: 1 // Sits above base, below text
        }

        MouseArea {
            id: wallpaperMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
        }
    }

    PanelWindow {
        id: pickerWindow

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-wallpaper-picker"
        WlrLayershell.keyboardFocus: WlrLayershell.OnDemand

        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        visible: wallpaperModuleRoot.menuOpen

        color: "transparent"

        // Background click to close
        MouseArea {
            anchors.fill: parent
            onPressed: wallpaperModuleRoot.toggleMenu()
        }

        Loader {
            id: pickerLoader
            anchors.centerIn: parent
            width: parent.width
            height: 650

            source: wallpaperModuleRoot.menuOpen ? Qt.resolvedUrl("WallpaperPicker.qml").toString() : ""

            onLoaded: {
                if (item) {
                    item.forceActiveFocus();
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: wallpaperModuleRoot.menuOpen && (!pickerLoader.item || pickerLoader.item.currentFilter !== "Search")
        onActivated: wallpaperModuleRoot.toggleMenu()
    }
}
