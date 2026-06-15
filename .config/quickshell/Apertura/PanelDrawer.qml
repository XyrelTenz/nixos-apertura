import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Item {
    id: drawerRoot

    property bool isOpen: false
    property int drawerHeight: 375
    property int drawerWidth: 300
    property string modalToken: ""
    property bool anchorTop: true
    property bool anchorRight: false

    property alias contentItem: drawerContent

    default property alias contentData: drawerContent.data

    width: 0
    height: 0

    property bool _animatingClosed: false

    onIsOpenChanged: {
        if (isOpen) {
            _animatingClosed = false;
            rootScope.requestOpen(modalToken);
        }
    }

    PanelWindow {
        id: drawerOverlayWindow
        visible: (drawerRoot.isOpen || drawerRoot._animatingClosed) && !(typeof rootScope !== 'undefined' && rootScope.screenshotMode)

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors {
            left: true
            top: true
            bottom: true
            right: true
        }
        color: "transparent"

        // Clicking outside the drawer content dismisses it
        MouseArea {
            anchors.fill: parent
            onClicked: drawerRoot.isOpen = false
        }

        Rectangle {
            id: drawerContent
            width: drawerRoot.drawerWidth
            height: drawerRoot.drawerHeight
            color: "#9911111b"
            clip: true
            x: drawerRoot.anchorRight ? (drawerOverlayWindow.width - drawerRoot.drawerWidth - 12) : 0
            y: {
                if (drawerRoot.anchorTop) {
                    return 12;
                } else {
                    return drawerOverlayWindow.height - drawerRoot.drawerHeight - 12;
                }
            }

            // Prevent clicks inside the drawer from closing it
            MouseArea {
                anchors.fill: parent
                onPressed: mouse => mouse.accepted = true
            }

            opacity: 0.0

            states: [
                State {
                    name: "open"
                    when: drawerRoot.isOpen
                    PropertyChanges {
                        target: drawerContent
                        opacity: 1.0
                        x: drawerRoot.anchorRight ? (drawerOverlayWindow.width - drawerRoot.drawerWidth - 12) : 0
                    }
                },
                State {
                    name: "closed"
                    when: !drawerRoot.isOpen
                    PropertyChanges {
                        target: drawerContent
                        opacity: 0.0
                        x: drawerRoot.anchorRight ? drawerOverlayWindow.width : -drawerRoot.drawerWidth
                    }
                }
            ]

            transitions: [
                Transition {
                    from: "closed"
                    to: "open"
                    ParallelAnimation {
                        NumberAnimation {
                            property: "x"
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            property: "opacity"
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }
                },
                Transition {
                    from: "open"
                    to: "closed"
                    SequentialAnimation {
                        ScriptAction {
                            script: drawerRoot._animatingClosed = true
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                property: "x"
                                duration: 200
                                easing.type: Easing.InCubic
                            }
                            NumberAnimation {
                                property: "opacity"
                                duration: 200
                                easing.type: Easing.InQuad
                            }
                        }
                        ScriptAction {
                            script: drawerRoot._animatingClosed = false
                        }
                    }
                }
            ]
        }
    }
}
