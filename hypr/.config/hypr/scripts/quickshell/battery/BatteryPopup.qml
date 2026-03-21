import QtQuick
import QtQuick.Layouts
import QtQuick.Window
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
    readonly property color overlay1: "#7f849c"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    
    readonly property color mauve: "#cba6f7"
    readonly property color pink: "#f5c2e7"
    readonly property color red: "#f38ba8"
    readonly property color maroon: "#eba0ac"
    readonly property color peach: "#fab387"
    readonly property color yellow: "#f9e2af"
    readonly property color green: "#a6e3a1"
    readonly property color teal: "#94e2d5"
    readonly property color sapphire: "#74c7ec"
    readonly property color blue: "#89b4fa"

    // -------------------------------------------------------------------------
    // STATE & POLLING
    // -------------------------------------------------------------------------
    property int batCapacity: 0
    property string batStatus: "Unknown"
    property string powerProfile: "balanced"
    
    property int upHours: 0
    property int upMins: 0

    property real sysVolume: 0
    property bool sysMuted: false
    property real sysBrightness: 0

    // Anti-Jitter Sync States
    property bool isDraggingVol: false
    property bool isDraggingBri: false

    Timer { id: volSyncDelay; interval: 800; onTriggered: window.isDraggingVol = false; triggeredOnStart: true; }
    Timer { id: briSyncDelay; interval: 800; onTriggered: window.isDraggingBri = false; triggeredOnStart: true; }

    readonly property bool isCharging: batStatus === "Charging"

    readonly property color batColorStart: {
        if (isCharging) return window.green;
        if (batCapacity >= 70) return window.blue;
        if (batCapacity >= 30) return window.yellow;
        return window.red;
    }

    readonly property color batColorEnd: {
        if (isCharging) return window.teal;
        if (batCapacity >= 70) return window.sapphire;
        if (batCapacity >= 30) return window.peach;
        return window.maroon;
    }

    readonly property color profileStart: {
        if (powerProfile === "performance") return window.red;
        if (powerProfile === "power-saver") return window.green;
        return window.blue;
    }
    
    readonly property color profileEnd: {
        if (powerProfile === "performance") return window.maroon;
        if (powerProfile === "power-saver") return window.teal;
        return window.sapphire;
    }

    readonly property color ambientPrimary: window.batColorStart
    readonly property color ambientSecondary: {
        if (powerProfile === "performance") return window.profileEnd;
        if (powerProfile === "power-saver") return window.profileEnd;
        return window.batColorEnd; 
    }

    property real animCapacity: 0
    Behavior on animCapacity { NumberAnimation { duration: 1200; easing.type: Easing.OutQuint } }
    
    onAnimCapacityChanged: batCanvas.requestPaint()
    onBatColorStartChanged: batCanvas.requestPaint()

    Process {
        id: sysPoller
        command: ["bash", "-c", 
            "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo '0'; " +
            "cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo 'Unknown'; " +
            "powerprofilesctl get 2>/dev/null || echo 'balanced'; " +
            "awk '{print int($1/3600)\"h \"int(($1%3600)/60)\"m\"}' /proc/uptime 2>/dev/null || echo '0h 0m'; " +
            "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100), ($3==\"[MUTED]\"?\"off\":\"on\")}' || echo '0 on'; " +
            "brightnessctl -m 2>/dev/null | awk -F, '{print substr($4, 1, length($4)-1)}' || echo '0'"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                if (lines.length >= 6) {
                    if (window.batCapacity !== parseInt(lines[0])) {
                        window.batCapacity = parseInt(lines[0]);
                        window.animCapacity = window.batCapacity;
                    }
                    window.batStatus = lines[1];
                    window.powerProfile = lines[2];
                    
                    let upParts = lines[3].split("h ");
                    if (upParts.length === 2) {
                        window.upHours = parseInt(upParts[0]) || 0;
                        window.upMins = parseInt(upParts[1].replace("m", "")) || 0;
                    }

                    if (!window.isDraggingVol) {
                        let volParts = (lines[4] || "0 on").trim().split(" ");
                        window.sysVolume = parseInt(volParts[0]) || 0;
                        window.sysMuted = (volParts[1] === "off");
                    }
                    
                    if (!window.isDraggingBri) {
                        window.sysBrightness = parseInt(lines[5]) || 0;
                    }
                }
            }
        }
    }

    Timer {
        interval: 1500; running: true; repeat: true; triggeredOnStart: true;
        onTriggered: sysPoller.running = true
    }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: true
    }

    property real introState: 0.0
    Component.onCompleted: introState = 1.0
    Behavior on introState { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    // -------------------------------------------------------------------------
    // UI LAYOUT
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        scale: 0.95 + (0.05 * introState)
        opacity: introState

        // Outer Border
        Rectangle {
            anchors.fill: parent
            radius: 30
            color: window.base
            border.color: window.surface0
            border.width: 1
            clip: true

            // Rotating Background Blobs
            Rectangle {
                width: parent.width * 0.8; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * 150
                y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * 100
                opacity: 0.08
                color: window.ambientPrimary
                Behavior on color { ColorAnimation { duration: 1000 } }
            }
            
            Rectangle {
                width: parent.width * 0.9; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * -150
                y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * -100
                opacity: 0.06
                color: window.ambientSecondary
                Behavior on color { ColorAnimation { duration: 1000 } }
            }

            // Radar Rings
            Item {
                id: radarItem
                anchors.fill: parent
                
                Repeater {
                    model: 3
                    Rectangle {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -70
                        width: 320 + (index * 170)
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.color: window.ambientSecondary
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 1000 } }
                        opacity: 0.06 - (index * 0.02)
                    }
                }
            }

            // ==========================================
            // TOP: UPTIME COMPONENT
            // ==========================================
            Row {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 25
                spacing: 6
                
                transform: Translate { y: -15 * (1.0 - introState) }
                opacity: introState
                
                // Hours Box
                Rectangle {
                    width: 44; height: 48; radius: 12
                    color: "#0dffffff"; border.color: "#1affffff"; border.width: 1
                    
                    Rectangle { anchors.fill: parent; radius: 12; color: window.ambientPrimary; opacity: 0.05; Behavior on color { ColorAnimation { duration: 1000 } } }
                    Column {
                        anchors.centerIn: parent
                        Text { 
                            text: window.upHours.toString().padStart(2, '0')
                            font.pixelSize: 18; font.family: "JetBrains Mono"; font.weight: Font.Black
                            color: window.ambientPrimary
                            Behavior on color { ColorAnimation { duration: 1000 } }
                            anchors.horizontalCenter: parent.horizontalCenter 
                        }
                        Text { 
                            text: "HR"; font.pixelSize: 8; font.family: "JetBrains Mono"; font.weight: Font.Bold
                            color: window.subtext0; anchors.horizontalCenter: parent.horizontalCenter 
                        }
                    }
                }

                // Pulsing Colon
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ":"
                    font.pixelSize: 22; font.family: "JetBrains Mono"; font.weight: Font.Black
                    color: window.ambientPrimary
                    Behavior on color { ColorAnimation { duration: 1000 } }
                    
                    opacity: uptimePulse
                    property real uptimePulse: 1.0
                    SequentialAnimation on uptimePulse {
                        loops: Animation.Infinite; running: true
                        NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                    }
                }

                // Mins Box
                Rectangle {
                    width: 44; height: 48; radius: 12
                    color: "#0dffffff"; border.color: "#1affffff"; border.width: 1
                    
                    Rectangle { anchors.fill: parent; radius: 12; color: window.ambientSecondary; opacity: 0.05; Behavior on color { ColorAnimation { duration: 1000 } } }
                    Column {
                        anchors.centerIn: parent
                        Text { 
                            text: window.upMins.toString().padStart(2, '0')
                            font.pixelSize: 18; font.family: "JetBrains Mono"; font.weight: Font.Black
                            color: window.ambientSecondary
                            Behavior on color { ColorAnimation { duration: 1000 } }
                            anchors.horizontalCenter: parent.horizontalCenter 
                        }
                        Text { 
                            text: "MIN"; font.pixelSize: 8; font.family: "JetBrains Mono"; font.weight: Font.Bold
                            color: window.subtext0; anchors.horizontalCenter: parent.horizontalCenter 
                        }
                    }
                }
            }

            // Simple top-right logout icon
            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.margins: 25
                width: 44; height: 44; radius: 22
                color: logoutMa.containsMouse ? "#1affffff" : "transparent"
                border.color: logoutMa.containsMouse ? "#33ffffff" : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Text {
                    anchors.centerIn: parent
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                    color: logoutMa.containsMouse ? window.red : window.overlay0
                    text: "󰍃"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                MouseArea {
                    id: logoutMa
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { Quickshell.execDetached(["sh", "-c", "loginctl terminate-user $USER"]); Quickshell.execDetached(["sh", "-c", "echo 'close' > /tmp/qs_widget_state"]); }
                }
            }

            // ==========================================
            // CENTRAL CORE & BATTERY RING 
            // ==========================================
            Item {
                anchors.fill: parent
                z: 1

                // --- CLEAN OUTSIDE GLOW HALO ---
                Rectangle {
                    anchors.centerIn: centralCore
                    width: centralCore.width + 45
                    height: width
                    radius: width / 2
                    color: centralCore.isDangerState ? window.red : window.ambientPrimary
                    opacity: centralCore.isDangerState ? 0.25 : 0.15
                    z: 0 
                    Behavior on color { ColorAnimation { duration: 400 } }
                    SequentialAnimation on scale {
                        loops: Animation.Infinite; running: true
                        NumberAnimation { to: heroMa.containsMouse ? 1.15 : 1.08; duration: heroMa.containsMouse ? 800 : 2000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: heroMa.containsMouse ? 800 : 2000; easing.type: Easing.InOutSine }
                    }
                }
                // -------------------------------

                Rectangle {
                    id: centralCore
                    width: 260
                    height: width
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -70
                    radius: width / 2
                    z: 1
                    
                    property bool isDangerState: !window.isCharging && window.batCapacity < 15
                    
                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        running: true
                        NumberAnimation { 
                            to: heroMa.containsMouse ? 1.05 : (centralCore.isDangerState ? 1.04 : 1.01)
                            duration: heroMa.containsMouse ? 1200 : (centralCore.isDangerState ? 600 : 2500)
                            easing.type: Easing.InOutSine 
                        }
                        NumberAnimation { 
                            to: 1.0
                            duration: heroMa.containsMouse ? 1200 : (centralCore.isDangerState ? 600 : 2500)
                            easing.type: Easing.InOutSine 
                        }
                    }

                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: window.surface0 }
                        GradientStop { position: 1.0; color: window.base }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: window.maroon
                        opacity: centralCore.isDangerState ? 0.15 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 1000 } }
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite; running: centralCore.isDangerState
                            NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.15; duration: 600; easing.type: Easing.InOutSine }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        
                        property real textPulse: 0.0
                        SequentialAnimation on textPulse {
                            loops: Animation.Infinite; running: true
                            NumberAnimation { from: 0.0; to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1.0; to: 0.0; duration: 1200; easing.type: Easing.InOutSine }
                        }
                        
                        property real pumpPhase: 0.0
                        NumberAnimation on pumpPhase {
                            running: heroMa.containsMouse && window.isCharging
                            loops: Animation.Infinite
                            from: 0.0; to: 1.0; duration: 1200
                            easing.type: Easing.InOutSine 
                            onStopped: batCanvas.requestPaint()
                        }
                        
                        property real dischargePhase: 1.0
                        NumberAnimation on dischargePhase {
                            running: heroMa.containsMouse && !window.isCharging
                            loops: Animation.Infinite
                            from: 1.0; to: 0.0; duration: 1600
                            easing.type: Easing.InOutSine
                            onStopped: batCanvas.requestPaint()
                        }
                        
                        onPumpPhaseChanged: { if(heroMa.containsMouse && window.isCharging) batCanvas.requestPaint() }
                        onDischargePhaseChanged: { if(heroMa.containsMouse && !window.isCharging) batCanvas.requestPaint() }
                        
                        Canvas {
                            id: batCanvas
                            anchors.fill: parent
                            rotation: 180 
                            
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                
                                var centerX = width / 2;
                                var centerY = height / 2;
                                var radius = (width / 2) - 18; 
                                var endAngle = (window.animCapacity / 100) * 2 * Math.PI;
                                
                                ctx.lineCap = "round";
                                
                                ctx.lineWidth = 8;
                                ctx.beginPath();
                                ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
                                ctx.strokeStyle = "#0dffffff";
                                ctx.stroke();
                                
                                var fillGrad = ctx.createLinearGradient(0, height, width, 0);
                                fillGrad.addColorStop(0, window.batColorStart.toString());
                                fillGrad.addColorStop(1, window.batColorEnd.toString());

                                ctx.globalAlpha = 1.0;
                                ctx.lineWidth = 14;
                                ctx.beginPath();
                                ctx.arc(centerX, centerY, radius, 0, endAngle);
                                ctx.strokeStyle = fillGrad;
                                ctx.stroke();
                                
                                if (heroMa.containsMouse && endAngle > 0.1) {
                                    if (window.isCharging) {
                                        var surgeAngle = parent.pumpPhase * (endAngle + 0.6) - 0.3;
                                        if (surgeAngle > 0 && surgeAngle < endAngle) {
                                            var sStart = Math.max(0, surgeAngle - 0.4);
                                            var sEnd = Math.min(endAngle, surgeAngle + 0.4);
                                            ctx.beginPath();
                                            ctx.arc(centerX, centerY, radius, sStart, sEnd);
                                            ctx.lineWidth = 22;
                                            ctx.strokeStyle = window.batColorStart.toString();
                                            ctx.globalAlpha = 0.5 * Math.sin(parent.pumpPhase * Math.PI);
                                            ctx.stroke();

                                            sStart = Math.max(0, surgeAngle - 0.2);
                                            sEnd = Math.min(endAngle, surgeAngle + 0.2);
                                            ctx.beginPath();
                                            ctx.arc(centerX, centerY, radius, sStart, sEnd);
                                            ctx.lineWidth = 28;
                                            ctx.strokeStyle = window.batColorEnd.toString();
                                            ctx.globalAlpha = 0.8 * Math.sin(parent.pumpPhase * Math.PI);
                                            ctx.stroke();
                                        }
                                        
                                        if (parent.pumpPhase > 0.7) {
                                            var flarePhase = (parent.pumpPhase - 0.7) / 0.3;
                                            var hitX = centerX + Math.cos(endAngle) * radius;
                                            var hitY = centerY + Math.sin(endAngle) * radius;
                                            ctx.beginPath();
                                            ctx.arc(hitX, hitY, 7 + (flarePhase * 15), 0, 2*Math.PI);
                                            ctx.fillStyle = window.batColorEnd.toString();
                                            ctx.globalAlpha = (1.0 - flarePhase) * 0.6;
                                            ctx.fill();
                                        }
                                    } else {
                                        var drainCenter = parent.dischargePhase * endAngle;
                                        for (var d = 0; d < 2; d++) {
                                            var dSpread = 0.2 + (d * 0.15);
                                            var dStart = Math.max(0, drainCenter - dSpread);
                                            var dEnd = Math.min(endAngle, drainCenter + dSpread);
                                            
                                            if (dStart < dEnd) {
                                                ctx.beginPath();
                                                ctx.arc(centerX, centerY, radius, dStart, dEnd);
                                                ctx.lineWidth = 14 + (1 - d) * 2;
                                                ctx.strokeStyle = window.batColorEnd.toString();
                                                ctx.globalAlpha = 0.2 * Math.sin(parent.dischargePhase * Math.PI);
                                                ctx.stroke();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: -2
                        
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8
                            
                            Text {
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 32
                                color: window.batColorStart
                                text: window.isCharging ? "󰂄" : (window.batCapacity > 20 ? "󰁹" : "󰂃")
                                Behavior on color { ColorAnimation { duration: 400 } }
                            }
                            
                            Text {
                                font.family: "JetBrains Mono"
                                font.weight: Font.Black
                                font.pixelSize: 54
                                color: window.text
                                text: Math.round(window.animCapacity) + "%" 
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: 13
                            
                            color: window.isCharging 
                                    ? Qt.tint(window.green, Qt.rgba(1, 1, 1, parent.textPulse * 0.4)) 
                                    : (centralCore.isDangerState ? Qt.tint(window.red, Qt.rgba(1, 1, 1, parent.textPulse * 0.3)) : window.subtext0)
                                    
                            text: window.batStatus.toUpperCase()
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                    }
                }

                MouseArea {
                    id: heroMa
                    anchors.fill: centralCore 
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: batCanvas.requestPaint()
                    onExited: batCanvas.requestPaint()
                }
            }

            // ==========================================
            // BOTTOM DOCKS
            // ==========================================
            ColumnLayout {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 25
                spacing: 15
                transform: Translate { y: 20 * (1.0 - introState) }
                opacity: introState

                // 1. HARDWARE CONTROLS DOCK (Sliders)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    radius: 24
                    color: "#05ffffff"
                    border.color: "#1affffff"
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        // Brightness Slider
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 15

                            Item {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                Text {
                                    anchors.centerIn: parent
                                    text: window.sysBrightness > 66 ? "󰃠" : (window.sysBrightness > 33 ? "󰃟" : "󰃞")
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: 22
                                    color: window.ambientPrimary
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                height: 18
                                
                                Timer {
                                    id: briCmdThrottle
                                    interval: 50
                                    property int targetPct: -1
                                    onTriggered: {
                                        if (targetPct >= 0) {
                                            Quickshell.execDetached(["brightnessctl", "set", targetPct + "%"]);
                                            targetPct = -1;
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 9
                                    color: "#0dffffff"
                                    border.color: "#1affffff"
                                    border.width: 1
                                    clip: true

                                    Rectangle {
                                        height: parent.height
                                        width: parent.width * (window.sysBrightness / 100)
                                        radius: 9
                                        opacity: briMa.containsMouse ? 0.9 : 0.7
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                        Behavior on width { enabled: !window.isDraggingBri; NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: window.batColorStart; Behavior on color { ColorAnimation { duration: 300 } } }
                                            GradientStop { position: 1.0; color: window.batColorEnd; Behavior on color { ColorAnimation { duration: 300 } } }
                                        }
                                    }
                                }
                                MouseArea {
                                    id: briMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: (mouse) => { briSyncDelay.stop(); window.isDraggingBri = true; updateBri(mouse.x); }
                                    onPositionChanged: (mouse) => { if (pressed) updateBri(mouse.x); }
                                    onReleased: { briSyncDelay.restart(); }
                                    
                                    function updateBri(mx) {
                                        let pct = Math.max(0, Math.min(100, Math.round((mx / width) * 100)));
                                        window.sysBrightness = pct; 
                                        briCmdThrottle.targetPct = pct;
                                        if (!briCmdThrottle.running) briCmdThrottle.start();
                                    }
                                }
                            }
                        }

                        // Volume Slider
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 15

                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: 16
                                color: volIconMa.containsMouse ? "#1affffff" : "transparent"
                                border.color: volIconMa.containsMouse ? window.ambientSecondary : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: window.sysMuted || window.sysVolume === 0 ? "󰖁" : (window.sysVolume > 50 ? "󰕾" : "󰖀")
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: 22
                                    color: window.sysMuted ? window.overlay0 : window.ambientSecondary
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                MouseArea {
                                    id: volIconMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        volSyncDelay.stop();
                                        window.isDraggingVol = true; 
                                        window.sysMuted = !window.sysMuted;
                                        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
                                        volSyncDelay.restart();
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                height: 18
                                
                                Timer {
                                    id: volCmdThrottle
                                    interval: 50
                                    property int targetPct: -1
                                    onTriggered: {
                                        if (targetPct >= 0) {
                                            if (targetPct > 0 && window.sysMuted) {
                                                window.sysMuted = false;
                                                Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"]);
                                            }
                                            Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", targetPct + "%"]);
                                            targetPct = -1;
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 9
                                    color: "#0dffffff"
                                    border.color: "#1affffff"
                                    border.width: 1
                                    clip: true

                                    Rectangle {
                                        height: parent.height
                                        width: parent.width * (window.sysVolume / 100)
                                        radius: 9
                                        opacity: window.sysMuted ? 0.5 : (volMa.containsMouse ? 0.9 : 0.7)
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                        Behavior on width { enabled: !window.isDraggingVol; NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: window.sysMuted ? window.overlay0 : window.profileStart; Behavior on color { ColorAnimation { duration: 300 } } }
                                            GradientStop { position: 1.0; color: window.sysMuted ? window.subtext0 : window.profileEnd; Behavior on color { ColorAnimation { duration: 300 } } }
                                        }
                                    }
                                }
                                MouseArea {
                                    id: volMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: (mouse) => { volSyncDelay.stop(); window.isDraggingVol = true; updateVol(mouse.x); }
                                    onPositionChanged: (mouse) => { if (pressed) updateVol(mouse.x); }
                                    onReleased: { volSyncDelay.restart(); }
                                    
                                    function updateVol(mx) {
                                        let pct = Math.max(0, Math.min(100, Math.round((mx / width) * 100)));
                                        window.sysVolume = pct;
                                        volCmdThrottle.targetPct = pct;
                                        if (!volCmdThrottle.running) volCmdThrottle.start();
                                    }
                                }
                            }
                        }
                    }
                }

                // 2. SYSTEM ACTIONS DOCK
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 75
                    spacing: 12
                    
                    Repeater {
                        model: ListModel {
                            ListElement { lbl: "Lock"; cmd: "hyprlock"; icon: ""; c1: "#cba6f7"; c2: "#f5c2e7"; weight: 1.0 }
                            ListElement { lbl: "Sleep"; cmd: "hyprlock & systemctl suspend"; icon: "ᶻ 𝗓 𐰁"; c1: "#89b4fa"; c2: "#74c7ec"; weight: 1.0 }
                            ListElement { lbl: "Reboot"; cmd: "systemctl reboot"; icon: "󰑓"; c1: "#f9e2af"; c2: "#fab387"; weight: 2.5 }
                            ListElement { lbl: "Power"; cmd: "systemctl poweroff"; icon: ""; c1: "#f38ba8"; c2: "#eba0ac"; weight: 3.5 }
                        }
                        
                        delegate: Rectangle {
                            id: actionCapsule
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 18
                            color: actionMa.containsMouse ? "#1affffff" : "#0dffffff"
                            border.color: actionMa.containsMouse ? c1 : "#1affffff"
                            border.width: actionMa.containsMouse ? 2 : 1
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on border.color { ColorAnimation { duration: 200 } }
                            
                            // --- CLEAN STIFF RESISTANCE EFFECT ---
                            scale: actionMa.pressed ? (0.98 - (0.01 * weight)) : (actionMa.containsMouse ? 1.08 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
                            // -------------------------------------

                            property real fillLevel: 0.0
                            property bool triggered: false
                            property real flashOpacity: 0.0
                            
                            Canvas {
                                id: actionWaveCanvas
                                anchors.fill: parent
                                
                                property real wavePhase: 0.0
                                NumberAnimation on wavePhase {
                                    running: actionCapsule.fillLevel > 0.0 && actionCapsule.fillLevel < 1.0
                                    loops: Animation.Infinite
                                    from: 0; to: Math.PI * 2; duration: 800
                                }
                                onWavePhaseChanged: requestPaint()
                                Connections { target: actionCapsule; function onFillLevelChanged() { actionWaveCanvas.requestPaint() } }
                                
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    if (actionCapsule.fillLevel <= 0.001) return;
                                    
                                    var r = 18; 
                                    var fillY = height * (1.0 - actionCapsule.fillLevel);
                                    ctx.save();
                                    ctx.beginPath();
                                    ctx.moveTo(r, 0);
                                    ctx.lineTo(width - r, 0);
                                    ctx.arcTo(width, 0, width, r, r);
                                    ctx.lineTo(width, height - r);
                                    ctx.arcTo(width, height, width - r, height, r);
                                    ctx.lineTo(r, height);
                                    ctx.arcTo(0, height, 0, height - r, r);
                                    ctx.lineTo(0, r);
                                    ctx.arcTo(0, 0, r, 0, r);
                                    ctx.closePath();
                                    ctx.clip(); 
                                    
                                    ctx.beginPath();
                                    ctx.moveTo(0, fillY);
                                    if (actionCapsule.fillLevel < 0.99) {
                                        var waveAmp = 10 * Math.sin(actionCapsule.fillLevel * Math.PI); 
                                        var cp1y = fillY + Math.sin(wavePhase) * waveAmp;
                                        var cp2y = fillY + Math.cos(wavePhase + Math.PI) * waveAmp;
                                        ctx.bezierCurveTo(width * 0.33, cp2y, width * 0.66, cp1y, width, fillY);
                                        ctx.lineTo(width, height);
                                        ctx.lineTo(0, height);
                                    } else {
                                        ctx.lineTo(width, 0);
                                        ctx.lineTo(width, height);
                                        ctx.lineTo(0, height);
                                    }
                                    ctx.closePath();
                                    
                                    var grad = ctx.createLinearGradient(0, 0, 0, height);
                                    grad.addColorStop(0, c1);
                                    grad.addColorStop(1, c2);
                                    ctx.fillStyle = grad;
                                    ctx.fill();
                                    ctx.restore();
                                }
                            }

                            Rectangle {
                                anchors.fill: parent; radius: 18; color: "#ffffff"
                                opacity: actionCapsule.flashOpacity
                                PropertyAnimation on opacity { id: cardFlashAnim; to: 0; duration: 500; easing.type: Easing.OutExpo }
                            }

                            ColumnLayout {
                                id: baseTextCol
                                anchors.centerIn: parent
                                spacing: 4
                                Text { 
                                    Layout.alignment: Qt.AlignHCenter; font.family: "Iosevka Nerd Font"; font.pixelSize: 22
                                    color: actionMa.containsMouse ? window.text : window.subtext0; text: icon
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                Text { 
                                    Layout.alignment: Qt.AlignHCenter; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: 11
                                    color: actionMa.containsMouse ? window.text : window.subtext0; text: actionCapsule.fillLevel > 0.1 ? "Hold" : lbl
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }

                            Item {
                                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                height: actionCapsule.height * actionCapsule.fillLevel
                                clip: true
                                
                                ColumnLayout {
                                    x: baseTextCol.x; y: baseTextCol.y - (actionCapsule.height - parent.height)
                                    width: baseTextCol.width; height: baseTextCol.height
                                    spacing: 4
                                    Text { Layout.alignment: Qt.AlignHCenter; font.family: "Iosevka Nerd Font"; font.pixelSize: 22; color: window.crust; text: icon }
                                    Text { Layout.alignment: Qt.AlignHCenter; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: 11; color: window.crust; text: actionCapsule.fillLevel > 0.1 ? "Hold" : lbl }
                                }
                            }

                            MouseArea {
                                id: actionMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: actionCapsule.triggered ? Qt.ArrowCursor : Qt.PointingHandCursor
                                
                                onPressed: { 
                                    if (!actionCapsule.triggered) { 
                                        drainAnim.stop(); 
                                        fillAnim.start(); 
                                    }
                                }
                                onReleased: {
                                    if (!actionCapsule.triggered && actionCapsule.fillLevel < 1.0) { 
                                        fillAnim.stop(); 
                                        drainAnim.start(); 
                                    }
                                }
                            }

                            NumberAnimation {
                                id: fillAnim; target: actionCapsule; property: "fillLevel"; to: 1.0
                                duration: (550 * weight) * (1.0 - actionCapsule.fillLevel); easing.type: Easing.InSine
                                onFinished: {
                                    actionCapsule.triggered = true; actionCapsule.flashOpacity = 0.6; cardFlashAnim.start();
                                    window.introState = 0.0; exitTimer.start();
                                }
                            }
                            
                            NumberAnimation {
                                id: drainAnim; target: actionCapsule; property: "fillLevel"; to: 0.0
                                duration: 1500 * actionCapsule.fillLevel; easing.type: Easing.OutQuad
                            }

                            Timer {
                                id: exitTimer; interval: 500 
                                onTriggered: { Quickshell.execDetached(["sh", "-c", cmd]); Quickshell.execDetached(["sh", "-c", "echo 'close' > /tmp/qs_widget_state"]); }
                            }
                        }
                    }
                }

                // 3. POWER PROFILES DOCK
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    radius: 27
                    color: "#0dffffff" 
                    border.color: "#1affffff"
                    border.width: 1
                    
                    Rectangle {
                        id: sliderPill
                        width: (parent.width - 2) / 3 
                        height: parent.height - 2
                        y: 1
                        radius: 26
                        x: {
                            if (window.powerProfile === "performance") return 1;
                            if (window.powerProfile === "balanced") return width + 1;
                            return (width * 2) + 1;
                        }
                        
                        Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                        
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: window.profileStart; Behavior on color { ColorAnimation{duration:400} } }
                            GradientStop { position: 1.0; color: window.profileEnd; Behavior on color { ColorAnimation{duration:400} } }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        Repeater {
                            model: ListModel {
                                ListElement { name: "performance"; icon: "󰓅"; label: "Perform" } 
                                ListElement { name: "balanced"; icon: "󰗑"; label: "Balance" }   
                                ListElement { name: "power-saver"; icon: "󰌪"; label: "Saver" } 
                            }
                            
                            delegate: Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Text {
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                                        color: window.powerProfile === name ? window.crust : (profileMa.containsMouse ? window.text : window.subtext0)
                                        text: icon
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                    Text {
                                        font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: 13
                                        color: window.powerProfile === name ? window.crust : (profileMa.containsMouse ? window.text : window.subtext0)
                                        text: label
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }
                                
                                MouseArea {
                                    id: profileMa
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { Quickshell.execDetached(["powerprofilesctl", "set", name]); sysPoller.running = true; }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
