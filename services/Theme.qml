pragma Singleton
import QtQuick
import Quickshell

// Eternal Darkness tokens — mirrored from MinkaShell/services/Theme.qml
// until the shared theme.json lands (ARCH_MAP M4).
Singleton {
    readonly property color ground: "#0a0709"
    readonly property color surface: "#161013"
    readonly property color surfaceRaised: "#1e161a"
    readonly property color line: "#2e2228"
    readonly property color text: "#ece5e7"
    readonly property color textMuted: "#a3959b"
    readonly property color textFaint: "#6e6167"
    readonly property color red: "#e0263c"
    readonly property color redDim: "#8f1e2d"
    readonly property color purple: "#a488c9"

    readonly property string fontFamily: "Noto Sans"
    readonly property string monoFamily: "monospace"
    readonly property int fontSize: 13
}