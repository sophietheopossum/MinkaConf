import QtQuick
import "../services"

// Labeled slider. Commits on release / wheel-settle rather than every
// pixel, so live-apply doesn't spam the compositor.
Rectangle {
    id: root

    property string label
    property real from: -1
    property real to: 1
    property real value: 0
    property real wheelStep: 0.05
    property int decimals: 2

    signal committed(real value)

    // Visual position while interacting; synced from `value` when idle.
    property real liveValue: value
    onValueChanged: {
        if (!trackArea.pressed && !settleTimer.running)
            liveValue = value;
    }

    height: 64
    radius: 8
    color: Theme.surface
    border.width: 1
    border.color: Theme.line

    function _commit() {
        const rounded = Math.round(liveValue * Math.pow(10, decimals))
            / Math.pow(10, decimals);
        root.committed(rounded);
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 8
        text: root.label
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.text
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 8
        text: root.liveValue.toFixed(root.decimals)
        font.family: Theme.monoFamily
        font.pixelSize: Theme.fontSize - 1
        color: Theme.textMuted
    }

    Item {
        id: slider

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: 10
        height: 18

        readonly property real fraction:
            (root.liveValue - root.from) / (root.to - root.from)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Theme.line
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(1, slider.fraction)) * parent.width
            height: 4
            radius: 2
            color: Theme.redDim
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(1, slider.fraction)) * (parent.width - width)
            width: 14
            height: 14
            radius: 7
            color: trackArea.pressed || trackArea.containsMouse ? Theme.red : Theme.textMuted
        }

        MouseArea {
            id: trackArea
            anchors.fill: parent
            hoverEnabled: true

            function applyAt(mouseX) {
                const fraction = Math.max(0, Math.min(1, mouseX / width));
                root.liveValue = root.from + fraction * (root.to - root.from);
            }

            onPressed: mouse => applyAt(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    applyAt(mouse.x);
            }
            onReleased: root._commit()
            onWheel: wheel => {
                const direction = wheel.angleDelta.y > 0 ? 1 : -1;
                root.liveValue = Math.max(root.from, Math.min(root.to,
                    root.liveValue + direction * root.wheelStep));
                settleTimer.restart();
            }
        }
    }

    // Wheel input settles briefly before committing.
    Timer {
        id: settleTimer
        interval: 350
        onTriggered: root._commit()
    }
}