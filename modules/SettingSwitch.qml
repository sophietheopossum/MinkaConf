import QtQuick
import "../services"

// Labeled on/off row. The caller owns the state: bind `checked`, react to
// `toggled(value)`.
Rectangle {
    id: root

    property string label
    property string hint: ""
    property bool checked: false

    signal toggled(bool value)

    height: hint === "" ? 42 : 54
    radius: 8
    color: area.containsMouse ? Theme.surfaceRaised : Theme.surface
    border.width: 1
    border.color: Theme.line

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.text
        }

        Text {
            visible: root.hint !== ""
            text: root.hint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 3
            color: Theme.textFaint
        }
    }

    // Track + knob
    Rectangle {
        id: track

        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 20
        radius: 10
        color: root.checked ? Theme.redDim : Theme.line

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Rectangle {
            width: 16
            height: 16
            radius: 8
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? track.width - width - 2 : 2
            color: root.checked ? Theme.red : Theme.textMuted

            Behavior on x {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.toggled(!root.checked)
    }
}