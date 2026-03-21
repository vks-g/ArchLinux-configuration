import QtQuick
import Quickshell
import "./bar"

Scope {
    // Variants allows you to spawn a window for every monitor connected
    // If you only have one monitor, it spawns once.
    Variants {
        model: Quickshell.screens

        // This instantiates your BarWindow for every screen found
        // 'modelData' contains the specific screen object
        BarWindow {
            screen: modelData
        }
    }
}
