import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: masterWindow
    title: "qs-master"
    color: "transparent"
    
    // Always mapped to prevent Wayland from destroying the surface and Hyprland from auto-centering!
    visible: true 

    // Push it off-screen the moment the component loads using Hyprland's dispatcher
    Component.onCompleted: {
        Quickshell.execDetached(["bash", "-c", `hyprctl dispatch resizewindowpixel "exact 1 1,title:^(qs-master)$" && hyprctl dispatch movewindowpixel "exact -5000 -5000,title:^(qs-master)$"`]);
    }

    property int screenW: 1920
    property int screenH: 1080

    property string currentActive: "hidden" 
    onCurrentActiveChanged: {
        Quickshell.execDetached(["bash", "-c", "echo '" + currentActive + "' > /tmp/qs_active_widget"]);
    }

    property bool isVisible: false
    property string activeArg: ""
    property bool disableMorph: false 
    property bool isWallpaperTransition: false 

    // NEW: Dynamic duration to allow fast opening but keep morphing smooth
    property int morphDuration: 500

    // Safe park coordinates to avoid cursor traps
    property int currentX: -5000
    property int currentY: -5000

    property real animW: 1
    property real animH: 1

    property var layouts: {
        "battery":   { w: 480, h: 760, x: screenW - 500, y: 70, comp: "battery/BatteryPopup.qml" },
        "calendar":  { w: 1450, h: 750, x: 235, y: 70, comp: "calendar/CalendarPopup.qml" },
        "music":     { w: 700, h: 620, x: 12, y: 70, comp: "music/MusicPopup.qml" },
        "network":   { w: 900, h: 700, x: screenW - 920, y: 70, comp: "network/NetworkPopup.qml" },
        "stewart":   { w: 800, h: 600, x: Math.floor((screenW/2)-(800/2)), y: Math.floor((screenH/2)-(600/2)), comp: "stewart/stewart.qml" },
        "wallpaper": { w: 1920, h: 500, x: 0, y: Math.floor((screenH/2)-(500/2)), comp: "wallpaper/WallpaperPicker.qml" },
        "monitors":  { w: 850, h: 580, x: Math.floor((screenW/2)-(850/2)), y: Math.floor((screenH/2)-(580/2)), comp: "monitors/MonitorPopup.qml" },
        "focustime": { w: 900, h: 720, x: Math.floor((screenW/2)-(900/2)), y: Math.floor((screenH/2)-(720/2)), comp: "focustime/FocusTimePopup.qml" },
        "hidden":    { w: 1, h: 1, x: -5000, y: -5000, comp: "" } 
    }
    width: 1
    height: 1
    implicitWidth: width
    implicitHeight: height

    onIsVisibleChanged: {
        if (isVisible) masterWindow.requestActivate();
    }

    Item {
        anchors.centerIn: parent
        width: masterWindow.animW
        height: masterWindow.animH
        clip: true 

        // MODIFIED: Use dynamic morphDuration instead of hardcoded 500
        Behavior on width { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.InOutCubic } }
        Behavior on height { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.InOutCubic } }

        opacity: masterWindow.isVisible ? 1.0 : 0.0
        // MODIFIED: Speed up opacity fade-in to match the fast opening (200ms when fast, 300ms when morphing)
        Behavior on opacity { NumberAnimation { duration: masterWindow.isWallpaperTransition ? 150 : (masterWindow.morphDuration === 500 ? 300 : 200); easing.type: Easing.InOutSine } }

        // INNER FIXED CONTAINER
        Item {
            anchors.centerIn: parent
            width: masterWindow.currentActive !== "hidden" && layouts[masterWindow.currentActive] ? layouts[masterWindow.currentActive].w : 1
            height: masterWindow.currentActive !== "hidden" && layouts[masterWindow.currentActive] ? layouts[masterWindow.currentActive].h : 1

            StackView {
                id: widgetStack
                anchors.fill: parent
                focus: true
                
                onCurrentItemChanged: {
                    if (currentItem) currentItem.forceActiveFocus();
                }

                // Perfectly synchronized crossfade! 
                // Both take exactly 350ms so they blend seamlessly without a gap.
                replaceEnter: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 350; easing.type: Easing.InOutQuad }
                        NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 350; easing.type: Easing.OutBack }
                    }
                }
                replaceExit: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 350; easing.type: Easing.InOutQuad }
                        NumberAnimation { property: "scale"; from: 1.0; to: 1.05; duration: 350; easing.type: Easing.InCubic }
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"])
    }

    function switchWidget(newWidget, arg) {
        let involvesWallpaper = (newWidget === "wallpaper" || currentActive === "wallpaper");
        masterWindow.isWallpaperTransition = involvesWallpaper;

        if (newWidget === "hidden") {
            if (currentActive !== "hidden" && layouts[currentActive]) {
                masterWindow.morphDuration = 250; // FAST CLOSE
                masterWindow.disableMorph = false;
                let t = layouts[currentActive];
                let cx = Math.floor(t.x + (t.w/2));
                let cy = Math.floor(t.y + (t.h/2));
                
                masterWindow.animW = 1;
                masterWindow.animH = 1;
                masterWindow.isVisible = false;
                
                Quickshell.execDetached(["bash", "-c", `hyprctl dispatch resizewindowpixel "exact 1 1,title:^(qs-master)$" && hyprctl dispatch movewindowpixel "exact ${cx} ${cy},title:^(qs-master)$"`]);
                delayedClear.start();
            }
        } else {
            if (currentActive === "hidden") {
                masterWindow.morphDuration = 250; // FAST INITIAL OPEN
                masterWindow.disableMorph = false;
                let t = layouts[newWidget];
                let cx = Math.floor(t.x + (t.w / 2));
                let cy = Math.floor(t.y + (t.h / 2));

                masterWindow.animW = 1;
                masterWindow.animH = 1;
                masterWindow.width = 1;
                masterWindow.height = 1;

                Quickshell.execDetached(["bash", "-c", `hyprctl dispatch movewindowpixel "exact ${cx} ${cy},title:^(qs-master)$"`]);

                prepTimer.newWidget = newWidget;
                prepTimer.newArg = arg;
                prepTimer.start();
                
            } else {
                masterWindow.morphDuration = 500; // SMOOTH MORPH BETWEEN WIDGETS
                if (involvesWallpaper) {
                    masterWindow.disableMorph = true;
                    masterWindow.isVisible = false; 
                    teleportFadeOutTimer.newWidget = newWidget;
                    teleportFadeOutTimer.newArg = arg;
                    teleportFadeOutTimer.start();
                } else {
                    masterWindow.disableMorph = false;
                    executeSwitch(newWidget, arg, false);
                }
            }
        }
    }

    Timer {
        id: prepTimer
        interval: 50
        property string newWidget: ""
        property string newArg: ""
        onTriggered: executeSwitch(newWidget, newArg, false)
    }

    Timer {
        id: teleportFadeOutTimer
        interval: 150 
        property string newWidget: ""
        property string newArg: ""
        onTriggered: {
            let t = layouts[newWidget];

            masterWindow.currentActive = newWidget;
            masterWindow.activeArg = newArg;

            masterWindow.animW = t.w;
            masterWindow.animH = t.h;
            masterWindow.width = t.w;
            masterWindow.height = t.h;
            masterWindow.currentX = t.x;
            masterWindow.currentY = t.y;

            Quickshell.execDetached(["bash", "-c", `hyprctl dispatch resizewindowpixel "exact ${t.w} ${t.h},title:^(qs-master)$" && hyprctl dispatch movewindowpixel "exact ${t.x} ${t.y},title:^(qs-master)$"`]);

            let props = newWidget === "wallpaper" ? { "widgetArg": newArg } : {};
            widgetStack.replace(t.comp, props, StackView.Immediate);

            teleportFadeInTimer.newWidget = newWidget;
            teleportFadeInTimer.newArg = newArg;
            teleportFadeInTimer.start();
        }
    }

    Timer {
        id: teleportFadeInTimer
        interval: 50 
        property string newWidget: ""
        property string newArg: ""
        onTriggered: {
            masterWindow.isVisible = true; 
            if (newWidget !== "wallpaper") resetMorphTimer.start();
        }
    }

    Timer {
        id: resetMorphTimer
        interval: masterWindow.morphDuration // MODIFIED: Synced with the dynamic animation duration
        onTriggered: masterWindow.disableMorph = false
    }

    function executeSwitch(newWidget, arg, immediate) {
        masterWindow.currentActive = newWidget;
        masterWindow.activeArg = arg;
        
        let t = layouts[newWidget];
        masterWindow.animW = t.w;
        masterWindow.animH = t.h;
        masterWindow.width = t.w;
        masterWindow.height = t.h;
        masterWindow.currentX = t.x;
        masterWindow.currentY = t.y;
        
        Quickshell.execDetached(["bash", "-c", `hyprctl dispatch resizewindowpixel "exact ${t.w} ${t.h},title:^(qs-master)$" && hyprctl dispatch movewindowpixel "exact ${t.x} ${t.y},title:^(qs-master)$"`]);
        
        masterWindow.isVisible = true;
        
        let props = newWidget === "wallpaper" ? { "widgetArg": arg } : {};

        if (immediate) {
            widgetStack.replace(t.comp, props, StackView.Immediate);
        } else {
            widgetStack.replace(t.comp, props);
        }
    }

    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: { if (!ipcPoller.running) ipcPoller.running = true; }
    }

    Process {
        id: ipcPoller
        command: ["bash", "-c", "if [ -f /tmp/qs_widget_state ]; then cat /tmp/qs_widget_state; rm /tmp/qs_widget_state; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let rawCmd = this.text.trim();
                if (rawCmd === "") return;

                let parts = rawCmd.split(":");
                let cmd = parts[0];
                let arg = parts.length > 1 ? parts[1] : "";

                if (cmd === "close") {
                    switchWidget("hidden", "");
                } else if (layouts[cmd]) {
                    delayedClear.stop();
                    if (masterWindow.isVisible && masterWindow.currentActive === cmd) {
                        switchWidget("hidden", "");
                    } else {
                        switchWidget(cmd, arg);
                    }
                }
            }
        }
    }

    Timer {
        id: delayedClear
        interval: masterWindow.isWallpaperTransition ? 150 : masterWindow.morphDuration // MODIFIED: Synced dynamically
        onTriggered: {
            masterWindow.currentActive = "hidden";
            widgetStack.clear();
            masterWindow.disableMorph = false;
            
            // Banished safely back to the shadow realm off-screen
            let cmd = `hyprctl dispatch resizewindowpixel "exact 1 1,title:^(qs-master)$" && hyprctl dispatch movewindowpixel "exact -5000 -5000,title:^(qs-master)$"`;
            Quickshell.execDetached(["bash", "-c", cmd]);
        }
    }
}
