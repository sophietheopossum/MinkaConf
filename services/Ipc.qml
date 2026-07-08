pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Minimal NDJSON client for ShojiWM's IPC socket — request/response only
// (MinkaConf consumes no broadcasts). Same non-blocking + auto-reconnect
// rules as MinkaShell's ShojiIpc.
Singleton {
    id: root

    readonly property string socketPath: {
        const runtimeDir = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp";
        const display = Quickshell.env("WAYLAND_DISPLAY") || "wayland-0";
        return `${runtimeDir}/shojiwm-${display}.sock`;
    }

    readonly property bool connected: socket.connected

    property int _nextId: 1
    property var _pending: ({})

    function request(method, params, onResult) {
        if (!socket.connected) {
            if (onResult)
                onResult(undefined, "not connected to ShojiWM");
            return;
        }
        const id = _nextId++;
        if (onResult)
            _pending[id] = onResult;
        const message = params === undefined
            ? { id, method }
            : { id, method, params };
        socket.write(JSON.stringify(message) + "\n");
        socket.flush();
    }

    Socket {
        id: socket
        path: root.socketPath
        connected: true

        parser: SplitParser {
            onRead: line => {
                const trimmed = line.trim();
                if (trimmed.length === 0)
                    return;
                let message;
                try {
                    message = JSON.parse(trimmed);
                } catch (e) {
                    return;
                }
                if (message.id === undefined)
                    return; // broadcast; not our concern
                const callback = root._pending[message.id];
                if (callback) {
                    delete root._pending[message.id];
                    callback(message.result, message.error);
                }
            }
        }

        onConnectedChanged: {
            if (!connected)
                root._pending = {};
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: !socket.connected
        onTriggered: socket.connected = true
    }
}