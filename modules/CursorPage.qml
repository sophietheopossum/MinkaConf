import QtQuick
import Quickshell.Io
import "../services"

// Cursor theme + size.
// Every installed theme (any XCursor search-path dir with a cursors/ subdir)
// is shown as a card with a grid of ALL its cursors
// for side-by-side comparison; clicking a card applies the theme. Previews
// are rendered to ~/.cache/minkaconf/cursor-previews by the bundled
// xcursor-previews.py (cached — only new/changed cursors are re-decoded).
// Selection persists and live-applies via Settings.set →
// COMPOSITOR.cursor.configure, which also exports XCURSOR_THEME/XCURSOR_SIZE
// for newly launched apps.
Flickable {
    id: root

    // [{ name, cursors: [{ name, path }] }] sorted by theme name.
    property var themes: []
    property var _previewLines: []

    readonly property string scriptPath:
        Qt.resolvedUrl("../scripts/xcursor-previews.py")
            .toString()
            .replace("file://", "")

    readonly property string currentTheme: Settings.get("cursor.theme", "Adwaita")

    contentHeight: column.implicitHeight + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Process {
        id: previewScan

        running: true
        command: ["python3", root.scriptPath]

        stdout: SplitParser {
            onRead: line => root._previewLines.push(line)
        }

        onExited: {
            const byTheme = {};
            const order = [];
            for (const line of root._previewLines) {
                const parts = line.split("\t");
                if (parts.length !== 3)
                    continue;
                if (byTheme[parts[0]] === undefined) {
                    byTheme[parts[0]] = [];
                    order.push(parts[0]);
                }
                byTheme[parts[0]].push({ name: parts[1], path: parts[2] });
            }
            root.themes = order.map(name => ({
                name,
                cursors: byTheme[name]
            }));
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
            text: "pick a theme below — applies immediately to the compositor "
                + "cursor and to newly launched apps; apps already running "
                + "keep their own cursor until restarted"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }

        // No-themes / still-scanning placeholder.
        Text {
            visible: root.themes.length === 0
            text: previewScan.running ? "scanning installed cursor themes…"
                                      : "no cursor themes found"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            color: Theme.textFaint
        }

        Repeater {
            model: root.themes

            delegate: Rectangle {
                id: themeCard

                required property var modelData

                readonly property bool active:
                    root.currentTheme === themeCard.modelData.name

                width: parent.width
                height: cardColumn.implicitHeight + 24
                radius: 8
                color: Theme.surface
                border.width: 1
                border.color: active ? Theme.red
                            : cardArea.containsMouse ? Theme.redDim
                            : Theme.line

                MouseArea {
                    id: cardArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Settings.set("cursor.theme", themeCard.modelData.name)
                }

                Column {
                    id: cardColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    Row {
                        spacing: 8

                        Text {
                            text: themeCard.modelData.name
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.weight: themeCard.active ? Font.DemiBold : Font.Normal
                            color: Theme.text
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: themeCard.modelData.cursors.length + " cursors"
                            font.family: Theme.monoFamily
                            font.pixelSize: Theme.fontSize - 3
                            color: Theme.textFaint
                        }

                        Text {
                            visible: themeCard.active
                            anchors.verticalCenter: parent.verticalCenter
                            text: "in use"
                            font.family: Theme.monoFamily
                            font.pixelSize: Theme.fontSize - 3
                            color: Theme.red
                        }
                    }

                    Flow {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: themeCard.modelData.cursors

                            delegate: Image {
                                required property var modelData

                                width: 26
                                height: 26
                                source: "file://" + modelData.path
                                sourceSize.width: 32
                                sourceSize.height: 32
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                asynchronous: true
                            }
                        }
                    }
                }
            }
        }
    }
}