import QtQuick
import "../services"

// Labeled single-choice chip row.
//   options: [{ label: "adaptive", value: "adaptive" }, ...]
Rectangle {
    id: root

    property string label
    property var options: []
    property var current

    signal picked(var value)

    height: 46
    radius: 8
    color: Theme.surface
    border.width: 1
    border.color: Theme.line

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.text
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: root.options

            delegate: Rectangle {
                id: chip

                required property var modelData

                readonly property bool active: chip.modelData.value === root.current

                width: chipText.implicitWidth + 20
                height: 26
                radius: 6
                color: active ? Theme.redDim
                     : chipArea.containsMouse ? Theme.surfaceRaised
                     : "transparent"
                border.width: 1
                border.color: active ? Theme.red : Theme.line

                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: chip.modelData.label
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fontSize - 2
                    color: chip.active ? Theme.text : Theme.textMuted
                }

                MouseArea {
                    id: chipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.picked(chip.modelData.value)
                }
            }
        }
    }
}