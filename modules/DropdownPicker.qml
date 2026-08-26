import QtQuick
import "../services"

// Labeled accordion picker: collapsed shows the current choice, expanded
// lists options inline (no overlay windows, so it works inside Flickables).
//   options: [{ label: "1920x1080 @ 60Hz", value: {...} }]
// `current` is compared to option values by SORTED-KEY equality (stableKey).
Rectangle {
    id: root

    property string label
    property var options: []
    property var current
    property bool expanded: false

    signal picked(var value)

    // Order-independent structural key. Plain JSON.stringify cannot be used here:
    // it preserves insertion order, so {width,height,refreshRate} built by the mode
    // list never matched the {height,refreshRate,width} the settings file stores
    // (JSON object keys come back alphabetised). The comparison silently failed and
    // the collapsed picker fell through to String(current) — the literal text
    // "[object Object]" — while the matching row also lost its highlight.
    function stableKey(value) {
        if (value === null || typeof value !== "object")
            return JSON.stringify(value);
        if (Array.isArray(value))
            return "[" + value.map(root.stableKey).join(",") + "]";
        return "{" + Object.keys(value).sort()
            .map(k => JSON.stringify(k) + ":" + root.stableKey(value[k]))
            .join(",") + "}";
    }

    readonly property string currentLabel: {
        for (const option of options)
            if (root.stableKey(option.value) === root.stableKey(current))
                return option.label;
        // Still no match: show something honest rather than a stringified object.
        if (current === undefined || current === null)
            return "—";
        return typeof current === "object" ? "(custom)" : String(current);
    }

    height: 46 + (expanded ? optionColumn.implicitHeight + 8 : 0)
    radius: 8
    color: Theme.surface
    border.width: 1
    border.color: root.expanded ? Theme.redDim : Theme.line
    clip: true

    Behavior on height {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 14
        text: root.label
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.text
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 14
        spacing: 6

        Text {
            text: root.currentLabel
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSize - 1
            color: Theme.textMuted
        }

        Text {
            text: root.expanded ? "▴" : "▾"
            font.pixelSize: Theme.fontSize - 2
            color: Theme.textFaint
        }
    }

    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 46
        onClicked: root.expanded = !root.expanded
    }

    Column {
        id: optionColumn

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 46
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 1

        Repeater {
            model: root.options

            delegate: Rectangle {
                id: optionRow

                required property var modelData

                readonly property bool active:
                    root.stableKey(optionRow.modelData.value)
                        === root.stableKey(root.current)

                width: parent.width
                height: 28
                radius: 5
                color: active ? Theme.redDim
                     : optionArea.containsMouse ? Theme.surfaceRaised
                     : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: optionRow.modelData.label
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fontSize - 2
                    color: optionRow.active ? Theme.text : Theme.textMuted
                }

                MouseArea {
                    id: optionArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.expanded = false;
                        root.picked(optionRow.modelData.value);
                    }
                }
            }
        }
    }
}