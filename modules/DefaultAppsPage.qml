import QtQuick
import Quickshell.Io
import "../services"

// Default applications for open-with dialogs and xdg-open. Reads and writes
// the standard XDG MIME database (~/.config/mimeapps.list via xdg-mime), so
// choices here are honored by every GTK/Qt app with no Minka-specific
// plumbing. Candidate apps come from .desktop files; each category maps to
// a small set of MIME types and applies to all of them at once.
Flickable {
    id: root

    readonly property var categories: [
        { label: "web browser", hint: "http, https and html",
          types: ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"],
          match: "x-scheme-handler/https" },
        { label: "email", hint: "mailto links",
          types: ["x-scheme-handler/mailto"], match: "x-scheme-handler/mailto" },
        { label: "file manager", hint: "folders",
          types: ["inode/directory"], match: "inode/directory" },
        { label: "text editor", hint: "plain text",
          types: ["text/plain"], match: "text/plain" },
        { label: "pdf viewer", hint: "pdf documents",
          types: ["application/pdf"], match: "application/pdf" },
        { label: "image viewer", hint: "png, jpeg, webp",
          types: ["image/png", "image/jpeg", "image/webp"], match: "image/png" },
        { label: "video player", hint: "mp4, mkv, webm",
          types: ["video/mp4", "video/x-matroska", "video/webm"], match: "video/mp4" },
        { label: "music player", hint: "mp3, flac, ogg",
          types: ["audio/mpeg", "audio/flac", "audio/x-vorbis+ogg"], match: "audio/mpeg" }
    ]

    property var apps: []       // [{ id, name, mimes }] — first found wins per id
    property var defaults: ({}) // mime type -> current default desktop id
    property var _appLines: []
    property var _defLines: []

    function optionsFor(category) {
        const out = [];
        for (const app of root.apps)
            if (category.types.some(t => app.mimes.indexOf(t) !== -1))
                out.push({ label: app.name, value: app.id });
        out.sort((a, b) => a.label.localeCompare(b.label));
        return out;
    }

    function applyDefault(category, appId) {
        applier.command = ["sh", "-c",
            category.types
                .map(t => "xdg-mime default '" + appId + "' " + t)
                .join(" && ")];
        applier.running = true;
    }

    function _buildApps() {
        const seen = {};
        const apps = [];
        for (const line of root._appLines) {
            const parts = line.split("\t");
            if (parts.length < 4 || seen[parts[0]])
                continue;
            seen[parts[0]] = true;
            apps.push({ id: parts[0], name: parts[1], mimes: parts[3].split(";") });
        }
        root.apps = apps;
    }

    function _buildDefaults() {
        const map = {};
        for (const line of root._defLines) {
            const parts = line.split("\t");
            if (parts.length === 2 && parts[1].length > 0)
                map[parts[0]] = parts[1];
        }
        root.defaults = map;
    }

    contentHeight: column.implicitHeight + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // .desktop scan, user dirs shadowing system dirs by file id.
    Process {
        id: appScan

        running: true
        command: ["sh", "-c", `
for d in "$HOME/.local/share/applications" /usr/local/share/applications \
         /usr/share/applications /var/lib/flatpak/exports/share/applications \
         "$HOME/.local/share/flatpak/exports/share/applications"; do
  [ -d "$d" ] || continue
  for f in "$d"/*.desktop; do
    [ -e "$f" ] || continue
    awk -v id="$(basename "$f")" '
      /^\\[/ { insec = ($0 == "[Desktop Entry]"); next }
      !insec { next }
      /^Type=/ { type = substr($0, 6) }
      /^Name=/ { if (name == "") name = substr($0, 6) }
      /^Icon=/ { if (icon == "") icon = substr($0, 6) }
      /^MimeType=/ { mime = substr($0, 10) }
      /^NoDisplay=true/ { skip = 1 }
      /^Hidden=true/ { skip = 1 }
      END {
        if (type == "Application" && !skip && name != "" && mime != "")
          printf "%s\\t%s\\t%s\\t%s\\n", id, name, icon, mime
      }' "$f"
  done
done`]

        stdout: SplitParser {
            onRead: line => root._appLines.push(line)
        }

        onExited: root._buildApps()
    }

    Process {
        id: defQuery

        running: true
        // NOTE: no flatMap — Qt's QML engine doesn't implement it.
        command: ["sh", "-c",
            "for t in " + root.categories.map(c => c.types.join(" ")).join(" ") + "; do"
            + " printf '%s\\t%s\\n' \"$t\" \"$(xdg-mime query default \"$t\" 2>/dev/null)\";"
            + " done"]

        stdout: SplitParser {
            onRead: line => root._defLines.push(line)
        }

        onExited: root._buildDefaults()
    }

    Process {
        id: applier

        onExited: {
            root._defLines = [];
            defQuery.running = true;
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
            text: "default applications"
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.red
        }

        Text {
            width: parent.width
            text: "used by open-with dialogs, links and xdg-open across all apps; each choice applies to every file type in its category"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.categories

            delegate: Column {
                id: categoryItem

                required property var modelData

                width: column.width
                spacing: 4

                DropdownPicker {
                    width: parent.width
                    label: categoryItem.modelData.label
                    options: root.optionsFor(categoryItem.modelData)
                    current: root.defaults[categoryItem.modelData.match]
                    onPicked: value => root.applyDefault(categoryItem.modelData, value)
                }

                Text {
                    text: categoryItem.modelData.hint
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fontSize - 3
                    color: Theme.textFaint
                    leftPadding: 2
                    bottomPadding: 6
                }
            }
        }
    }
}