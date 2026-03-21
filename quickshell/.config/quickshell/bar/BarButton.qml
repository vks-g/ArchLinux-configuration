import QtQuick
import ".." // Imports Style.qml from parent directory

Rectangle {
    id: root
    
    // Custom properties
    property string icon: ""
    property bool isTextIcon: false
    signal clicked()

    // Layout properties
    width: 32
    height: 32
    radius: Style.cornerRadius
    
    // Colors
    color: hover.hovered ? Style.surface0 : Qt.rgba(30/255, 30/255, 46/255, 0.85)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.05)

    // Icon Image (SVG)
    Image {
        visible: !root.isTextIcon
        anchors.centerIn: parent
        // Assumes icons are in ../images/icons/ relative to this file
        source: visible ? "../images/icons/" + root.icon + ".svg" : ""
        sourceSize.width: 18
        sourceSize.height: 18
    }

    // Text Icon (Font)
    Text {
        visible: root.isTextIcon
        anchors.centerIn: parent
        text: root.icon
        font.family: Style.fontIcon
        font.pixelSize: 18
        color: hover.hovered ? Style.sky : Style.sapphire
    }

    // Interaction
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
