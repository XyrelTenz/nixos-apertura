import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: mediaControlRoot
    width: 32
    height: 32

    property var activePlayer: null

    function updateActivePlayer() {
        let playersList = Mpris.players.values;
        if (!playersList || playersList.length === 0) {
            activePlayer = null;
            return;
        }

        // 1. If any player is actively playing, set it as active
        for (let i = 0; i < playersList.length; i++) {
            let p = playersList[i];
            if (p && p.playbackState === MprisPlaybackState.Playing) {
                activePlayer = p;
                return;
            }
        }

        // 2. If the current activePlayer is still available in the list, keep it
        if (activePlayer) {
            for (let i = 0; i < playersList.length; i++) {
                if (playersList[i] === activePlayer) {
                    return;
                }
            }
        }

        // 3. Fallback to the first player in the list
        activePlayer = playersList[0];
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: mediaControlRoot.updateActivePlayer()
    }
    
    function togglePlayback() {
        if (activePlayer) {
            activePlayer.playPause();
        }
    }

    Rectangle {
        id: visualBase
        anchors.fill: parent
        color: "transparent"

        Text {
            anchors.centerIn: parent
            text: {
                if (!mediaControlRoot.activePlayer) return "music_off";
                return mediaControlRoot.activePlayer.playbackState === MprisPlaybackState.Playing 
                    ? "motion_photos_paused" 
                    : "motion_play";
            }
            font.family: "Material Symbols Outlined"
            font.pixelSize: 20
            color: {
                if (!mediaControlRoot.activePlayer) {
                    return rootScope.theme ? rootScope.theme.theme_outline : "#555555";
                }
                return rootScope.theme ? rootScope.theme.theme_fg : "#ffffff";
            }
        }

        Rectangle {
            id: interactionOverlay
            anchors.fill: parent
            radius: 0
            color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
            opacity: moduleHitbox.containsMouse ? 0.3 : 0.0
            z: 1
        }

        MouseArea {
            id: moduleHitbox
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: mediaControlRoot.activePlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton

            onClicked: {
                mediaControlRoot.togglePlayback();
            }
        }
    }
}
