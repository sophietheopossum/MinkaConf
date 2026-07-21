pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The settings store. Single source of truth is
// ~/.config/minka-settings.json
// the ShojiWM config imports it
// at boot, and `settings.apply` over IPC swaps it live at runtime. Every
// mutation here does both: persist to the file AND apply immediately.
//
// Risky display changes (mode / enable / mirror / HDR) go through the
// revert guard: callers beginRisky() first, and unless confirmRisky() is
// called within the countdown the previous settings are restored — so a
// black screen fixes itself (kscreen-style).
Singleton {
    id: root

    readonly property string settingsPath:
        Quickshell.env("HOME") +
        "/.config/minka-settings.json"

    property var data: ({})
    readonly property bool ready: data && data.input !== undefined

    // False when the last IPC apply failed (e.g. not inside a ShojiWM
    // session). The file is still written, so changes land next boot.
    property bool liveApplied: true

    function reload() {
        try {
            root.data = JSON.parse(file.text());
        } catch (e) {
            console.log("minkaconf: cannot parse", settingsPath, e);
        }
    }

    // Read a nested value: get("input.touchpad.naturalScroll", false)
    function get(path, fallback) {
        let node = root.data;
        for (const part of path.split(".")) {
            if (node === undefined || node === null)
                return fallback;
            node = node[part];
        }
        return node === undefined ? fallback : node;
    }

    // Write a nested value, persist, and live-apply.
    function set(path, value) {
        const parts = path.split(".");
        const next = JSON.parse(JSON.stringify(root.data));
        let node = next;
        for (let i = 0; i < parts.length - 1; i++) {
            if (typeof node[parts[i]] !== "object" || node[parts[i]] === null)
                node[parts[i]] = {};
            node = node[parts[i]];
        }
        node[parts[parts.length - 1]] = value;
        root.data = next;
        save();
        apply();
    }

    // Merge a patch object into one display's entry (one save+apply).
    function patchDisplay(name, patch) {
        const next = JSON.parse(JSON.stringify(root.data));
        if (typeof next.displays !== "object" || next.displays === null)
            next.displays = {};
        next.displays[name] = Object.assign({}, next.displays[name] || {}, patch);
        root.data = next;
        save();
        apply();
    }

    // Write positions for many displays at once (drag commits move every
    // output after origin normalization).
    function setDisplayPositions(positions) {
        const next = JSON.parse(JSON.stringify(root.data));
        if (typeof next.displays !== "object" || next.displays === null)
            next.displays = {};
        for (const name of Object.keys(positions)) {
            next.displays[name] = Object.assign({}, next.displays[name] || {}, {
                position: positions[name]
            });
        }
        root.data = next;
        save();
        apply();
    }

    function save() {
        file.setText(JSON.stringify(root.data, null, 2) + "\n");
    }

    function apply() {
        Ipc.request("settings.apply", root.data, (result, error) => {
            root.liveApplied = !error && result && result.ok === true;
        });
    }

    // ---- revert guard -------------------------------------------------
    property var _revertSnapshot: null
    readonly property bool revertPending: _revertSnapshot !== null
    property int revertSecondsLeft: 0

    function beginRisky() {
        if (_revertSnapshot === null)
            _revertSnapshot = JSON.parse(JSON.stringify(root.data));
        revertSecondsLeft = 12;
        revertTimer.restart();
    }

    function confirmRisky() {
        _revertSnapshot = null;
        revertTimer.stop();
    }

    function revertRisky() {
        if (_revertSnapshot === null)
            return;
        root.data = _revertSnapshot;
        _revertSnapshot = null;
        revertTimer.stop();
        save();
        apply();
    }

    Timer {
        id: revertTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.revertSecondsLeft -= 1;
            if (root.revertSecondsLeft <= 0)
                root.revertRisky();
        }
    }

    FileView {
        id: file
        path: root.settingsPath
        blockLoading: true
        onLoaded: root.reload()
    }

    Component.onCompleted: reload()
}