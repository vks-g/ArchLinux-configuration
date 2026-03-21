import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

Rectangle {
    id: root
    height: 32
    // Auto width based on children
    width: layout.implicitWidth + 16
    
    radius: 24
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.08)
    
    // Glassy Gradient Background
    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: Qt.rgba(30/255, 30/255, 46/255, 0.95) }
        GradientStop { position: 1.0; color: Qt.rgba(24/255, 24/255, 37/255, 0.85) }
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 10

        // --- KB Layout ---
        SysPill {
            icon: "󰌌"
            label: "US"
            baseColor: Style.overlay2
        }

        // --- WiFi ---
        SysPill {
            property var w: DataSource.wifi
            
            // Safe access using ternary checks
            icon: w.power === "on" ? (w.connected ? w.connected.icon : "󰤮") : "󰤮"
            label: w.power === "on" ? (w.connected ? w.connected.ssid : "Disconnected") : "Off"
            
            isActive: w.power === "on" && w.connected !== null
            activeColor: Style.blue
            
            onClicked: console.log("Wifi Clicked")
        }

        // --- Bluetooth ---
        SysPill {
            property var b: DataSource.bluetooth
            property bool hasDevice: b.connected && b.connected.mac !== ""
            
            icon: b.power === "on" ? (hasDevice ? b.connected.icon : "") : ""
            label: hasDevice ? b.connected.name : ""
            showLabel: hasDevice
            
            isActive: b.power === "on" && hasDevice
            activeColor: Style.mauve
        }

        // --- Volume ---
        SysPill {
            icon: ""
            label: "50%"
            baseColor: Style.peach
        }

        // --- Battery ---
        SysPill {
            icon: "󰁹"
            label: "100%"
            baseColor: Style.green
        }
    }
}
