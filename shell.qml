import Quickshell
import QtQuick
import "services"
import "modules"

// MinkaConf — the Minka settings application. Quickshell-hosted floating
// window; owns ~/.config/shojiwm/src/minka-settings.json and live-applies
// changes over the ShojiWM IPC socket (settings.apply).
ShellRoot {
    FloatingWindow {
        id: win

        title: "MinkaConf"
        implicitWidth: 780
        implicitHeight: 540
        color: Theme.ground

        property string page: "input"

        // Sidebar
        Rectangle {
            id: sidebar

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 172
            color: Theme.surface

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: Theme.line
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 4

                Row {
                    spacing: 7
                    bottomPadding: 12

                    Text {
                        text: "❖"
                        font.pixelSize: Theme.fontSize + 3
                        color: Theme.red
                    }

                    Text {
                        text: "MinkaConf"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 2
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                }

                Repeater {
                    model: [
                        { id: "input", label: "input" },
                        { id: "displays", label: "displays" },
                        { id: "layout", label: "layout" },
                        { id: "wallpaper", label: "wallpaper" }
                    ]

                    delegate: Rectangle {
                        id: navItem

                        required property var modelData

                        readonly property bool active: win.page === navItem.modelData.id

                        width: parent.width
                        height: 34
                        radius: 7
                        color: active ? Theme.surfaceRaised
                             : navArea.containsMouse ? Theme.surfaceRaised
                             : "transparent"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: navItem.active ? 16 : 0
                            radius: 1.5
                            color: Theme.red

                            Behavior on height {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: navItem.modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            color: navItem.active ? Theme.text : Theme.textMuted
                        }

                        MouseArea {
                            id: navArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: win.page = navItem.modelData.id
                        }
                    }
                }
            }

            // Session link status — the IPC health dot, house style.
            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 14
                spacing: 7

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 7
                    radius: 3.5
                    color: Ipc.connected ? Theme.redDim : Theme.red

                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Ipc.connected ? "shojiwm session" : "offline — saved only"
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fontSize - 3
                    color: Theme.textFaint
                }
            }
        }

        // Stale-config banner: the running session predates this app's
        // settings schema, so edits would only half-apply until a reload.
        Rectangle {
            id: staleBanner

            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: parent.top
            height: Ipc.revisionStale ? 34 : 0
            visible: Ipc.revisionStale
            color: Theme.redDim

            Text {
                anchors.centerIn: parent
                text: "session config is older than MinkaConf — press Super+Shift+R to reload it"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                color: Theme.text
            }
        }

        InputPage {
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: staleBanner.bottom
            anchors.bottom: parent.bottom
            visible: win.page === "input"
        }

        DisplaysPage {
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: staleBanner.bottom
            anchors.bottom: parent.bottom
            visible: win.page === "displays"
        }

        LayoutPage {
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: staleBanner.bottom
            anchors.bottom: parent.bottom
            visible: win.page === "layout"
        }

        WallpaperPage {
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: staleBanner.bottom
            anchors.bottom: parent.bottom
            visible: win.page === "wallpaper"
        }
    }
}