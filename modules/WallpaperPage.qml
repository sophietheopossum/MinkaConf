import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

// Wallpaper picker. Sources: the user's ~/Pictures/wallpapers plus installed
// wallpaper packages — KDE-style packages under /usr/share/wallpapers (best
// resolution per package, dark variants skipped) and plain images under
// /usr/share/backgrounds. Selection writes shell.wallpaper to
// minka-settings.json; MinkaShell watches the file, so the background swaps
// live without a reload.
Flickable {
    id: root

    property var userWalls: []
    property var systemWalls: []
    property var _lines: []

    readonly property string current: Settings.get("shell.wallpaper", "")

    function rescan() {
        root._lines = [];
        scanner.running = true;
    }

    function _buildModel() {
        const home = Quickshell.env("HOME");
        const userPrefix = home + "/Pictures/wallpapers/";
        const packages = {};
        const user = [];
        const system = [];

        for (const path of root._lines) {
            // KDE packages ship light/dark image sets; showing both would
            // just duplicate every tile.
            if (path.indexOf("/images_dark/") !== -1)
                continue;
            const pkg = path.match(/^(\/usr\/share\/wallpapers\/([^/]+))\/contents\/images\//);
            if (pkg) {
                const res = path.match(/(\d{3,5})x(\d{3,5})\.\w+$/);
                const area = res ? parseInt(res[1], 10) * parseInt(res[2], 10) : 0;
                const entry = packages[pkg[1]];
                if (!entry || area > entry.area)
                    packages[pkg[1]] = { path: path, area: area, name: pkg[2] };
                continue;
            }
            const name = path.substring(path.lastIndexOf("/") + 1).replace(/\.\w+$/, "");
            if (path.startsWith(userPrefix))
                user.push({ path: path, name: name });
            else
                system.push({ path: path, name: name });
        }
        for (const key of Object.keys(packages))
            system.push({ path: packages[key].path, name: packages[key].name });

        const byName = (a, b) => a.name.localeCompare(b.name);
        user.sort(byName);
        system.sort(byName);
        root.userWalls = user;
        root.systemWalls = system;
    }

    contentHeight: column.implicitHeight + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Component.onCompleted: rescan()

    Process {
        id: scanner

        command: ["sh", "-c",
            "find -L \"$HOME/Pictures/wallpapers\" /usr/share/backgrounds /usr/share/wallpapers"
            + " -maxdepth 5 -type f \\( -iname '*.jpg' -o -iname '*.jpeg'"
            + " -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null"]

        stdout: SplitParser {
            onRead: line => {
                const trimmed = line.trim();
                if (trimmed.length > 0)
                    root._lines.push(trimmed);
            }
        }

        onExited: root._buildModel()
    }

    component WallTile: Rectangle {
        id: tile

        required property var modelData

        readonly property bool selected: root.current === tile.modelData.path

        width: 172
        height: 104
        radius: 7
        color: Theme.surface
        border.width: selected ? 2 : 1
        border.color: selected ? Theme.red : Theme.line

        Image {
            anchors.fill: parent
            anchors.margins: 2
            source: "file://" + tile.modelData.path
            sourceSize.width: 344
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            clip: true
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 2
            height: 20
            color: "#b0101319"

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: tile.modelData.name
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fontSize - 3
                color: Theme.text
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Settings.set("shell.wallpaper", tile.modelData.path)
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
            text: "wallpaper"
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.red
        }

        Row {
            spacing: 8

            Rectangle {
                width: noneLabel.implicitWidth + 20
                height: 26
                radius: 7
                color: root.current === "" ? Theme.surfaceRaised
                     : noneArea.containsMouse ? Theme.surfaceRaised
                     : "transparent"
                border.width: 1
                border.color: root.current === "" ? Theme.red : Theme.line

                Text {
                    id: noneLabel
                    anchors.centerIn: parent
                    text: "no wallpaper"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    color: root.current === "" ? Theme.text : Theme.textMuted
                }

                MouseArea {
                    id: noneArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Settings.set("shell.wallpaper", "")
                }
            }

            Rectangle {
                width: rescanLabel.implicitWidth + 20
                height: 26
                radius: 7
                color: rescanArea.containsMouse ? Theme.surfaceRaised : "transparent"
                border.width: 1
                border.color: Theme.line

                Text {
                    id: rescanLabel
                    anchors.centerIn: parent
                    text: "rescan"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    color: Theme.textMuted
                }

                MouseArea {
                    id: rescanArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.rescan()
                }
            }
        }

        Text {
            topPadding: 8
            text: "~/Pictures/wallpapers"
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSize - 3
            color: Theme.textFaint
        }

        Flow {
            width: parent.width
            spacing: 10

            Repeater {
                model: root.userWalls

                delegate: WallTile {}
            }
        }

        Text {
            visible: root.userWalls.length === 0
            text: "no images found — drop some in ~/Pictures/wallpapers"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.textMuted
        }

        Text {
            topPadding: 8
            text: "system & packages"
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSize - 3
            color: Theme.textFaint
        }

        Flow {
            width: parent.width
            spacing: 10

            Repeater {
                model: root.systemWalls

                delegate: WallTile {}
            }
        }

        Text {
            visible: root.systemWalls.length === 0
            text: "no wallpaper packages installed"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.textMuted
        }
    }
}