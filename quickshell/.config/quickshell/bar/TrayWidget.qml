import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import ".."

RowLayout {
    spacing: 5

    Repeater {
        // SystemTray is a singleton that provides the list of items
        model: SystemTray.items

        Rectangle {
            id: trayItem
            width: 24
            height: 24
            radius: 4
            color: hover.hovered ? Style.surface1 : "transparent"
            
            // The icon provided by the tray service
            Image {
                anchors.centerIn: parent
                source: modelData.icon
                width: 18
                height: 18
                fillMode: Image.PreserveAspectFit
            }

            // Interaction
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                // Left click to activate
                onClicked: modelData.activate(Qt.LeftButton)
                
                // Right click usually opens the menu
                onPressed: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        modelData.menu.open(mouse.x, mouse.y)
                    }
                }
            }
        }
    }
}
