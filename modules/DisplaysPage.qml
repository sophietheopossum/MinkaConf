import QtQuick
import "../services"

// Per-output scale. Connected outputs come from the compositor
// (debug.geometry); each row also shows what the compositor is actually
// running right now, so a pending change is visible until it lands.
Flickable {
    id: root

    property var outputs: []

    function refresh() {
        Ipc.request("debug.geometry", undefined, (result, error) => {
            if (error || !result || !result.outputs)
                return;
            const list = [];
            for (const name of Object.keys(result.outputs))
                list.push(result.outputs[name]);
            list.sort((a, b) => a.name.localeCompare(b.name));
            root.outputs = list;
        });
    }

    Component.onCompleted: refresh()

    Connections {
        target: Ipc

        function onConnectedChanged() {
            if (Ipc.connected)
                root.refresh();
        }
    }

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
            text: "displays"
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.red
        }

        Text {
            visible: !Ipc.connected
            width: parent.width
            wrapMode: Text.WordWrap
            text: "not connected to a ShojiWM session — configured scales are shown and saved, but connected-display info is unavailable"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.textFaint
        }

        Repeater {
            model: root.outputs

            delegate: Rectangle {
                id: outputRow

                required property var modelData

                readonly property string outputName: modelData.name
                readonly property real configuredScale:
                    Settings.get(`displays.${outputName}.scale`, 1.0)

                width: column.width
                height: 74
                radius: 8
                color: Theme.surface
                border.width: 1
                border.color: Theme.line

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        text: outputRow.outputName
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        color: Theme.text
                    }

                    Text {
                        text: {
                            const res = outputRow.modelData.resolution;
                            const mode = res ? `${res.width}x${res.height}` : "off";
                            return `${mode}  ·  running at x${outputRow.modelData.scale}`;
                        }
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fontSize - 3
                        color: Theme.textFaint
                    }
                }

                OptionChips {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 330
                    height: 46
                    color: "transparent"
                    border.width: 0
                    label: ""
                    options: [
                        { label: "100%", value: 1.0 },
                        { label: "125%", value: 1.25 },
                        { label: "150%", value: 1.5 },
                        { label: "175%", value: 1.75 },
                        { label: "200%", value: 2.0 }
                    ]
                    current: outputRow.configuredScale
                    onPicked: value => {
                        Settings.set(`displays.${outputRow.outputName}.scale`, value);
                        refreshTimer.restart();
                    }
                }
            }
        }

        Text {
            visible: Ipc.connected
            width: parent.width
            wrapMode: Text.WordWrap
            text: "scale changes apply immediately and persist for the next session"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 3
            color: Theme.textFaint
        }
    }

    // Re-read compositor state shortly after a change so "running at"
    // reflects reality.
    Timer {
        id: refreshTimer
        interval: 800
        onTriggered: root.refresh()
    }
}