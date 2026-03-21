pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Changed from QtObject to Item to allow children (Process/Parser)
Item {
    id: root

    // ============================
    // 1. WORKSPACES (Streaming)
    // ============================
    property var workspaces: []
    
    Process {
        id: wsProcess
        command: ["bash", "./scripts/workspaces.sh"]
        running: true
        
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    root.workspaces = JSON.parse(data);
                } catch (e) {
                    console.log("WS Parse Error:", e);
                }
            }
        }
    }

    // ============================
    // 2. WEATHER (Polling)
    // ============================
    property var weatherData: null
    property string weatherIcon: ""
    property string weatherTemp: "0°"
    property color weatherHex: "#ffffff"

    Process {
        id: weatherProc
        command: ["bash", "./scripts/weather.sh", "--json"]
        running: true
        
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    var json = JSON.parse(data);
                    root.weatherData = json;
                    if (json.forecast && json.forecast.length > 0) {
                        root.weatherIcon = json.forecast[0].icon;
                        root.weatherTemp = json.forecast[0].max + "°";
                        root.weatherHex = json.forecast[0].hex;
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 300000 
        running: true; repeat: true
        onTriggered: weatherProc.running = true
    }

    // ============================
    // 3. MUSIC (Polling)
    // ============================
    property var music: ({
        title: "Not Playing", 
        artist: "", 
        status: "Stopped", 
        artUrl: "",
        percent: 0,
        timeStr: "--:--"
    })

    Process {
        id: musicProc
        command: ["bash", "./scripts/music_info.sh"]
        running: true

        stdout: SplitParser {
            onRead: (data) => {
                try {
                    root.music = JSON.parse(data);
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 1000
        running: true; repeat: true
        onTriggered: musicProc.running = true
    }

    // ============================
    // 4. WIFI (Polling)
    // ============================
    property var wifi: ({ power: "off", connected: null, networks: [] })
    
    Process {
        id: wifiProc
        command: ["bash", "./scripts/wifi_panel_logic.sh"]
        running: true
        
        stdout: SplitParser {
            onRead: (data) => { try { root.wifi = JSON.parse(data) } catch(e){} }
        }
    }
    Timer { 
        interval: 3000
        running: true; repeat: true
        onTriggered: wifiProc.running = true 
    }

    // ============================
    // 5. BLUETOOTH (Polling)
    // ============================
    property var bluetooth: ({ power: "off", connected: { mac: "" }, devices: [] })

    Process {
        id: btProc
        command: ["bash", "./scripts/bluetooth_panel_logic.sh", "--status"]
        running: true
        
        stdout: SplitParser {
            onRead: (data) => { try { root.bluetooth = JSON.parse(data) } catch(e){} }
        }
    }
    Timer { 
        interval: 3000
        running: true; repeat: true
        onTriggered: btProc.running = true 
    }
}
