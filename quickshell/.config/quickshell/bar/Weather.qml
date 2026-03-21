import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    height: 32
    width: row.implicitWidth + 24
    color: Qt.rgba(30/255, 30/255, 46/255, 0.85)
    radius: Style.cornerRadius
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.05)

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 15

        // Clock
        ColumnLayout {
            spacing: -2
            Text {
                id: timeTxt
                text: Qt.formatDateTime(new Date(), "hh:mm:ss AP")
                font.family: Style.fontMain
                font.weight: Font.Black
                font.pixelSize: 14
                color: Style.blue
                
                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: timeTxt.text = Qt.formatDateTime(new Date(), "hh:mm:ss AP")
                }
            }
            Text {
                id: dateTxt
                text: Qt.formatDateTime(new Date(), "dddd, MMMM d")
                font.family: Style.fontMain
                font.weight: Font.Bold
                font.pixelSize: 10
                color: Style.subtext0
            }
        }

        // Weather
        RowLayout {
            spacing: 5
            Text {
                text: DataSource.weatherIcon
                font.family: Style.fontIcon
                font.pixelSize: 22
                color: DataSource.weatherHex
            }
            Text {
                text: DataSource.weatherTemp
                font.family: Style.fontMain
                font.weight: Font.ExtraBold
                font.pixelSize: 15
                color: Style.peach
            }
        }
    }
}
