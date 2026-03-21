import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

Rectangle {
    id: root
    height: 32
    // Width grows with content
    width: row.implicitWidth + 12
    
    color: Qt.rgba(30/255, 30/255, 46/255, 0.85)
    radius: Style.cornerRadius
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.05)

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 5
        
        Repeater {
            model: DataSource.workspaces

            Rectangle {
                id: wsBtn
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: 8
                
                // Color Logic based on Eww CSS classes
                color: {
                    if (modelData.state === "active") return Style.mauve;
                    if (modelData.state === "occupied") return Style.surface1;
                    return "transparent"; // empty
                }

                // Text Color Logic
                property color textColor: {
                    if (modelData.state === "active") return Style.base;
                    if (modelData.state === "occupied") return Style.blue;
                    return Style.surface2; // empty
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData.id
                    font.family: "JetBrains Mono ExtraBold"
                    font.pixelSize: 14
                    color: parent.textColor
                    font.weight: modelData.state === "active" ? Font.Black : Font.Normal
                }
                
                // Hover effect
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        if (modelData.state === "active") wsBtn.color = Style.pink
                        else if (modelData.state === "occupied") wsBtn.color = Style.surface2
                        else wsBtn.color = Qt.rgba(1,1,1,0.05)
                    }
                    onExited: {
                         // Reset happens automatically via binding above
                    }
                    onClicked: {
                        // Switch workspace
                        var p = Qt.createQmlObject('import Quickshell.Io 1.0; Process {}', parent);
                        p.command = ["hyprctl", "dispatch", "workspace", modelData.id];
                        p.running = true;
                    }
                }
            }
        }
    }
}
