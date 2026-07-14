import QtQuick
import Quickshell.Io
import "../services"

// Cursor theme + size. Themes are enumerated from the XCursor search path
// (any icon dir with a cursors/ subdir counts); selection persists and
// live-applies via Settings.set → COMPOSITOR.cursor.configure, which also
// exports XCURSOR_THEME/XCURSOR_SIZE for newly launched apps.
Flickable {
    id: root

    // [{ label, value }] — value is the theme's directory name, which is
    // exactly what XCURSOR_THEME wants.
    property var themes: []
    property var _themeLines: []

    contentHeight: column.implicitHeight + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Process {
        id: themeScan

        running: true
        command: ["sh", "-c",
            'for d in "$HOME/.icons" "$HOME/.local/share/icons" ' +
            '/usr/local/share/icons /usr/share/icons; do ' +
            '[ -d "$d" ] || continue; ' +
            'for t in "$d"/*/; do ' +
            '[ -d "$t/cursors" ] && basename "$t"; ' +
            'done; done | sort -u']

        stdout: SplitParser {
            onRead: line => root._themeLines.push(line)
        }

        onExited: {
            const options = [];
            for (const name of root._themeLines) {
                if (name.length > 0)
                    options.push({ label: name, value: name });
            }
            root.themes = options;
        }
    }

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 8

        Text {
            text: "cursor"
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.red
        }

        DropdownPicker {
            width: parent.width
            label: "cursor theme"
            options: root.themes
            current: Settings.get("cursor.theme", "Adwaita")
            onPicked: value => Settings.set("cursor.theme", value)
        }

        OptionChips {
            width: parent.width
            label: "cursor size"
            options: [
                { label: "16", value: 16 },
                { label: "20", value: 20 },
                { label: "24", value: 24 },
                { label: "32", value: 32 },
                { label: "48", value: 48 }
            ]
            current: Settings.get("cursor.size", 24)
            onPicked: value => Settings.set("cursor.size", value)
        }

        Text {
            width: parent.width
            text: "applies immediately to the compositor cursor and to newly "
                + "launched apps; apps already running keep their own cursor "
                + "until restarted"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }
    }
}