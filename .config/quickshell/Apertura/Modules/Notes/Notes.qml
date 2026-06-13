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
    property string activeTab: "tasks" // "tasks" or "notes"
    property string activeTaskStatus: "todo" // "todo", "ongoing", "done"
    property bool isLoaded: false

    signal closeDetachedRequested(var finalSubList, int finalSubIndex)

    function toggleMenu(): void {
        if (isDetachedElsewhere) return;
        if (isAlwaysVisible) {
            if (menuOpen) closeMenu();
            else openMenu();
        } else if (menuOpen) {
            closeMenu();
            if (rootScope.activeModal === "notes") rootScope.dismissAll();
        } else {
            openMenu();
        }
    }

    function openMenu(): void {
        rootScope.requestOpen("notes");
        menuOpen = true;
        if (!notesRoot.isAlwaysVisible) dismissTimer.restart();
    }

    function closeMenu(): void {
        menuOpen = false; 
        dismissTimer.stop();
    }

    function detachModule(): void {
        isDetachedElsewhere = true;
        closeMenu();
        if (rootScope.activeModal === "notes") rootScope.dismissAll();
        
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
                if (rootScope.activeModal === "notes") rootScope.dismissAll();
            }
        }
    }

    Connections {
        target: rootScope
        ignoreUnknownSignals: true
        function onActiveModalChanged() {
            if (rootScope.activeModal !== "notes" && notesRoot.menuOpen && !notesRoot.isAlwaysVisible) {
                notesRoot.closeMenu();
            }
        }
    }

    function saveState() {
        if (!isLoaded) return;
        let data = {
            "notes": notesRoot.notesList,
            "tasks": notesRoot.tasksList
        };
        Quickshell.execDetached([
            "sh", "-c",
            "mkdir -p ~/.cache/quickshell && echo '" + JSON.stringify(data).replace(/'/g, "'\\''") + "' > " + Quickshell.env("HOME") + "/.cache/quickshell/notes_and_tasks.json"
        ]);
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
                    if (parsed.notes !== undefined) notesRoot.notesList = parsed.notes;
                    if (parsed.tasks !== undefined) notesRoot.tasksList = parsed.tasks;
                } catch(e) {}
            }
            notesRoot.isLoaded = true;
            syncTasksModel();
        }
    }

    ListModel { id: todoModel }
    ListModel { id: ongoingModel }
    ListModel { id: doneModel }

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
            if (tasksList[i].status === "todo") {
                todoModel.append(item);
            } else if (tasksList[i].status === "ongoing") {
                ongoingModel.append(item);
            } else if (tasksList[i].status === "done") {
                doneModel.append(item);
            }
        }
    }

    function addTask(txt) {
        if (!txt || txt.trim() === "") return;
        let list = tasksList;
        list.push({ "text": txt.trim(), "status": "todo" });
        tasksList = list;
        saveState();
        syncTasksModel();
    }

    function deleteTask(originalIdx) {
        if (originalIdx === undefined || originalIdx < 0 || originalIdx >= tasksList.length) return;
        let list = tasksList;
        list.splice(originalIdx, 1);
        tasksList = list;
        saveState();
        syncTasksModel();
    }

    function moveTask(originalIdx, newStatus) {
        if (originalIdx === undefined || originalIdx < 0 || originalIdx >= tasksList.length) return;
        let list = tasksList;
        list[originalIdx].status = newStatus;
        tasksList = list;
        saveState();
        syncTasksModel();
    }

    function updateTaskText(originalIdx, newText) {
        if (originalIdx === undefined || originalIdx < 0 || originalIdx >= tasksList.length) return;
        let list = tasksList;
        list[originalIdx].text = newText;
        tasksList = list;
        saveState();
        syncTasksModel();
    }

    function getTaskCount(status) {
        let count = 0;
        for (let i = 0; i < tasksList.length; i++) {
            if (tasksList[i].status === status) count++;
        }
        return count;
    }

    component NotesViewContainer : Item {
        id: notesViewScope
        property bool isFloating: false
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            // Top Header & Control buttons
            RowLayout {
                Layout.fillWidth: true
                
                Text { 
                    text: notesRoot.activeTab === "tasks" ? "Task Board" : "Notepad"
                    font.family: "Rubik"
                    font.pixelSize: 15; font.weight: Font.Bold
                    color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" 
                }
                
                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    // Mode switch buttons
                    Rectangle {
                        width: 50; height: 22; radius: 4
                        color: notesRoot.activeTab === "tasks" ? (rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa") : "transparent"
                        border.color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "Tasks"
                            font.family: "Rubik"; font.pixelSize: 10; font.bold: true
                            color: notesRoot.activeTab === "tasks" ? (rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b") : (rootScope.theme ? rootScope.theme.theme_fg : "#ffffff")
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { notesRoot.activeTab = "tasks"; syncTasksModel(); dismissTimer.stop(); }
                        }
                    }

                    Rectangle {
                        width: 50; height: 22; radius: 4
                        color: notesRoot.activeTab === "notes" ? (rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa") : "transparent"
                        border.color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "Notes"
                            font.family: "Rubik"; font.pixelSize: 10; font.bold: true
                            color: notesRoot.activeTab === "notes" ? (rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b") : (rootScope.theme ? rootScope.theme.theme_fg : "#ffffff")
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { notesRoot.activeTab = "notes"; dismissTimer.stop(); }
                        }
                    }

                    // Detach Button
                    Rectangle {
                        id: detachActionButton
                        width: 44; height: 22; radius: 4
                        color: notesViewScope.isFloating ? (rootScope.theme ? rootScope.theme.theme_outline : "#45ffffff") : "transparent"
                        border.width: 1
                        border.color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"

                        Text {
                            anchors.centerIn: parent
                            text: notesViewScope.isFloating ? "Attach" : "Pop"
                            font.family: "Rubik"; font.pixelSize: 10; font.weight: Font.Bold
                            color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
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

            Component {
                id: taskCardDelegate
                Rectangle {
                    width: ListView.view ? ListView.view.width : 150
                    height: Math.max(34, cardText.implicitHeight + 14)
                    color: (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff")
                    radius: 6
                    border.color: cardMouseArea.containsMouse ? (rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa") : "transparent"
                    border.width: 1

                    MouseArea {
                        id: cardMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6; anchors.rightMargin: 6
                        spacing: 4

                        // Left Arrow to move back
                        Rectangle {
                            width: 18; height: 18; radius: 9
                            color: backBtnMouse.containsMouse ? "#1affffff" : "transparent"
                            visible: status !== "todo"
                            Text {
                                anchors.centerIn: parent
                                text: "chevron_left"
                                font.family: "Material Symbols Outlined"; font.pixelSize: 14
                                color: rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff"
                            }
                            MouseArea {
                                id: backBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (status === "ongoing") moveTask(originalIndex, "todo");
                                    else if (status === "done") moveTask(originalIndex, "ongoing");
                                    dismissTimer.stop();
                                }
                            }
                        }

                        // Task Text (Editable)
                        TextInput {
                            id: cardText
                            text: taskText
                            font.family: "Rubik"; font.pixelSize: 11
                            color: status === "done" ? (rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff") : (rootScope.theme ? rootScope.theme.theme_fg : "#ffffff")
                            font.strikeout: status === "done"
                            Layout.fillWidth: true
                            selectByMouse: true
                            clip: true
                            onEditingFinished: {
                                updateTaskText(originalIndex, text);
                            }
                            onFocusChanged: {
                                if (focus) dismissTimer.stop();
                            }
                        }

                        // Right Arrow to move forward
                        Rectangle {
                            width: 18; height: 18; radius: 9
                            color: fwdBtnMouse.containsMouse ? "#1affffff" : "transparent"
                            visible: status !== "done"
                            Text {
                                anchors.centerIn: parent
                                text: "chevron_right"
                                font.family: "Material Symbols Outlined"; font.pixelSize: 14
                                color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
                            }
                            MouseArea {
                                id: fwdBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (status === "todo") moveTask(originalIndex, "ongoing");
                                    else if (status === "ongoing") moveTask(originalIndex, "done");
                                    dismissTimer.stop();
                                }
                            }
                        }

                        // Delete Button
                        Rectangle {
                            width: 18; height: 18; radius: 4
                            color: delBtnMouse.containsMouse ? "#33ff5555" : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "close"
                                font.family: "Material Symbols Outlined"; font.pixelSize: 14
                                color: delBtnMouse.containsMouse ? "#ff5555" : (rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff")
                            }
                            MouseArea {
                                id: delBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    deleteTask(originalIndex);
                                    dismissTimer.stop();
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff" }

            // Dynamic Stack based on Mode
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: notesRoot.activeTab === "tasks" ? 0 : 1

                // ================== TASKS MODE (3-column Kanban Board) ==================
                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // --- TODO COLUMN ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: "Todo"
                                font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold
                                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                            }
                            Rectangle {
                                width: 15; height: 15; radius: 7.5
                                color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
                                Text {
                                    anchors.centerIn: parent
                                    text: todoModel.count
                                    font.family: "Rubik"; font.pixelSize: 9; font.bold: true
                                    color: rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b"
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            color: "transparent"
                            border.color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
                            border.width: 1
                            radius: 6
                            clip: true

                            ListView {
                                id: todoListView
                                anchors.fill: parent; anchors.margins: 4
                                model: todoModel
                                spacing: 4
                                boundsBehavior: Flickable.StopAtBounds
                                delegate: taskCardDelegate
                            }

                            Text {
                                visible: todoModel.count === 0
                                anchors.centerIn: parent
                                text: "No tasks"
                                font.family: "Rubik"; font.pixelSize: 10
                                color: rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff"
                            }
                        }

                        // Task Input
                        RowLayout {
                            Layout.fillWidth: true; spacing: 4
                            TextField {
                                id: newTodoInput
                                Layout.fillWidth: true; height: 26
                                placeholderText: "Add todo..."
                                font.family: "Rubik"; font.pixelSize: 10
                                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                                background: Rectangle {
                                    color: rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b"
                                    border.color: newTodoInput.activeFocus ? (rootScope.theme ? rootScope.theme.theme_primary : "#ffffff") : (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff")
                                    border.width: 1; radius: 4
                                }
                                Keys.onPressed: (event) => {
                                    if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                        addTask(text);
                                        text = "";
                                    }
                                }
                                onFocusChanged: { if (focus) dismissTimer.stop(); }
                            }
                            Rectangle {
                                width: 26; height: 26; radius: 4
                                color: addTodoBtnMouse.containsMouse ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : (rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b")
                                border.color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
                                border.width: 1
                                Text { anchors.centerIn: parent; text: "add"; font.family: "Material Symbols Outlined"; font.pixelSize: 14; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" }
                                MouseArea {
                                    id: addTodoBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { addTask(newTodoInput.text); newTodoInput.text = ""; dismissTimer.stop(); }
                                }
                            }
                        }
                    }

                    // --- ONGOING COLUMN ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Text {
                                text: "Ongoing"
                                font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold
                                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                            }
                            Rectangle {
                                width: 15; height: 15; radius: 7.5
                                color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
                                Text {
                                    anchors.centerIn: parent
                                    text: ongoingModel.count
                                    font.family: "Rubik"; font.pixelSize: 9; font.bold: true
                                    color: rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b"
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            color: "transparent"
                            border.color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
                            border.width: 1
                            radius: 6
                            clip: true

                            ListView {
                                id: ongoingListView
                                anchors.fill: parent; anchors.margins: 4
                                model: ongoingModel
                                spacing: 4
                                boundsBehavior: Flickable.StopAtBounds
                                delegate: taskCardDelegate
                            }

                            Text {
                                visible: ongoingModel.count === 0
                                anchors.centerIn: parent
                                text: "No ongoing"
                                font.family: "Rubik"; font.pixelSize: 10
                                color: rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff"
                            }
                        }
                    }

                    // --- DONE COLUMN ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Text {
                                text: "Done"
                                font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold
                                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                            }
                            Rectangle {
                                width: 15; height: 15; radius: 7.5
                                color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
                                Text {
                                    anchors.centerIn: parent
                                    text: doneModel.count
                                    font.family: "Rubik"; font.pixelSize: 9; font.bold: true
                                    color: rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b"
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            color: "transparent"
                            border.color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
                            border.width: 1
                            radius: 6
                            clip: true

                            ListView {
                                id: doneListView
                                anchors.fill: parent; anchors.margins: 4
                                model: doneModel
                                spacing: 4
                                boundsBehavior: Flickable.StopAtBounds
                                delegate: taskCardDelegate
                            }

                            Text {
                                visible: doneModel.count === 0
                                anchors.centerIn: parent
                                text: "No completed"
                                font.family: "Rubik"; font.pixelSize: 10
                                color: rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff"
                            }
                        }
                    }
                }

                // ================== NOTEPAD MODE ==================
                ColumnLayout {
                    spacing: 8

                    ScrollView {
                        Layout.fillWidth: true
                        id: tabScrollView
                        height: 32
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        ScrollBar.horizontal.policy: ScrollBar.AsNeeded

                        Row {
                            id: tabRow
                            spacing: 6
                            width: implicitWidth

                            Rectangle {
                                width: 24; height: 24; radius: 4
                                color: addMouse.containsMouse ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : "transparent"
                                border.width: 1
                                border.color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"

                                Text {
                                    anchors.centerIn: parent
                                    text: "add"
                                    font.family: "Material Symbols Outlined"; font.pixelSize: 14
                                    color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                                }

                                MouseArea {
                                    id: addMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
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
                                    height: 24
                                    color: notesRoot.activeIndex === index ? (rootScope.theme ? rootScope.theme.theme_outline : "#45ffffff") : (tabMouse.containsMouse ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : "transparent")
                                    border.width: notesRoot.activeIndex === index ? 0 : 1
                                    border.color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
                                    radius: 4

                                    Text {
                                        id: tabText
                                        anchors.left: parent.left; anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Note " + (index + 1)
                                        font.family: "Rubik"; font.pixelSize: 11; font.weight: Font.Medium
                                        color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                                    }

                                    Text {
                                        anchors.right: parent.right; anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "close"
                                        font.family: "Material Symbols Outlined"; font.pixelSize: 12
                                        color: closeTabMouse.containsMouse ? (rootScope.theme ? rootScope.theme.theme_fg : "#ffffff") : (rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff")

                                        MouseArea {
                                            id: closeTabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var list = notesRoot.notesList;
                                                if (list.length > 1) {
                                                    list.splice(index, 1);
                                                    let nextIndex = notesRoot.activeIndex;
                                                    if (nextIndex >= list.length) nextIndex = list.length - 1;
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
                                        id: tabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { notesRoot.activeIndex = index; dismissTimer.stop(); }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        color: "transparent"
                        border.color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
                        border.width: 1
                        radius: 4

                        ScrollView {
                            id: noteScroll
                            anchors.fill: parent
                            clip: true

                            TextArea {
                                id: noteTextArea
                                width: noteScroll.width
                                height: noteScroll.height
                                font.family: "Rubik"; font.pixelSize: 12
                                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                                wrapMode: TextEdit.WordWrap
                                selectByMouse: true
                                background: null
                                padding: 8
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
                                    if (focus) dismissTimer.stop();
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
            WlrLayershell.layer: isAlwaysVisibleState ? WlrLayer.Overlay : WlrLayer.Bottom
            WlrLayershell.namespace: "quickshell-detached-note"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            mask: detachedFrameBounds

            Region { id: detachedFrameBounds; item: detachedFrame }
            
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

                x: posX; y: posY
                width: 600; height: 380
                color: "#9911111b"
                radius: 8
                border.color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
                border.width: 1
                
                NotesViewContainer { isFloating: true }

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

                    onPressed: (mouse) => {
                        clickOffsetX = mouse.x
                        clickOffsetY = mouse.y
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed) {
                            detachedFrame.posX = detachedFrame.posX + mouse.x - clickOffsetX
                            detachedFrame.posY = detachedFrame.posY + mouse.y - clickOffsetY
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
        radius: 0
        opacity: notesRoot.isDetachedElsewhere ? 0.3 : 1.0
        visible: !notesRoot.isDetachedInstance 

        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "description" 
                font.family: "Material Symbols Outlined"; font.pixelSize: 20
                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
            }
        }

        Rectangle {
            id: notesHoverOverlay
            anchors.fill: parent; radius: 0
            color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
            opacity: notesMouseArea.containsMouse && !notesRoot.isDetachedElsewhere ? 0.3 : 0.0
            z: 1
        }

        MouseArea {
            id: notesMouseArea
            anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton 
            cursorShape: notesRoot.isDetachedElsewhere ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: toggleMenu()
        }
    }

    PanelWindow {
        id: notesOverlayModal
        visible: !notesRoot.isDetachedElsewhere && (notesRoot.menuOpen || notesRoot.isAlwaysVisible)
        color: "transparent"
        anchors { left: true; top: true; bottom: true; right: true }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        mask: notesRoot.isAlwaysVisible ? notesInputBounds : null

        Region { id: notesInputBounds; item: popupMenuFrame }

        onVisibleChanged: {
            if (visible && notesRoot.menuOpen) popupMenuFrame.forceActiveFocus();
        }

        MouseArea {
            anchors.fill: parent; enabled: !notesRoot.isAlwaysVisible
            onClicked: {
                closeMenu();
                if (rootScope.activeModal === "notes") rootScope.dismissAll();
            }
        }

        Rectangle {
            id: popupMenuFrame
            height: 380
            x: 0
            anchors.bottom: parent.bottom; anchors.bottomMargin: 12
            color: "#9911111b"
            border.color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
            border.width: 1
            radius: 8
            focus: true; clip: true

            states: [
                State {
                    name: "visible"
                    when: !notesRoot.isDetachedElsewhere && (notesRoot.menuOpen || notesRoot.isAlwaysVisible)
                    PropertyChanges { target: popupMenuFrame; width: 600; opacity: 1.0 }
                },
                State {
                    name: "hidden"
                    when: notesRoot.isDetachedElsewhere || (!notesRoot.menuOpen && !notesRoot.isAlwaysVisible)
                    PropertyChanges { target: popupMenuFrame; width: 0; opacity: 0.0 }
                }
            ]

            transitions: [
                Transition {
                    from: "hidden"; to: "visible"
                    ParallelAnimation {
                        NumberAnimation { property: "width"; duration: Config.entryDuration; easing.type: Config.entryEasing }
                        NumberAnimation { property: "opacity"; duration: 150; easing.type: Easing.OutQuad }
                    }
                },
                Transition {
                    from: "visible"; to: "hidden"
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation { property: "width"; duration: Config.exitDuration; easing.type: Config.exitEasing }
                            NumberAnimation { property: "opacity"; duration: Config.exitDuration; easing.type: Config.exitEasing }
                        }
                    }
                }
            ]

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape && !notesRoot.isAlwaysVisible) {
                    closeMenu();
                    if (rootScope.activeModal === "notes") rootScope.dismissAll();
                    event.accepted = true;
                }
            }

            MouseArea {
                id: mainContentArea
                anchors.fill: parent; hoverEnabled: true
                onPressed: (mouse) => { mouse.accepted = true; }
                onEntered: dismissTimer.stop()
                onExited: {
                    if (!notesRoot.isAlwaysVisible && notesRoot.menuOpen) dismissTimer.restart();
                }

                Item {
                    id: textContentGroup
                    anchors.fill: parent
                    opacity: popupMenuFrame.width > Config.contentFadeThreshold ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                    NotesViewContainer { isFloating: false }
                }
            }
        }
    }
}
