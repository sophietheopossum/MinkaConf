pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The settings store. Single source of truth is
// ~/.config/shojiwm/src/minka-settings.json — the ShojiWM config imports it
// at boot, and `settings.apply` over IPC swaps it live at runtime. Every
// mutation here does both: persist to the file AND apply immediately.
Singleton {
    id: root

    readonly property string settingsPath:
        Quickshell.env("HOME") + "/.config/shojiwm/src/minka-settings.json"

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

    function save() {
        file.setText(JSON.stringify(root.data, null, 2) + "\n");
    }

    function apply() {
        Ipc.request("settings.apply", root.data, (result, error) => {
            root.liveApplied = !error && result && result.ok === true;
        });
    }

    FileView {
        id: file
        path: root.settingsPath
        blockLoading: true
        onLoaded: root.reload()
    }

    Component.onCompleted: reload()
}