import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../.."

Item {
    id: notesRoot
    implicitWidth: 32
    implicitHeight: 32

    property bool menuOpen: false
    property var notesList: [""]
    property int activeIndex: 0
    property var tasksList: []
    property bool isAlwaysVisible: false
    property bool isDetachedInstance: false
    property bool isDetachedElsewhere: false
    property string activeTab: "tasks"
    property string activeTaskStatus: "todo"
    property bool isLoaded: false

    signal closeDetachedRequested(var finalSubList, int finalSubIndex)

    function toggleMenu(): void {
        if (isDetachedElsewhere)
            return;
        if (isAlwaysVisible) {
            if (menuOpen)
                closeMenu();
            else
                openMenu();
        } else if (menuOpen) {
            closeMenu();
            if (rootScope.activeModal === "notes")
                rootScope.dismissAll();
        } else {
            openMenu();
        }
    }

    function openMenu(): void {
        rootScope.requestOpen("notes");
        menuOpen = true;
        if (!notesRoot.isAlwaysVisible)
            dismissTimer.restart();
    }

    function closeMenu(): void {
        menuOpen = false;
        dismissTimer.stop();
    }

    function detachModule(): void {
        isDetachedElsewhere = true;
        closeMenu();
        if (rootScope.activeModal === "notes")
            rootScope.dismissAll();
        let primaryScreen = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
        let initialX = 10;
        let initialY = primaryScreen ? Math.round((primaryScreen.height - 350) / 2) : 250;
        detachedWindowWrapper.createObject(rootScope, {
            "passedNotesList": notesRoot.notesList,
            "passedActiveIndex": notesRoot.activeIndex,
            "passedTasksList": notesRoot.tasksList,
            "passedAlwaysVisible": notesRoot.isAlwaysVisible,
            "spawnX": initialX
        });
    }

    Timer {
        id: dismissTimer
        interval: 3500
        running: false
        repeat: false
        onTriggered: {
            if (!notesRoot.isAlwaysVisible && !notesRoot.isDetachedElsewhere) {
                notesRoot.closeMenu();
                if (rootScope.activeModal === "notes")
                    rootScope.dismissAll();
            }
        }
    }

    Connections {
        target: rootScope
        ignoreUnknownSignals: true
        function onActiveModalChanged() {
            if (rootScope.activeModal !== "notes" && notesRoot.menuOpen && !notesRoot.isAlwaysVisible)
                notesRoot.closeMenu();
        }
    }

    function saveState() {
        if (!isLoaded)
            return;
        let data = {
            "notes": notesRoot.notesList,
            "tasks": notesRoot.tasksList
        };
        Quickshell.execDetached(["sh", "-c", "mkdir -p ~/.cache/quickshell && echo '" + JSON.stringify(data).replace(/'/g, "'\\''") + "' > " + Quickshell.env("HOME") + "/.cache/quickshell/notes_and_tasks.json"]);
    }

    FileView {
        id: stateReader
        path: Quickshell.env("HOME") + "/.cache/quickshell/notes_and_tasks.json"
        preload: true
        onTextChanged: {
            let raw = text();
            if (raw && raw.trim() !== "") {
                try {
                    let parsed = JSON.parse(raw);
                    if (parsed.notes !== undefined)
                        notesRoot.notesList = parsed.notes;
                    if (parsed.tasks !== undefined)
                        notesRoot.tasksList = parsed.tasks;
                } catch (e) {}
            }
            notesRoot.isLoaded = true;
            syncTasksModel();
        }
    }

    ListModel {
        id: todoModel
    }
    ListModel {
        id: ongoingModel
    }
    ListModel {
        id: doneModel
    }

    function syncTasksModel() {
        todoModel.clear();
        ongoingModel.clear();
        doneModel.clear();
        for (let i = 0; i < tasksList.length; i++) {
            let item = {
                "originalIndex": i,
                "taskText": tasksList[i].text,
                "status": tasksList[i].status
            };
            if (tasksList[i].status === "todo")
                todoModel.append(item);
            else if (tasksList[i].status === "ongoing")
                ongoingModel.append(item);
            else if (tasksList[i].status === "done")
                doneModel.append(item);
        }
    }

    function addTask(txt) {
        if (!txt || txt.trim() === "")
            return;
        let list = tasksList;
        list.push({
            "text": txt.trim(),
            "status": "todo"
        });
        tasksList = list;
        saveState();
        syncTasksModel();
    }

    function deleteTask(originalIdx) {
        if (originalIdx === undefined || originalIdx < 0 || originalIdx >= tasksList.length)
            return;
        let list = tasksList;
        list.splice(originalIdx, 1);
        tasksList = list;
        saveState();
        syncTasksModel();
    }

    function moveTask(originalIdx, newStatus) {
        if (originalIdx === undefined || originalIdx < 0 || originalIdx >= tasksList.length)
            return;
        let list = tasksList;
        list[originalIdx].status = newStatus;
        tasksList = list;
        saveState();
        syncTasksModel();
    }

    function updateTaskText(originalIdx, newText) {
        if (originalIdx === undefined || originalIdx < 0 || originalIdx >= tasksList.length)
            return;
        let list = tasksList;
        list[originalIdx].text = newText;
        tasksList = list;
        saveState();
        syncTasksModel();
    }

    function getTaskCount(status) {
        let count = 0;
        for (let i = 0; i < tasksList.length; i++) {
            if (tasksList[i].status === status)
                count++;
        }
        return count;
    }

    component NotesViewContainer: Item {
        id: notesViewScope
        property bool isFloating: false
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Rectangle {
                    width: 3
                    height: 16
                    color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
                }

                Item {
                    width: 8
                }

                Text {
                    text: notesRoot.activeTab === "tasks" ? "Task Board" : "Notepad"
                    font.family: "Rubik"
                    font.pixelSize: 14
                    font.weight: Font.SemiBold
                    color: rootScope.theme ? rootScope.theme.theme_fg : "#cdd6f4"
                }

                Item {
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: [
                            {
                                key: "tasks",
                                label: "Tasks"
                            },
                            {
                                key: "notes",
                                label: "Notes"
                            }
                        ]
                        delegate: Rectangle {
                            width: 54
                            height: 22
                            color: "transparent"
                            border.color: notesRoot.activeTab === modelData.key ? (rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa") : "#30ffffff"
                            border.width: 1

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 180
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: "Rubik"
                                font.pixelSize: 10
                                font.weight: notesRoot.activeTab === modelData.key ? Font.SemiBold : Font.Normal
                                color: notesRoot.activeTab === modelData.key ? (rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa") : "#66ffffff"
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 180
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    notesRoot.activeTab = modelData.key;
                                    if (modelData.key === "tasks")
                                        syncTasksModel();
                                    dismissTimer.stop();
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 48
                        height: 22
                        color: "transparent"
                        border.color: notesViewScope.isFloating ? "#66ffffff" : "#30ffffff"
                        border.width: 1

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 180
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: notesViewScope.isFloating ? "Attach" : "Pop"
                            font.family: "Rubik"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: notesViewScope.isFloating ? "#ccffffff" : "#66ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (notesViewScope.isFloating) {
                                    notesRoot.isDetachedElsewhere = false;
                                    detachedWin.destroy();
                                    notesRoot.openMenu();
                                } else {
                                    notesRoot.detachModule();
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

            Component {
                id: taskCardDelegate

                Rectangle {
                    width: ListView.view ? ListView.view.width : 150
                    height: Math.max(34, cardText.implicitHeight + 14)
                    color: "transparent"
                    border.color: cardMouseArea.containsMouse ? (rootScope.theme ? rootScope.theme.theme_primary + "55" : "#89b4fa55") : "#18ffffff"
                    border.width: 1

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 2
                        color: status === "done" ? "#33a6e3a1" : status === "ongoing" ? "#55f9e2af" : "#5589b4fa"
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                    }

                    MouseArea {
                        id: cardMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 4

                        Rectangle {
                            width: 18
                            height: 18
                            color: "transparent"
                            visible: status !== "todo"

                            Text {
                                anchors.centerIn: parent
                                text: "chevron_left"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 14
                                color: backBtnMouse.containsMouse ? "#99ffffff" : "#44ffffff"
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            MouseArea {
                                id: backBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (status === "ongoing")
                                        moveTask(originalIndex, "todo");
                                    else if (status === "done")
                                        moveTask(originalIndex, "ongoing");
                                    dismissTimer.stop();
                                }
                            }
                        }

                        TextInput {
                            id: cardText
                            text: taskText
                            font.family: "Rubik"
                            font.pixelSize: 11
                            color: status === "done" ? "#44ffffff" : "#ddffffff"
                            font.strikeout: status === "done"
                            Layout.fillWidth: true
                            selectByMouse: true
                            clip: true
                            onEditingFinished: updateTaskText(originalIndex, text)
                            onFocusChanged: {
                                if (focus)
                                    dismissTimer.stop();
                            }
                        }

                        Rectangle {
                            width: 18
                            height: 18
                            color: "transparent"
                            visible: status !== "done"

                            Text {
                                anchors.centerIn: parent
                                text: "chevron_right"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 14
                                color: fwdBtnMouse.containsMouse ? (rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa") : "#55ffffff"
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            MouseArea {
                                id: fwdBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (status === "todo")
                                        moveTask(originalIndex, "ongoing");
                                    else if (status === "ongoing")
                                        moveTask(originalIndex, "done");
                                    dismissTimer.stop();
                                }
                            }
                        }

                        Rectangle {
                            width: 18
                            height: 18
                            color: "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "close"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 12
                                color: delBtnMouse.containsMouse ? "#f38ba8" : "#33ffffff"
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            MouseArea {
                                id: delBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    deleteTask(originalIndex);
                                    dismissTimer.stop();
                                }
                            }
                        }
                    }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: notesRoot.activeTab === "tasks" ? 0 : 1

                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Repeater {
                        model: [
                            {
                                label: "Todo",
                                mdl: todoModel,
                                placeholder: "Add task…",
                                accentColor: "#89b4fa"
                            },
                            {
                                label: "Ongoing",
                                mdl: ongoingModel,
                                placeholder: null,
                                accentColor: "#f9e2af"
                            },
                            {
                                label: "Done",
                                mdl: doneModel,
                                placeholder: null,
                                accentColor: "#a6e3a1"
                            }
                        ]

                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 6

                            property var colData: modelData

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    width: 2
                                    height: 12
                                    color: colData.accentColor
                                    opacity: 0.8
                                }

                                Text {
                                    text: colData.label
                                    font.family: "Rubik"
                                    font.pixelSize: 10
                                    font.weight: Font.SemiBold
                                    color: colData.accentColor
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: colData.mdl.count
                                    font.family: "Rubik"
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: colData.accentColor
                                    opacity: 0.7
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#14ffffff"
                                border.width: 1
                                clip: true

                                ListView {
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    model: colData.mdl
                                    spacing: 4
                                    boundsBehavior: Flickable.StopAtBounds
                                    delegate: taskCardDelegate

                                    add: Transition {
                                        NumberAnimation {
                                            property: "opacity"
                                            from: 0
                                            to: 1
                                            duration: 180
                                        }
                                        NumberAnimation {
                                            property: "scale"
                                            from: 0.95
                                            to: 1
                                            duration: 180
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                    remove: Transition {
                                        NumberAnimation {
                                            property: "opacity"
                                            from: 1
                                            to: 0
                                            duration: 130
                                        }
                                    }
                                }

                                Text {
                                    visible: colData.mdl.count === 0
                                    anchors.centerIn: parent
                                    text: "Empty"
                                    font.family: "Rubik"
                                    font.pixelSize: 10
                                    color: "#22ffffff"
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                visible: colData.placeholder !== null

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 26
                                    color: "transparent"
                                    border.color: newTodoInput.activeFocus ? (rootScope.theme ? rootScope.theme.theme_primary + "99" : "#89b4fa99") : "#20ffffff"
                                    border.width: 1

                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }

                                    TextField {
                                        id: newTodoInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        placeholderText: colData.placeholder || ""
                                        font.family: "Rubik"
                                        font.pixelSize: 10
                                        color: "#ddffffff"
                                        background: null
                                        placeholderTextColor: "#33ffffff"
                                        Keys.onPressed: event => {
                                            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                                addTask(text);
                                                text = "";
                                            }
                                        }
                                        onFocusChanged: {
                                            if (focus)
                                                dismissTimer.stop();
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 26
                                    height: 26
                                    color: "transparent"
                                    border.color: addBtnMouse.containsMouse ? (rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa") : "#20ffffff"
                                    border.width: 1

                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "add"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 13
                                        color: addBtnMouse.containsMouse ? (rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa") : "#55ffffff"
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 150
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: addBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            addTask(newTodoInput.text);
                                            newTodoInput.text = "";
                                            dismissTimer.stop();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    spacing: 8

                    ScrollView {
                        Layout.fillWidth: true
                        height: 28
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        ScrollBar.horizontal.policy: ScrollBar.AsNeeded

                        Row {
                            id: tabRow
                            spacing: 4
                            width: implicitWidth

                            Rectangle {
                                width: 26
                                height: 26
                                color: "transparent"
                                border.color: addMouse.containsMouse ? "#44ffffff" : "#20ffffff"
                                border.width: 1

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "add"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 13
                                    color: addMouse.containsMouse ? "#99ffffff" : "#44ffffff"
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }
                                }

                                MouseArea {
                                    id: addMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var list = notesRoot.notesList;
                                        list.push("");
                                        notesRoot.notesList = list.slice();
                                        notesRoot.activeIndex = notesRoot.notesList.length - 1;
                                        notesRepeater.model = notesRoot.notesList;
                                        saveState();
                                        dismissTimer.stop();
                                    }
                                }
                            }

                            Repeater {
                                id: notesRepeater
                                model: notesRoot.notesList
                                delegate: Rectangle {
                                    width: tabText.implicitWidth + 36
                                    height: 26
                                    color: "transparent"
                                    border.color: notesRoot.activeIndex === index ? (rootScope.theme ? rootScope.theme.theme_primary + "88" : "#89b4fa88") : (tabMouse.containsMouse ? "#30ffffff" : "#18ffffff")
                                    border.width: 1

                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }

                                    Rectangle {
                                        visible: notesRoot.activeIndex === index
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 1
                                        color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
                                        opacity: 0.6
                                    }

                                    Text {
                                        id: tabText
                                        anchors.left: parent.left
                                        anchors.leftMargin: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Note " + (index + 1)
                                        font.family: "Rubik"
                                        font.pixelSize: 10
                                        font.weight: notesRoot.activeIndex === index ? Font.SemiBold : Font.Normal
                                        color: notesRoot.activeIndex === index ? "#ddffffff" : "#66ffffff"
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 150
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "close"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 10
                                        color: closeTabMouse.containsMouse ? "#f38ba8" : "#33ffffff"
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                            }
                                        }

                                        MouseArea {
                                            id: closeTabMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var list = notesRoot.notesList;
                                                if (list.length > 1) {
                                                    list.splice(index, 1);
                                                    let nextIndex = notesRoot.activeIndex;
                                                    if (nextIndex >= list.length)
                                                        nextIndex = list.length - 1;
                                                    notesRoot.notesList = list.slice();
                                                    notesRoot.activeIndex = nextIndex;
                                                    notesRepeater.model = notesRoot.notesList;
                                                } else if (list.length === 1) {
                                                    list[0] = "";
                                                    notesRoot.notesList = list.slice();
                                                    notesRoot.activeIndex = 0;
                                                    notesRepeater.model = notesRoot.notesList;
                                                }
                                                saveState();
                                                dismissTimer.stop();
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: tabMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            notesRoot.activeIndex = index;
                                            dismissTimer.stop();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "transparent"
                        border.color: "#14ffffff"
                        border.width: 1

                        ScrollView {
                            id: noteScroll
                            anchors.fill: parent
                            clip: true

                            TextArea {
                                id: noteTextArea
                                width: noteScroll.width
                                height: noteScroll.height
                                font.family: "Rubik"
                                font.pixelSize: 12
                                color: "#ddffffff"
                                wrapMode: TextEdit.WordWrap
                                selectByMouse: true
                                background: null
                                padding: 12
                                placeholderText: "Start writing…"
                                placeholderTextColor: "#28ffffff"
                                text: notesRoot.notesList[notesRoot.activeIndex] || ""

                                onTextChanged: {
                                    if (focus) {
                                        var list = notesRoot.notesList;
                                        list[notesRoot.activeIndex] = text;
                                        notesRoot.notesList = list.slice();
                                        saveState();
                                    }
                                }
                                onFocusChanged: {
                                    if (focus)
                                        dismissTimer.stop();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: detachedWindowWrapper

        PanelWindow {
            id: detachedWin
            visible: !(typeof rootScope !== 'undefined' && rootScope.screenshotMode)
            WlrLayershell.layer: isAlwaysVisibleState ? WlrLayer.Overlay : WlrLayer.Bottom
            WlrLayershell.namespace: "quickshell-detached-note"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            mask: detachedFrameBounds

            Region {
                id: detachedFrameBounds
                item: detachedFrame
            }

            property var passedNotesList: [""]
            property int passedActiveIndex: 0
            property var passedTasksList: []
            property bool passedAlwaysVisible: false
            property int spawnX: 10
            property bool isAlwaysVisibleState: passedAlwaysVisible

            Component.onCompleted: {
                notesRoot.notesList = passedNotesList;
                notesRoot.activeIndex = passedActiveIndex;
                notesRoot.tasksList = passedTasksList;
                notesRoot.isAlwaysVisible = passedAlwaysVisible;
                detachedFrame.posX = spawnX;
                notesRoot.syncTasksModel();
            }

            Rectangle {
                id: detachedFrame
                property int posX: 10
                property int posY: 100
                property bool initialized: false

                x: posX
                y: posY
                width: 620
                height: 390
                color: "#9911111b"
                border.color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
                border.width: 1

                layer.enabled: true

                NotesViewContainer {
                    isFloating: true
                }

                Connections {
                    target: detachedWin
                    function onHeightChanged() {
                        if (!detachedFrame.initialized && detachedWin.height > 0) {
                            detachedFrame.posY = detachedWin.height - detachedFrame.height - 12;
                            detachedFrame.initialized = true;
                        }
                    }
                }

                MouseArea {
                    id: internalFrameDrag
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: containsMouse ? Qt.SizeAllCursor : Qt.ArrowCursor
                    z: -2
                    property int clickOffsetX: 0
                    property int clickOffsetY: 0
                    onPressed: mouse => {
                        clickOffsetX = mouse.x;
                        clickOffsetY = mouse.y;
                    }
                    onPositionChanged: mouse => {
                        if (pressed) {
                            detachedFrame.posX = detachedFrame.posX + mouse.x - clickOffsetX;
                            detachedFrame.posY = detachedFrame.posY + mouse.y - clickOffsetY;
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: notesHitbox
        anchors.fill: parent
        color: "transparent"
        opacity: notesRoot.isDetachedElsewhere ? 0.3 : 1.0
        visible: !notesRoot.isDetachedInstance

        Text {
            anchors.centerIn: parent
            text: "description"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 18
            color: notesMouseArea.containsMouse && !notesRoot.isDetachedElsewhere ? (rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa") : (rootScope.theme ? rootScope.theme.theme_fg : "#cdd6f4")
            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }
        }

        MouseArea {
            id: notesMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: notesRoot.isDetachedElsewhere ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: toggleMenu()
        }
    }

    PanelWindow {
        id: notesOverlayModal
        visible: !notesRoot.isDetachedElsewhere && (notesRoot.menuOpen || notesRoot.isAlwaysVisible) && !(typeof rootScope !== 'undefined' && rootScope.screenshotMode)
        color: "transparent"
        anchors {
            left: true
            top: true
            bottom: true
            right: true
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        mask: notesRoot.isAlwaysVisible ? notesInputBounds : null

        Region {
            id: notesInputBounds
            item: popupMenuFrame
        }

        onVisibleChanged: {
            if (visible && notesRoot.menuOpen)
                popupMenuFrame.forceActiveFocus();
        }

        MouseArea {
            anchors.fill: parent
            enabled: !notesRoot.isAlwaysVisible
            onClicked: {
                closeMenu();
                if (rootScope.activeModal === "notes")
                    rootScope.dismissAll();
            }
        }

        Rectangle {
            id: popupMenuFrame
            height: 390
            x: 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            color: "#9911111b"
            border.width: 0
            focus: true
            clip: true

            layer.enabled: true

            states: [
                State {
                    name: "visible"
                    when: !notesRoot.isDetachedElsewhere && (notesRoot.menuOpen || notesRoot.isAlwaysVisible)
                    PropertyChanges {
                        target: popupMenuFrame
                        width: 620
                        opacity: 1.0
                    }
                },
                State {
                    name: "hidden"
                    when: notesRoot.isDetachedElsewhere || (!notesRoot.menuOpen && !notesRoot.isAlwaysVisible)
                    PropertyChanges {
                        target: popupMenuFrame
                        width: 0
                        opacity: 0.0
                    }
                }
            ]

            transitions: [
                Transition {
                    from: "hidden"
                    to: "visible"
                    ParallelAnimation {
                        NumberAnimation {
                            property: "width"
                            duration: Config.entryDuration
                            easing.type: Config.entryEasing
                        }
                        NumberAnimation {
                            property: "opacity"
                            duration: 180
                            easing.type: Easing.OutQuad
                        }
                    }
                },
                Transition {
                    from: "visible"
                    to: "hidden"
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation {
                                property: "width"
                                duration: Config.exitDuration
                                easing.type: Config.exitEasing
                            }
                            NumberAnimation {
                                property: "opacity"
                                duration: Config.exitDuration
                                easing.type: Config.exitEasing
                            }
                        }
                    }
                }
            ]

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape && !notesRoot.isAlwaysVisible) {
                    closeMenu();
                    if (rootScope.activeModal === "notes")
                        rootScope.dismissAll();
                    event.accepted = true;
                }
            }

            MouseArea {
                id: mainContentArea
                anchors.fill: parent
                hoverEnabled: true
                onPressed: mouse => {
                    mouse.accepted = true;
                }
                onEntered: dismissTimer.stop()
                onExited: {
                    if (!notesRoot.isAlwaysVisible && notesRoot.menuOpen)
                        dismissTimer.restart();
                }

                Item {
                    id: textContentGroup
                    anchors.fill: parent
                    opacity: popupMenuFrame.width > Config.contentFadeThreshold ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }

                    NotesViewContainer {
                        isFloating: false
                    }
                }
            }
        }
    }
}
