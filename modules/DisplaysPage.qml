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

    // Layout maths (drag, snapping, collision, world bounds) applies only to
    // outputs that actually occupy desktop space.
    readonly property var enabledOutputs:
        outputs.filter(o => o.enabled && o.resolution)

    // What the canvas DRAWS. Disabled outputs stay on the canvas, greyed out,
    // because the canvas is the only way to select an output — filtering them
    // out made disabling a display a one-way door: the tile vanished, so it
    // could never be clicked again to re-enable it. They are excluded from
    // enabledOutputs above, so they still contribute nothing to positioning.
    readonly property var canvasOutputs:
        outputs.filter(o => o.resolution)

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

    // Operator preference: snap dragged displays to their neighbours, centre them
    // on the perpendicular axis, and refuse overlaps. ON by default — a monitor
    // layout is nearly always meant to be flush and aligned, and hand-dragging
    // to whole-pixel edges on a scaled-down canvas is fiddly. Turning it off
    // restores free positioning for genuinely irregular arrangements.
    readonly property bool snapEnabled: Settings.get("minkaconf.snapDisplays", true)

    // Do two rectangles overlap? Touching edges do NOT count — flush is the goal.
    function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh) {
        return ax < bx + bw && bx < ax + aw && ay < by + bh && by < ay + ah;
    }

    // Push `name` out of every rectangle it intersects, along whichever axis needs
    // the least movement, until nothing overlaps. Bounded: a pathological layout
    // must not spin the UI thread, and stopping early leaves a visible overlap
    // rather than a hang -- the honest failure.
    function resolveOverlaps(positions, name) {
        const dragged = root.enabledOutputs.find(o => o.name === name);
        if (!dragged)
            return;
        const size = logicalSize(dragged);
        for (let pass = 0; pass < 16; pass++) {
            let moved = false;
            for (const other of root.enabledOutputs) {
                if (other.name === name)
                    continue;
                const op = positions[other.name];
                const os = logicalSize(other);
                const p = positions[name];
                if (!rectsOverlap(p.x, p.y, size.width, size.height, op.x, op.y, os.width, os.height))
                    continue;
                // Penetration depth on each side; move by the smallest.
                const pushRight = (op.x + os.width) - p.x;
                const pushLeft = (p.x + size.width) - op.x;
                const pushDown = (op.y + os.height) - p.y;
                const pushUp = (p.y + size.height) - op.y;
                const best = Math.min(pushRight, pushLeft, pushDown, pushUp);
                if (best === pushRight) p.x += pushRight;
                else if (best === pushLeft) p.x -= pushLeft;
                else if (best === pushDown) p.y += pushDown;
                else p.y -= pushUp;
                moved = true;
            }
            if (!moved)
                break;
        }
    }

    // Snap the dragged output's edges to its neighbors, then shift
    // everything so the layout origin is (0, 0), and commit all positions.
    function commitDrag(draggedName) {
        const positions = JSON.parse(JSON.stringify(root.layoutPositions));
        const dragged = root.enabledOutputs.find(o => o.name === draggedName);
        if (dragged && root.snapEnabled) {
            const size = logicalSize(dragged);
            const p = positions[draggedName];
            // Generous, and proportional to the display: the canvas is scaled to fit,
            // so a fixed 40 logical px was only a pixel or two of mouse travel and
            // almost never caught. Overlaps are resolved below, so a wide snap zone
            // costs nothing.
            const threshold = Math.max(150, Math.min(size.width, size.height) * 0.25);
            let bestX = null, bestY = null;
            let bestXDist = Infinity, bestYDist = Infinity;
            // The neighbour a FLUSH (side-by-side / stacked) snap landed against.
            // Only a flush snap implies adjacency, and only adjacency implies the
            // displays should be centred against each other on the other axis.
            let flushXNeighbour = null, flushYNeighbour = null;
            for (const other of root.enabledOutputs) {
                if (other.name === draggedName)
                    continue;
                const op = positions[other.name];
                const os = logicalSize(other);
                // Flush candidates first (adjacency), then pure edge alignments.
                const xFlush = [op.x + os.width, op.x - size.width];
                const xAlign = [op.x, op.x + os.width - size.width];
                for (const candidate of xFlush.concat(xAlign)) {
                    const dist = Math.abs(p.x - candidate);
                    if (dist < threshold && dist < bestXDist) {
                        bestX = candidate;
                        bestXDist = dist;
                        flushXNeighbour = xFlush.indexOf(candidate) >= 0 ? other : null;
                    }
                }
                const yFlush = [op.y + os.height, op.y - size.height];
                const yAlign = [op.y, op.y + os.height - size.height];
                for (const candidate of yFlush.concat(yAlign)) {
                    const dist = Math.abs(p.y - candidate);
                    if (dist < threshold && dist < bestYDist) {
                        bestY = candidate;
                        bestYDist = dist;
                        flushYNeighbour = yFlush.indexOf(candidate) >= 0 ? other : null;
                    }
                }
            }
            if (bestX !== null)
                p.x = bestX;
            if (bestY !== null)
                p.y = bestY;

            // Centre on the perpendicular axis. Side-by-side displays centre
            // vertically, stacked ones centre horizontally -- which is what people
            // mean by "arranged", and what you cannot hit by hand on a scaled canvas.
            // Whichever axis snapped flush MORE tightly wins, so a corner drag
            // resolves to one intent rather than fighting itself.
            const preferX = flushXNeighbour && (!flushYNeighbour || bestXDist <= bestYDist);
            const preferY = flushYNeighbour && !preferX;
            if (preferX) {
                const os = logicalSize(flushXNeighbour);
                p.y = positions[flushXNeighbour.name].y + (os.height - size.height) / 2;
            } else if (preferY) {
                const os = logicalSize(flushYNeighbour);
                p.x = positions[flushYNeighbour.name].x + (os.width - size.width) / 2;
            }

            resolveOverlaps(positions, draggedName);
        } else if (dragged) {
            // Snapping off: still refuse overlaps. Two displays occupying the same
            // logical space is not a layout choice, it is a broken configuration.
            resolveOverlaps(positions, draggedName);
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
                    model: root.canvasOutputs

                    delegate: Rectangle {
                        id: monitor

                        required property var modelData

                        readonly property string outputName: modelData.name
                        readonly property bool outputEnabled: modelData.enabled === true
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
                        // Disabled: dimmed and behind the live tiles, but still
                        // present and still clickable — selecting it is the only
                        // route back to switching it on.
                        opacity: outputEnabled ? 1.0 : 0.45
                        z: selected ? 2 : (outputEnabled ? 1 : 0)

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

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: !monitor.outputEnabled
                                text: "disabled"
                                font.family: Theme.fontFamily
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
                text: root.snapEnabled ? "drag to arrange · snapping on · click to select"
                                       : "drag to arrange · free positioning · click to select"
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fontSize - 4
                color: Theme.textFaint
            }
        }

        // Governs commitDrag: edge snapping, perpendicular centring, and the
        // overlap refusal. Sits directly under the canvas it affects.
        SettingSwitch {
            width: parent.width
            label: "snap displays"
            hint: "snap edges together, centre on the other axis, and never overlap"
            checked: root.snapEnabled
            onToggled: value => Settings.set("minkaconf.snapDisplays", value)
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