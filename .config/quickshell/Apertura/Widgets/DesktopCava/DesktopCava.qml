import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: desktopCavaWindow

    WlrLayershell.layer: isAlwaysVisible ? WlrLayer.Overlay : WlrLayer.Background
    WlrLayershell.namespace: "desktop-cava-widget"
    
    WlrLayershell.anchors.top: true
    WlrLayershell.anchors.left: true
    WlrLayershell.anchors.bottom: true
    WlrLayershell.anchors.right: true
    
    color: "transparent"

    mask: isAlwaysVisible ? cavaInputBounds : null

    Region {
        id: cavaInputBounds
        item: cavaContentWrapper
    }

    property bool isAlwaysVisible: false
    
    onVisibleChanged: {
        if (visible) {
            cavaService.start();
        }
    }

    Rectangle {
        id: cavaContentWrapper
        
        property int posX: 25
        property int posY: desktopCavaWindow.height - height - 25

        x: posX
        y: posY
        width: 320
        height: 120
        
        color: "#9911111b"
        radius: 0
        border.width: 0

        Text {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 10
            anchors.leftMargin: 12
            text: "AUDIO VISUALIZER"
            font.family: "Rubik"
            font.pixelSize: 8
            font.weight: Font.Bold
            color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
            opacity: 0.4
        }

        Item {
            id: visualizerContainer
            anchors.fill: parent
            anchors.topMargin: 26
            anchors.bottomMargin: 10
            anchors.leftMargin: 12
            anchors.rightMargin: 12

            property int barCount: 32
            property real barWidth: 4
            property real maxHeight: parent.height - 36
            property real spacing: 2
            property color accentColor: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
            property bool active: cavaService.active
            property bool fillWidth: true

            readonly property real effectiveBarWidth: fillWidth && width > 0
                ? Math.max(1, (width - spacing * (barCount - 1)) / barCount)
                : barWidth

            Row {
                anchors.fill: parent
                spacing: visualizerContainer.spacing

                Repeater {
                    model: visualizerContainer.barCount
                    delegate: Item {
                        property int idx: index
                        width: visualizerContainer.effectiveBarWidth
                        height: visualizerContainer.maxHeight

                        readonly property real amp: {
                            var bars = cavaService.bars
                            if (!bars || bars.length === 0 || idx >= bars.length) return 0
                            var v = bars[idx]
                            return isNaN(v) ? 0 : Math.max(0, Math.min(1, v / 100))
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "#05ffffff"
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: visualizerContainer.effectiveBarWidth
                            height: Math.max(2, amp * visualizerContainer.maxHeight)
                            radius: width / 2
                            color: Qt.rgba(visualizerContainer.accentColor.r, 
                                           visualizerContainer.accentColor.g, 
                                           visualizerContainer.accentColor.b, 
                                           0.25 + amp * 0.65)

                            Behavior on height {
                                NumberAnimation { duration: 50; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            cursorShape: containsMouse ? Qt.SizeAllCursor : Qt.ArrowCursor
            hoverEnabled: true

            property int clickOffsetX: 0
            property int clickOffsetY: 0

            onPressed: (mouse) => {
                clickOffsetX = mouse.x
                clickOffsetY = mouse.y
            }

            onPositionChanged: (mouse) => {
                if (pressed) {
                    cavaContentWrapper.posX = cavaContentWrapper.posX + mouse.x - clickOffsetX
                    cavaContentWrapper.posY = cavaContentWrapper.posY + mouse.y - clickOffsetY
                }
            }
        }

        RowLayout {
            id: toggleContainer
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.rightMargin: 12
            spacing: 8
            
            visible: dragArea.containsMouse || btnMouseArea.containsMouse

            Text {
                text: desktopCavaWindow.isAlwaysVisible ? "keep" : "keep_off"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 18
                Layout.alignment: Qt.AlignVCenter
                color: desktopCavaWindow.isAlwaysVisible 
                    ? (rootScope.theme ? rootScope.theme.theme_fg : "#ffffff") 
                    : (rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff")
            }

            Rectangle {
                id: toggleTrack
                width: 50
                height: 24
                radius: 12
                Layout.alignment: Qt.AlignVCenter
                color: desktopCavaWindow.isAlwaysVisible 
                    ? (rootScope.theme ? rootScope.theme.theme_outline : "#45ffffff") 
                    : (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff")
                
                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b"
                    anchors.verticalCenter: parent.verticalCenter
                    x: desktopCavaWindow.isAlwaysVisible ? 28 : 4
                    
                    Behavior on x { 
                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad } 
                    }
                }
                
                MouseArea {
                    id: btnMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true 
                    
                    onClicked: {
                        desktopCavaWindow.isAlwaysVisible = !desktopCavaWindow.isAlwaysVisible
                    }
                }
            }
        }
    }
}
