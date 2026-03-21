import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

Rectangle {
    id: root
    visible: DataSource.music.status !== "Stopped"
    height: 32
    width: layout.implicitWidth + 20
    
    color: Qt.rgba(30/255, 30/255, 46/255, 0.85)
    radius: Style.cornerRadius
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.05)

    // EWW Class: bar-media-playing (vinyl spin)
    property bool isPlaying: DataSource.music.status === "Playing"

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 10

        // Album Art
        Item {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            
            Image {
                id: art
                anchors.fill: parent
                source: DataSource.music.artUrl || ""
                fillMode: Image.PreserveAspectCrop
                
                // Circular mask (simulated with opacity mask or just radius)
                layer.enabled: true
                layer.effect: ShaderEffect {
                    property var source: art
                    fragmentShader: "
                        varying highp vec2 qt_TexCoord0;
                        uniform sampler2D source;
                        void main() {
                            lowp vec4 tex = texture2D(source, qt_TexCoord0);
                            lowp float dist = distance(qt_TexCoord0, vec2(0.5, 0.5));
                            if (dist > 0.5) discard;
                            gl_FragColor = tex;
                        }
                    "
                }
            }
            
            // Vinyl Spin Animation
            RotationAnimator {
                target: art
                from: 0; to: 360
                duration: 5000
                running: root.isPlaying
                loops: Animation.Infinite
            }
        }

        // Text Info
        ColumnLayout {
            spacing: 0
            Text {
                text: DataSource.music.title
                font.family: Style.fontMain
                font.weight: Font.ExtraBold
                font.pixelSize: 12
                color: Style.sapphire
                elide: Text.ElideRight
                Layout.maximumWidth: 150
            }
            Text {
                text: DataSource.music.timeStr
                font.family: Style.fontMain
                font.weight: Font.Bold
                font.pixelSize: 10
                color: Style.overlay1
            }
        }

        // Controls
        RowLayout {
            spacing: 5
            
            Text { 
                text: "󰒮" 
                font.family: Style.fontIcon; font.pixelSize: 16; color: Style.overlay2 
                MouseArea { anchors.fill: parent; onClicked: quickExec(["playerctl", "previous"]) }
            }
            Text { 
                text: root.isPlaying ? "󰏤" : "󰐊"
                font.family: Style.fontIcon; font.pixelSize: 18; color: Style.text 
                MouseArea { anchors.fill: parent; onClicked: quickExec(["playerctl", "play-pause"]) }
            }
            Text { 
                text: "󰒭" 
                font.family: Style.fontIcon; font.pixelSize: 16; color: Style.overlay2 
                MouseArea { anchors.fill: parent; onClicked: quickExec(["playerctl", "next"]) }
            }
        }
    }

    function quickExec(cmd) {
        var p = Qt.createQmlObject('import Quickshell.Io 1.0; Process {}', parent);
        p.command = cmd;
        p.running = true;
    }
}
