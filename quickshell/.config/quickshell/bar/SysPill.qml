import QtQuick
import QtQuick.Layouts
import ".." // Import Style.qml

Rectangle {
    id: root

    // API
    property string icon: ""
    property string label: ""
    property color baseColor: Style.subtext0
    property bool isActive: false
    property color activeColor: Style.blue
    property bool showLabel: true
    signal clicked()

    // Layout
    height: 24
    // Calculate width based on content + padding
    width: row.implicitWidth + 16
    radius: 12
    
    // Borders
    border.width: 1
    border.color: "transparent"

    // FIX: Define Gradient unconditionally, but change colors dynamically
    // If Inactive: Both stops use the transparent background color (0.04 alpha)
    // If Active: Use the activeColor gradient
    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { 
            position: 0.0
            color: root.isActive ? root.activeColor : Qt.rgba(1, 1, 1, 0.04)
        }
        GradientStop { 
            position: 1.0 
            color: root.isActive ? Qt.darker(root.activeColor, 1.2) : Qt.rgba(1, 1, 1, 0.04)
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 5
        
        Text {
            text: root.icon
            font.family: Style.fontIcon
            font.pixelSize: 14
            color: root.isActive ? Style.crust : root.baseColor
        }
        
        Text {
            visible: root.showLabel
            text: root.label
            font.family: Style.fontMain
            font.weight: Font.ExtraBold
            font.pixelSize: 11
            color: root.isActive ? Style.crust : Style.text
            elide: Text.ElideRight
            Layout.maximumWidth: 100
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
