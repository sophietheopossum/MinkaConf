import QtQuick
import Quickshell.Io
import "../services"

// Mouse + touchpad + keyboard settings. Every control persists AND
// live-applies via Settings.set (see services/Settings.qml).
Flickable {
    id: root

    // XKB layouts and variants parsed from evdev.lst:
    //   layouts: [{ label, value }] sorted by description
    //   variantsByLayout: { layoutCode: [{ label, value }] }
    property var layouts: []
    property var variantsByLayout: ({})
    property var _lstLines: []

    readonly property string currentLayout: Settings.get("input.keyboard.layout", "us")

    readonly property var variantOptions: {
        const base = [{ label: "default", value: "" }];
        const extra = root.variantsByLayout[root.currentLayout];
        return extra ? base.concat(extra) : base;
    }

    function _buildXkbModel() {
        const layouts = [];
        const variants = {};
        let section = "";
        for (const line of root._lstLines) {
            if (line.startsWith("!")) {
                section = line.trim();
                continue;
            }
            const m = line.match(/^\s+(\S+)\s+(.*\S)\s*$/);
            if (!m)
                continue;
            if (section === "! layout") {
                layouts.push({ label: m[2] + "  —  " + m[1], value: m[1] });
            } else if (section === "! variant") {
                const v = m[2].match(/^([a-zA-Z0-9_-]+): (.*)$/);
                if (!v)
                    continue;
                if (variants[v[1]] === undefined)
                    variants[v[1]] = [];
                variants[v[1]].push({ label: v[2] + "  —  " + m[1], value: m[1] });
            }
        }
        layouts.sort((a, b) => a.label.localeCompare(b.label));
        for (const key of Object.keys(variants))
            variants[key].sort((a, b) => a.label.localeCompare(b.label));
        root.layouts = layouts;
        root.variantsByLayout = variants;
    }

    contentHeight: column.implicitHeight + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Process {
        id: xkbList

        running: true
        command: ["sed", "-n",
            "/^! layout$/,/^! variant$/p; /^! variant$/,/^! option$/p",
            "/usr/share/X11/xkb/rules/evdev.lst"]

        stdout: SplitParser {
            onRead: line => root._lstLines.push(line)
        }

        onExited: root._buildXkbModel()
    }

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 8

        Text {
            text: "pointer"
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.red
        }

        SettingSlider {
            width: parent.width
            label: "pointer speed"
            from: -1
            to: 1
            value: Settings.get("input.pointerAccel", 0)
            onCommitted: value => Settings.set("input.pointerAccel", value)
        }

        OptionChips {
            width: parent.width
            label: "acceleration profile"
            options: [
                { label: "adaptive", value: "adaptive" },
                { label: "flat", value: "flat" }
            ]
            current: Settings.get("input.accelProfile", "adaptive")
            onPicked: value => Settings.set("input.accelProfile", value)
        }

        SettingSwitch {
            width: parent.width
            label: "natural scrolling (mouse)"
            hint: "scroll content, not the viewport"
            checked: Settings.get("input.naturalScroll", false)
            onToggled: value => Settings.set("input.naturalScroll", value)
        }

        Item { width: 1; height: 8 }

        Text {
            text: "touchpad"
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.red
        }

        SettingSwitch {
            width: parent.width
            label: "natural scrolling (touchpad)"
            checked: Settings.get("input.touchpad.naturalScroll", false)
            onToggled: value => Settings.set("input.touchpad.naturalScroll", value)
        }

        SettingSwitch {
            width: parent.width
            label: "tap to click"
            checked: Settings.get("input.touchpad.tapToClick", true)
            onToggled: value => Settings.set("input.touchpad.tapToClick", value)
        }

        SettingSwitch {
            width: parent.width
            label: "disable while typing"
            checked: Settings.get("input.touchpad.disableWhileTyping", true)
            onToggled: value => Settings.set("input.touchpad.disableWhileTyping", value)
        }

        SettingSlider {
            width: parent.width
            label: "touchpad scroll speed"
            from: 0.1
            to: 1.0
            value: Settings.get("input.touchpad.scrollFactor", 0.3)
            onCommitted: value => Settings.set("input.touchpad.scrollFactor", value)
        }

        Item { width: 1; height: 8 }

        Text {
            text: "keyboard"
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.red
        }

        DropdownPicker {
            width: parent.width
            label: "layout"
            options: root.layouts
            current: root.currentLayout
            onPicked: value => {
                // A variant belongs to one layout; switching layouts always
                // resets to the default variant.
                Settings.set("input.keyboard.layout", value);
                Settings.set("input.keyboard.variant", "");
            }
        }

        DropdownPicker {
            width: parent.width
            label: "variant"
            options: root.variantOptions
            current: Settings.get("input.keyboard.variant", "")
            onPicked: value => Settings.set("input.keyboard.variant", value)
        }

        Text {
            width: parent.width
            text: "applies to every keyboard; per-device overrides live in the ShojiWM config"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }
    }
}