import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../.."

Item {
    id: powerViewRoot
    Layout.fillWidth: true
    Layout.fillHeight: true

    signal backClicked
    signal actionTriggered

    function runCommand(args) {
        powerViewRoot.actionTriggered();
        if (args[0] === "INTERNAL_LOCK") {
            Quickshell.execDetached(["sh", "-c", "hyprlock"]);
        } else {
            sysCmd.command = args;
            sysCmd.running = true;
        }
    }

    Process {
        id: sysCmd
        running: false
    }

    ColumnLayout {
        spacing: 16
        anchors.fill: parent

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
                    onClicked: powerViewRoot.backClicked()
                }
            }

            RowLayout {
                spacing: 10
                Layout.fillWidth: true

                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    color: Qt.rgba(255 / 255, 85 / 255, 85 / 255, 0.15)
                    Text {
                        anchors.centerIn: parent
                        text: "power_settings_new"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 18
                        color: "#ff5555"
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Power Menu"
                        font.family: "Rubik"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }
                    Text {
                        text: "Choose session action"
                        font.family: "Rubik"
                        font.pixelSize: 11
                        color: "#a6adc8"
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    {
                        label: "Lock Screen",
                        icon: "lock",
                        cmd: ["INTERNAL_LOCK"]
                    },
                    {
                        label: "Suspend",
                        icon: "bedtime",
                        cmd: ["systemctl", "suspend"]
                    },
                    {
                        label: "Reboot",
                        icon: "restart_alt",
                        cmd: ["systemctl", "reboot"]
                    },
                    {
                        label: "Shutdown",
                        icon: "power_settings_new",
                        cmd: ["systemctl", "poweroff"]
                    }
                ]

                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 12
                    color: btnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 0.5

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        Text {
                            text: modelData.icon
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 18
                            color: modelData.label === "Shutdown" ? "#ff5555" : (rootScope.theme ? rootScope.theme.theme_primary : "#378ADD")
                        }

                        Text {
                            text: modelData.label
                            font.family: "Rubik"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: "#ffffff"
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "chevron_right"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 16
                            color: "#a6adc8"
                        }
                    }

                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: powerViewRoot.runCommand(modelData.cmd)
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
