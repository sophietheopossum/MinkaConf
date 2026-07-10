import QtQuick
import Quickshell
import "../services"

// Shell layout policy. "zenbook duo" pins every persistent shell surface
// (bar, dock, menus) to the ScreenPad and keeps the main display clear;
// "general" gives every output the KDE-style layout. "auto" detects the
// ScreenPad by shape (wide and short), which is also the effective default
// when no settings file exists yet — a wrong first-run guess just means
// flipping this switch. MinkaShell watches the settings file, so the change
// lands live without a reload.
Flickable {
    id: root

    // Same shape heuristic as MinkaShell's ShellLayout: the ScreenPad is a
    // wide, very short output.
    readonly property bool screenPadPresent:
        Quickshell.screens.some(s => s !== null && s.height <= 600 && s.width >= 1600)

    contentHeight: column.implicitHeight + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 8

        Text {
            text: "shell layout"
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.red
        }

        OptionChips {
            width: parent.width
            label: "monitor roles"
            options: [
                { label: "auto", value: "auto" },
                { label: "zenbook duo", value: "duo" },
                { label: "general", value: "general" }
            ]
            current: Settings.get("shell.layout", "auto")
            onPicked: value => Settings.set("shell.layout", value)
        }

        Text {
            width: parent.width
            text: root.screenPadPresent
                ? "auto detects: zenbook duo — a ScreenPad-shaped output is connected"
                : "auto detects: general — no ScreenPad-shaped output connected"
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSize - 3
            color: Theme.textFaint
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            text: "zenbook duo pins the bar, dock and menus to the ScreenPad and keeps the main display clear; general lays out every output KDE-style"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }
    }
}