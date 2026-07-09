import QtQuick
import "../services"

// Visual display arrangement, KDE-style: drag monitor rectangles on the
// canvas, click one to edit its mode/scale/state below. Positions commit on
// drag release (snapped to neighbor edges, normalized to a 0,0 origin) and
// apply live via settings.apply. Risky changes (mode, enable, mirror, HDR)
// arm the revert guard: unless kept, the previous settings restore
// automatically so a black screen heals itself.
Flickable {
    id: root

    property var outputs: []
    property string selectedName: ""

    // Working copy of logical positions while dragging: { name: {x, y} }.
    property var layoutPositions: ({})

    readonly property var enabledOutputs:
        outputs.filter(o => o.enabled && o.resolution)

    readonly property var selectedOutput:
        outputs.find(o => o.name === root.selectedName) ?? null

    function logicalSize(output) {
        return {
            width: output.resolution.width / output.scale,
            height: output.resolution.height / output.scale
        };
    }

    function refresh() {
        Ipc.request("debug.geometry", undefined, (result, error) => {
            if (error || !result || !result.outputs)
                return;
            const list = [];
            const positions = {};
            for (const name of Object.keys(result.outputs)) {
                const output = result.outputs[name];
                list.push(output);
                positions[name] = { x: output.position.x, y: output.position.y };
            }
            list.sort((a, b) => a.name.localeCompare(b.name));
            root.outputs = list;
            root.layoutPositions = positions;
            if (!root.selectedName && list.length > 0)
                root.selectedName = (list.find(o => o.enabled) ?? list[0]).name;
        });
    }

    // Snap the dragged output's edges to its neighbors, then shift
    // everything so the layout origin is (0, 0), and commit all positions.
    function commitDrag(draggedName) {
        const positions = JSON.parse(JSON.stringify(root.layoutPositions));
        const dragged = root.enabledOutputs.find(o => o.name === draggedName);
        if (dragged) {
            const size = logicalSize(dragged);
            const p = positions[draggedName];
            const threshold = 40;
            let bestX = null;
            let bestY = null;
            for (const other of root.enabledOutputs) {
                if (other.name === draggedName)
                    continue;
                const op = positions[other.name];
                const os = logicalSize(other);
                // Candidate x positions: flush right-of / left-of / aligned edges.
                for (const candidate of [op.x + os.width, op.x - size.width, op.x, op.x + os.width - size.width]) {
                    if (Math.abs(p.x - candidate) < threshold
                        && (bestX === null || Math.abs(p.x - candidate) < Math.abs(p.x - bestX)))
                        bestX = candidate;
                }
                // Candidate y positions: flush below / above / aligned edges.
                for (const candidate of [op.y + os.height, op.y - size.height, op.y, op.y + os.height - size.height]) {
                    if (Math.abs(p.y - candidate) < threshold
                        && (bestY === null || Math.abs(p.y - candidate) < Math.abs(p.y - bestY)))
                        bestY = candidate;
                }
            }
            if (bestX !== null)
                p.x = bestX;
            if (bestY !== null)
                p.y = bestY;
        }

        // Normalize origin.
        let minX = Infinity;
        let minY = Infinity;
        for (const output of root.enabledOutputs) {
            minX = Math.min(minX, positions[output.name].x);
            minY = Math.min(minY, positions[output.name].y);
        }
        const committed = {};
        for (const output of root.enabledOutputs) {
            committed[output.name] = {
                x: Math.round(positions[output.name].x - minX),
                y: Math.round(positions[output.name].y - minY)
            };
        }
        root.layoutPositions = Object.assign({}, positions, committed);
        Settings.setDisplayPositions(committed);
        refreshTimer.restart();
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
        spacing: 10

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
            text: "not connected to a ShojiWM session — arrangement needs the live compositor; settings edits still save for next boot"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.textFaint
        }

        // ---- arrangement canvas ---------------------------------------
        Rectangle {
            id: canvasFrame

            width: parent.width
            height: 210
            radius: 10
            color: Theme.ground
            border.width: 1
            border.color: Theme.line
            visible: root.enabledOutputs.length > 0

            Item {
                id: canvas

                anchors.fill: parent
                anchors.margins: 18

                // World bounds from the working layout.
                readonly property var world: {
                    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
                    for (const output of root.enabledOutputs) {
                        const p = root.layoutPositions[output.name];
                        if (!p)
                            continue;
                        const s = root.logicalSize(output);
                        minX = Math.min(minX, p.x);
                        minY = Math.min(minY, p.y);
                        maxX = Math.max(maxX, p.x + s.width);
                        maxY = Math.max(maxY, p.y + s.height);
                    }
                    if (minX === Infinity)
                        return { x: 0, y: 0, width: 1, height: 1 };
                    return { x: minX, y: minY, width: maxX - minX, height: maxY - minY };
                }

                readonly property real fit: Math.min(
                    width / Math.max(1, world.width),
                    height / Math.max(1, world.height)) * 0.92

                readonly property real offsetX: (width - world.width * fit) / 2
                readonly property real offsetY: (height - world.height * fit) / 2

                Repeater {
                    model: root.enabledOutputs

                    delegate: Rectangle {
                        id: monitor

                        required property var modelData

                        readonly property string outputName: modelData.name
                        readonly property var pos:
                            root.layoutPositions[outputName] ?? { x: 0, y: 0 }
                        readonly property var size: root.logicalSize(modelData)
                        readonly property bool selected:
                            root.selectedName === outputName

                        x: canvas.offsetX + (pos.x - canvas.world.x) * canvas.fit
                        y: canvas.offsetY + (pos.y - canvas.world.y) * canvas.fit
                        width: size.width * canvas.fit
                        height: size.height * canvas.fit
                        radius: 4
                        color: selected ? Theme.surfaceRaised : Theme.surface
                        border.width: selected ? 2 : 1
                        border.color: selected ? Theme.red : Theme.line
                        z: selected ? 2 : 1

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: monitor.outputName
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                                color: monitor.selected ? Theme.text : Theme.textMuted
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: `${monitor.modelData.resolution.width}x${monitor.modelData.resolution.height}`
                                font.family: Theme.monoFamily
                                font.pixelSize: Theme.fontSize - 4
                                color: Theme.textFaint
                            }
                        }

                        MouseArea {
                            anchors.fill: parent

                            property real pressX: 0
                            property real pressY: 0
                            property var startPos: null

                            onPressed: mouse => {
                                root.selectedName = monitor.outputName;
                                pressX = mouse.x;
                                pressY = mouse.y;
                                startPos = {
                                    x: monitor.pos.x,
                                    y: monitor.pos.y
                                };
                            }
                            onPositionChanged: mouse => {
                                if (!pressed || !startPos)
                                    return;
                                const dx = (mouse.x - pressX) / canvas.fit;
                                const dy = (mouse.y - pressY) / canvas.fit;
                                const next = Object.assign({}, root.layoutPositions);
                                next[monitor.outputName] = {
                                    x: startPos.x + dx,
                                    y: startPos.y + dy
                                };
                                root.layoutPositions = next;
                            }
                            onReleased: {
                                if (!startPos)
                                    return;
                                const moved = Math.abs(monitor.pos.x - startPos.x) > 1
                                    || Math.abs(monitor.pos.y - startPos.y) > 1;
                                startPos = null;
                                if (moved)
                                    root.commitDrag(monitor.outputName);
                            }
                        }
                    }
                }
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
                text: "drag to arrange · click to select"
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fontSize - 4
                color: Theme.textFaint
            }
        }

        // ---- revert guard ----------------------------------------------
        Rectangle {
            width: parent.width
            height: 44
            radius: 8
            visible: Settings.revertPending
            color: Theme.redDim
            border.width: 1
            border.color: Theme.red

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: `keep these display settings? reverting in ${Settings.revertSecondsLeft}s`
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                color: Theme.text
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 64
                height: 28
                radius: 6
                color: keepArea.containsMouse ? Theme.red : Theme.surfaceRaised
                border.width: 1
                border.color: Theme.red

                Text {
                    anchors.centerIn: parent
                    text: "keep"
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.text
                }

                MouseArea {
                    id: keepArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Settings.confirmRisky()
                }
            }
        }

        // ---- selected output details ------------------------------------
        Column {
            width: parent.width
            spacing: 8
            visible: root.selectedOutput !== null

            Text {
                text: root.selectedOutput
                    ? `${root.selectedOutput.name}${root.selectedOutput.model ? "  ·  " + root.selectedOutput.model : ""}`
                    : ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.text
            }

            DropdownPicker {
                width: parent.width
                label: "mode"
                options: {
                    const output = root.selectedOutput;
                    if (!output)
                        return [];
                    const seen = new Set();
                    const list = [{ label: "best (auto)", value: "best" }];
                    const modes = (output.availableModes ?? [])
                        .slice()
                        .sort((a, b) => (b.width * b.height - a.width * a.height)
                            || (b.refreshRate - a.refreshRate));
                    for (const mode of modes) {
                        const key = `${mode.width}x${mode.height}@${Math.round(mode.refreshRate)}`;
                        if (seen.has(key))
                            continue;
                        seen.add(key);
                        list.push({
                            label: `${mode.width}x${mode.height} @ ${Math.round(mode.refreshRate)}Hz`,
                            value: {
                                width: mode.width,
                                height: mode.height,
                                refreshRate: mode.refreshRate
                            }
                        });
                    }
                    return list;
                }
                current: root.selectedOutput
                    ? Settings.get(`displays.${root.selectedOutput.name}.resolution`, "best")
                    : "best"
                onPicked: value => {
                    Settings.beginRisky();
                    Settings.patchDisplay(root.selectedName, { resolution: value });
                    refreshTimer.restart();
                }
            }

            OptionChips {
                width: parent.width
                label: "scale"
                options: [
                    { label: "100%", value: 1.0 },
                    { label: "125%", value: 1.25 },
                    { label: "150%", value: 1.5 },
                    { label: "175%", value: 1.75 },
                    { label: "200%", value: 2.0 }
                ]
                current: root.selectedOutput
                    ? Settings.get(`displays.${root.selectedOutput.name}.scale`, 1.0)
                    : 1.0
                onPicked: value => {
                    Settings.patchDisplay(root.selectedName, { scale: value });
                    refreshTimer.restart();
                }
            }

            DropdownPicker {
                width: parent.width
                label: "mirror"
                options: {
                    const list = [{ label: "off (extend)", value: null }];
                    for (const output of root.enabledOutputs)
                        if (output.name !== root.selectedName)
                            list.push({ label: output.name, value: output.name });
                    return list;
                }
                current: root.selectedOutput
                    ? Settings.get(`displays.${root.selectedOutput.name}.mirror`, null)
                    : null
                onPicked: value => {
                    Settings.beginRisky();
                    Settings.patchDisplay(root.selectedName, { mirror: value });
                    refreshTimer.restart();
                }
            }

            SettingSwitch {
                width: parent.width
                label: "enabled"
                checked: root.selectedOutput
                    ? Settings.get(`displays.${root.selectedOutput.name}.enabled`, true) !== false
                    : true
                onToggled: value => {
                    Settings.beginRisky();
                    Settings.patchDisplay(root.selectedName, { enabled: value });
                    refreshTimer.restart();
                }
            }

            SettingSwitch {
                width: parent.width
                label: "HDR (HDR10 / PQ)"
                hint: "this display's EDID advertises HDR support"
                // Only offered when the display can actually do HDR. Older
                // compositors don't report capability (hdrSupported absent);
                // then the toggle only appears if HDR is already enabled, as
                // an escape hatch to turn it off.
                visible: root.selectedOutput !== null
                    && (root.selectedOutput.hdrSupported === true
                        || Settings.get(`displays.${root.selectedOutput.name}.hdr`, false) === true)
                checked: root.selectedOutput
                    ? Settings.get(`displays.${root.selectedOutput.name}.hdr`, false) === true
                    : false
                onToggled: value => {
                    Settings.beginRisky();
                    Settings.patchDisplay(root.selectedName, { hdr: value });
                    refreshTimer.restart();
                }
            }
        }

        Text {
            visible: Ipc.connected
            width: parent.width
            wrapMode: Text.WordWrap
            text: "changes apply immediately and persist; mode, mirror, enable and HDR changes auto-revert unless kept"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 3
            color: Theme.textFaint
        }
    }

    // Re-read compositor state shortly after a change so the canvas and
    // "running at" data reflect reality.
    Timer {
        id: refreshTimer
        interval: 900
        onTriggered: root.refresh()
    }
}