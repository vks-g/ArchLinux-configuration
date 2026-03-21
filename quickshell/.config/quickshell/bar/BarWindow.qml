import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import ".."

PanelWindow {
    id: root
    
    property var screen

    screen: root.screen
    
    // ANCHORS: Top, Left, Right
    anchors {
        top: true
        left: true
        right: true
    }

    // HEIGHT: Use implicitHeight as requested by the warning
    implicitHeight: Style.barHeight

    // MARGINS: Must be a specific object, not an int
    margins {
        top: 10
        left: 10
        right: 10
        bottom: 0
    }

    color: "transparent"

    // EXCLUSION MODE: Ensures windows don't overlap the bar
    exclusionMode: ExclusionMode.Exclusive

    // Main Layout
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ============================
        // LEFT WIDGETS
        // ============================
        RowLayout {
            Layout.alignment: Qt.AlignLeft
            spacing: 5
            Layout.leftMargin: 10
            
            // Search Button
            BarButton { 
                icon: "search" 
                onClicked: sh("bash ../../../../sessions/hyprland/scripts/rofi_show.sh") 
            }
            
            // Notification Button
            BarButton { 
                icon: "" 
                isTextIcon: true 
                onClicked: sh("swaync-client -t -sw") 
            }

            // Workspaces Widget
            Workspaces {}
            
            // Media Widget
            Media {}
        }

        // ============================
        // CENTER WIDGETS
        // ============================
        Item { Layout.fillWidth: true } // Spacer

        Weather {}

        Item { Layout.fillWidth: true } // Spacer

        // ============================
        // RIGHT WIDGETS
        // ============================
        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 5
            Layout.rightMargin: 10
            
            // System Tray
            TrayWidget { 
                Layout.preferredHeight: 32 
            }
            
            // System Info Pills
            System {}
        }
    }

    function sh(cmd) {
        var p = Qt.createQmlObject('import Quickshell.Io 1.0; Process {}', root);
        p.command = ["bash", "-c", cmd];
        p.running = true;
        p.runningChanged.connect(() => { if(!p.running) p.destroy(); });
    }
}
