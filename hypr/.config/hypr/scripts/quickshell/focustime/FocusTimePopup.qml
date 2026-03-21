import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtCore
import Quickshell
import Quickshell.Io

Item {
    id: window

    // -------------------------------------------------------------------------
    // COLORS (Catppuccin Mocha)
    // -------------------------------------------------------------------------
    readonly property color base: "#1e1e2e"
    readonly property color mantle: "#181825"
    readonly property color crust: "#11111b"
    readonly property color text: "#cdd6f4"
    readonly property color subtext0: "#a6adc8"
    readonly property color overlay0: "#6c7086"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    
    readonly property color mauve: "#cba6f7"
    readonly property color pink: "#f5c2e7"
    readonly property color red: "#f38ba8"
    readonly property color peach: "#fab387"
    readonly property color yellow: "#f9e2af"
    readonly property color green: "#a6e3a1"
    readonly property color sapphire: "#74c7ec"
    readonly property color blue: "#89b4fa"

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    // -------------------------------------------------------------------------
    // STATE & POLLING PATHS
    // -------------------------------------------------------------------------
    property var targetDate: new Date()
    property string selectedDateStr: ""
    property int totalSeconds: 0
    property string liveActiveApp: "Desktop"
    property var topApps: []
    property var weekData: []
    property real maxWeekTotal: 1 
    property var monthData: []
    property real maxMonthTotal: 1
    
    // Animation properties
    property real animatedTotalSeconds: 0
    Behavior on animatedTotalSeconds {
        NumberAnimation { duration: 850; easing.type: Easing.OutQuint }
    }
    onTotalSecondsChanged: {
        animatedTotalSeconds = totalSeconds;
    }

    property bool isFirstLoad: true
    readonly property bool isTodaySelected: window.selectedDateStr === getIsoDate(new Date())

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/focustime"
    readonly property string xdgRuntime: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string stateFilePath: window.xdgRuntime + "/focustime_state.json"

    property real introState: 0.0
    Component.onCompleted: {
        introState = 1.0;
        if (window.isTodaySelected) {
            liveFileReader.running = true;
        } else {
            historicalPoller.running = true;
        }
    }
    Behavior on introState { NumberAnimation { duration: 800; easing.type: Easing.OutExpo } }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 120000; loops: Animation.Infinite; running: true
    }

    // --- SHARED DATA INGESTION ---
    function updateFromData(data) {
        window.selectedDateStr = data.selected_date;
        window.totalSeconds = data.total || 0;
        window.liveActiveApp = data.current || "Unknown";

        if (window.isFirstLoad) firstLoadTimer.start();

        window.topApps = data.apps || [];
        syncAppsModel();

        let parsedWeek = data.week || [];
        if (JSON.stringify(window.weekData) !== JSON.stringify(parsedWeek)) {
            window.weekData = parsedWeek;
            syncWeekModel();
        }

        let parsedMonth = data.month || [];
        if (JSON.stringify(window.monthData) !== JSON.stringify(parsedMonth)) {
            window.monthData = parsedMonth;
            syncMonthModel();
        }
    }

    // --- LIVE FILE READER ---
    Process {
        id: liveFileReader
        command: ["cat", window.stateFilePath]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text.trim();
                if (raw === "") return;
                try {
                    let data = JSON.parse(raw);
                    window.updateFromData(data);
                } catch(e) {}
            }
        }
    }

    Timer { 
        interval: 1000
        running: window.isTodaySelected 
        repeat: true
        onTriggered: liveFileReader.running = true 
    }

    // --- HISTORICAL DATA FETCHER ---
    Process {
        id: historicalPoller
        command: ["python3", window.scriptsDir + "/get_stats.py", getIsoDate(window.targetDate)]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text.trim();
                if (raw === "") return;
                try {
                    let data = JSON.parse(raw);
                    window.updateFromData(data);
                } catch(e) {}
            }
        }
    }

    // --- DATE HELPERS ---
    function getIsoDate(d) {
        let z = d.getTimezoneOffset() * 60000;
        return (new Date(d - z)).toISOString().slice(0, 10);
    }

    function getFancyDate(d) {
        let monthName = window.monthNames[d.getMonth()];
        let dateNum = d.getDate();
        
        let todayIso = getIsoDate(new Date());
        let isToday = getIsoDate(d) === todayIso;
        
        return isToday ? "Today" : `${monthName} ${dateNum}`;
    }

    function changeDay(offsetDays) {
        let d = new Date(targetDate);
        d.setDate(d.getDate() + offsetDays);
        targetDate = d;
        window.isFirstLoad = true; 
        
        if (getIsoDate(targetDate) === getIsoDate(new Date())) {
            liveFileReader.running = true;
        } else {
            historicalPoller.running = true;
        }
    }
    
    // Completely bypasses UTC timezone drifting by forcing Noon local time
    function changeToDate(clickedDateStr) {
        if (!clickedDateStr) return;
        let currentIso = getIsoDate(window.targetDate);
        if (clickedDateStr === currentIso) return;
        
        // Append T12:00:00 to avoid any timezone/DST rounding errors
        let dCurrent = new Date(currentIso + "T12:00:00");
        let dClicked = new Date(clickedDateStr + "T12:00:00");
        
        let diffDays = Math.round((dClicked - dCurrent) / (1000 * 60 * 60 * 24));
        if (diffDays !== 0) {
            changeDay(diffDays);
        }
    }

    Timer {
        id: firstLoadTimer
        interval: 1000
        onTriggered: window.isFirstLoad = false
    }

    ListModel { id: appListModel }
    ListModel { id: weekListModel }
    ListModel { id: monthListModel }

    function syncAppsModel() {
        for (let i = 0; i < window.topApps.length; i++) {
            let app = window.topApps[i];
            if (i < appListModel.count) {
                appListModel.setProperty(i, "name", app.name);
                appListModel.setProperty(i, "seconds", app.seconds);
                appListModel.setProperty(i, "percent", app.percent);
            } else {
                appListModel.append({
                    name: app.name,
                    seconds: app.seconds,
                    percent: app.percent,
                    idx: i
                });
            }
        }
        while (appListModel.count > window.topApps.length) {
            appListModel.remove(appListModel.count - 1);
        }
    }

    function syncWeekModel() {
        let currentMax = 1;
        for (let i = 0; i < window.weekData.length; i++) {
            if (window.weekData[i].total > currentMax) currentMax = window.weekData[i].total;
        }
        window.maxWeekTotal = currentMax;

        for (let i = 0; i < window.weekData.length; i++) {
            let w = window.weekData[i];
            if (i < weekListModel.count) {
                weekListModel.setProperty(i, "dateStr", w.date);
                weekListModel.setProperty(i, "dayName", w.day);
                weekListModel.setProperty(i, "total", w.total);
                weekListModel.setProperty(i, "isTarget", w.is_target);
            } else {
                weekListModel.append({
                    dateStr: w.date,
                    dayName: w.day,
                    total: w.total,
                    isTarget: w.is_target
                });
            }
        }
        while (weekListModel.count > window.weekData.length) {
            weekListModel.remove(weekListModel.count - 1);
        }
    }

    function syncMonthModel() {
        let currentMax = 1;
        for (let i = 0; i < window.monthData.length; i++) {
            if (window.monthData[i].total > currentMax) currentMax = window.monthData[i].total;
        }
        window.maxMonthTotal = currentMax;

        for (let i = 0; i < window.monthData.length; i++) {
            let m = window.monthData[i];
            if (i < monthListModel.count) {
                monthListModel.setProperty(i, "dateStr", m.date);
                monthListModel.setProperty(i, "total", m.total);
                monthListModel.setProperty(i, "isTarget", m.is_target);
            } else {
                monthListModel.append({
                    dateStr: m.date,
                    total: m.total,
                    isTarget: m.is_target
                });
            }
        }
        while (monthListModel.count > window.monthData.length) {
            monthListModel.remove(monthListModel.count - 1);
        }
    }

    function formatTimeLarge(secs) {
        let h = Math.floor(secs / 3600);
        let m = Math.floor((secs % 3600) / 60);
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    function formatTimeList(secs) {
        let h = Math.floor(secs / 3600);
        let m = Math.floor((secs % 3600) / 60);
        if (h > 0) return h + "h " + m.toString().padStart(2, '0') + "m";
        return m + "m";
    }

    // -------------------------------------------------------------------------
    // KEYBOARD SHORTCUTS
    // -------------------------------------------------------------------------
    Shortcut { sequence: "Left"; onActivated: changeDay(-1) }
    Shortcut { sequence: "Right"; onActivated: changeDay(1) }
    Shortcut { sequence: "Home"; onActivated: changeDay(-7) }
    Shortcut { sequence: "End"; onActivated: changeDay(7) }

    // -------------------------------------------------------------------------
    // UI LAYOUT
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        scale: 0.97 + (0.03 * introState)
        opacity: introState

        // Deep OLED background
        Rectangle {
            anchors.fill: parent
            radius: 28
            color: window.crust
            border.color: Qt.alpha(window.surface1, 0.2)
            border.width: 1
            clip: true

            // Flowing Background Circles
            Rectangle {
                width: parent.width * 1.2; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * 150
                y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * 100
                opacity: 0.015
                color: window.mauve
            }
            Rectangle {
                width: parent.width * 1.1; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * -150
                y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * -100
                opacity: 0.010
                color: window.blue
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                // ==========================================
                // 1. HEADER
                // ==========================================
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.preferredHeight: 40
                    
                    Rectangle {
                        width: 40; height: 40; radius: 20
                        color: prevWeekMa.containsMouse ? window.surface0 : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text { anchors.centerIn: parent; font.family: "Iosevka Nerd Font"; text: ""; color: window.text; font.pixelSize: 18 }
                        MouseArea { id: prevWeekMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: changeDay(-1) }
                    }
                    
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        font.family: "Inter, Roboto, sans-serif"
                        font.weight: Font.DemiBold
                        font.pixelSize: 18
                        color: window.text
                        text: window.getFancyDate(window.targetDate)
                    }

                    Rectangle {
                        width: 40; height: 40; radius: 20
                        color: nextWeekMa.containsMouse ? window.surface0 : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text { anchors.centerIn: parent; font.family: "Iosevka Nerd Font"; text: ""; color: window.text; font.pixelSize: 18 }
                        MouseArea { id: nextWeekMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: changeDay(1) }
                    }
                }

                // Total Time Display
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 80
                    spacing: 8

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        font.family: "Inter, Roboto, sans-serif"
                        font.weight: Font.Black
                        font.pixelSize: 52
                        color: window.text
                        text: window.formatTimeLarge(window.animatedTotalSeconds)
                    }

                    // Dynamic Pill / Text Subtitle
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: pillLoader.width
                        Layout.preferredHeight: 24
                        
                        Loader {
                            id: pillLoader
                            anchors.centerIn: parent
                            sourceComponent: window.isTodaySelected ? activePillComponent : historyTextComponent
                        }

                        Component {
                            id: activePillComponent
                            Rectangle {
                                implicitWidth: activeAppText.width + 24
                                implicitHeight: 24
                                radius: 12
                                
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: window.mauve }
                                    GradientStop { position: 1.0; color: window.blue }
                                }

                                Text {
                                    id: activeAppText
                                    anchors.centerIn: parent
                                    font.family: "Inter, Roboto, sans-serif"
                                    font.weight: Font.Bold
                                    font.pixelSize: 12
                                    color: window.crust // High contrast dark text
                                    text: window.liveActiveApp
                                }
                            }
                        }

                        Component {
                            id: historyTextComponent
                            Text {
                                font.family: "Inter, Roboto, sans-serif"
                                font.weight: Font.Medium
                                font.pixelSize: 13
                                color: window.subtext0
                                text: "Total Focus Time"
                            }
                        }
                    }
                }

                // ==========================================
                // 2. MIDDLE CHARTS (Week + Heatmap)
                // ==========================================
                RowLayout {
                    id: middleSection
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    Layout.fillHeight: false
                    spacing: 16

                    // LEFT: Weekly Close-Knit Bar Chart
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 400 
                        radius: 20
                        color: window.base
                        border.color: Qt.alpha(window.surface1, 0.3)
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            height: parent.height - 32
                            spacing: 12 

                            Repeater {
                                model: weekListModel
                                delegate: Item {
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 45 

                                    MouseArea {
                                        id: barMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            window.changeToDate(model.dateStr);
                                        }
                                    }

                                    Item {
                                        anchors.bottom: dayLbl.top
                                        anchors.bottomMargin: 8
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 45 
                                        height: Math.max(4, (parent.height - 25) * (model.total / Math.max(window.maxWeekTotal, 1)))
                                        Behavior on height { NumberAnimation { duration: window.isFirstLoad ? 800 : 600; easing.type: Easing.OutQuint } }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 4 
                                            color: window.surface0
                                            visible: !model.isTarget
                                            opacity: barMa.containsMouse ? 0.7 : 1.0
                                            Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 4 
                                            visible: model.isTarget
                                            opacity: barMa.containsMouse ? 0.7 : 1.0
                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: window.mauve }
                                                GradientStop { position: 1.0; color: window.blue }
                                            }
                                        }
                                    }

                                    Text {
                                        id: dayLbl
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        font.family: "Inter, Roboto, sans-serif"
                                        font.weight: Font.Medium
                                        font.pixelSize: 12
                                        color: model.isTarget ? window.text : window.overlay0
                                        text: model.dayName 
                                        Behavior on color { ColorAnimation { duration: 400 } }
                                    }
                                }
                            }
                        }
                    }

                    // RIGHT: Calendar Month Heatmap
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 300
                        radius: 20
                        color: window.base
                        border.color: Qt.alpha(window.surface1, 0.3)
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                font.family: "Inter, Roboto, sans-serif"
                                font.weight: Font.DemiBold
                                font.pixelSize: 13
                                color: window.text
                                text: window.monthNames[window.targetDate.getMonth()]
                            }

                            Grid {
                                Layout.alignment: Qt.AlignCenter
                                columns: 7 
                                flow: Grid.LeftToRight 
                                spacing: 6 

                                Repeater {
                                    model: monthListModel
                                    delegate: Rectangle {
                                        width: 18 
                                        height: 18 
                                        radius: 4
                                        
                                        color: model.total === -1 ? "transparent" : (model.total === 0 ? window.surface0 : Qt.rgba(window.mauve.r, window.mauve.g, window.mauve.b, Math.min(1.0, 0.3 + 0.7 * (model.total / window.maxMonthTotal))))
                                        Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.OutQuint } }

                                        border.color: model.isTarget ? window.text : "transparent"
                                        border.width: model.isTarget ? 1 : 0
                                        Behavior on border.color { ColorAnimation { duration: 300 } }
                                        
                                        visible: model.total !== -1

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: model.total !== -1
                                            onClicked: {
                                                if (model.total !== -1) {
                                                    window.changeToDate(model.dateStr);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // 3. APP LIST CARD 
                // ==========================================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true 
                    radius: 20
                    color: window.base
                    border.color: Qt.alpha(window.surface1, 0.3)
                    border.width: 1

                    ListView {
                        id: appList
                        anchors.fill: parent
                        anchors.margins: 8
                        anchors.topMargin: 12
                        anchors.bottomMargin: 12
                        model: appListModel
                        interactive: true 
                        clip: true        
                        spacing: 2
                        
                        move: Transition { NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutQuint } }
                        
                        ScrollBar.vertical: ScrollBar {
                            active: appList.moving || appList.movingVertically
                            width: 4
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: 4
                                radius: 2
                                color: window.surface2
                            }
                        }
                        
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 58 
                            color: "transparent"
                            radius: 12

                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: rowMa.containsMouse ? window.surface0 : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: rowMa
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                anchors.topMargin: 10
                                anchors.bottomMargin: 10
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        font.family: "Inter, Roboto, sans-serif"
                                        font.weight: Font.Medium
                                        font.pixelSize: 13
                                        color: window.text
                                        text: model.name
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        font.family: "Inter, Roboto, sans-serif"
                                        font.weight: Font.Regular
                                        font.pixelSize: 13
                                        color: window.subtext0
                                        text: window.formatTimeList(model.seconds)
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 6

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 3
                                        color: window.crust
                                    }

                                    Rectangle {
                                        height: parent.height
                                        width: Math.max(6, parent.width * (model.percent / 100.0))
                                        radius: 3
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: window.mauve }
                                            GradientStop { position: 1.0; color: window.blue }
                                        }
                                        Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
