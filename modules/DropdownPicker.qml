import QtQuick
import "../services"

// Labeled accordion picker: collapsed shows the current choice, expanded
// lists options inline (no overlay windows, so it works inside Flickables).
//   options: [{ label: "1920x1080 @ 60Hz", value: {...} }]
// `current` is compared to option values by JSON equality.
Rectangle {
    id: root

    property string label
    property var options: []
    property var current
    property bool expanded: false

    signal picked(var value)

    readonly property string currentLabel: {
        for (const option of options)
            if (JSON.stringify(option.value) === JSON.stringify(current))
                return option.label;
        return current === undefined || current === null ? "—" : String(current);
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
                    JSON.stringify(optionRow.modelData.value)
                        === JSON.stringify(root.current)

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