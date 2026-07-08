import QtQuick
import "../services"

// Mouse + touchpad settings. Every control persists AND live-applies via
// Settings.set (see services/Settings.qml).
Flickable {
    id: root

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
    }
}