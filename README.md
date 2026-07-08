# MinkaConf

The Minka settings application (Quickshell/QML, Eternal Darkness theme).

## How settings flow

Single source of truth: `~/.config/shojiwm/src/minka-settings.json`.

- The ShojiWM config (`index.tsx`) imports it at boot (tsx resolves JSON
  imports) and feeds `COMPOSITOR.input.configure` and the per-output
  `scale` in `COMPOSITOR.output.configure`.
- MinkaConf edits the file **and** sends the whole object over the IPC
  socket (`settings.apply`), which swaps the active settings and re-runs the
  input/output factories — changes land immediately, no config reload.
- Outside a ShojiWM session the IPC dot shows offline; edits are still
  saved and apply on the next session start.

## Current pages

- **input** — pointer speed (libinput accel −1…1), accel profile
  (adaptive/flat), natural scrolling (mouse and touchpad separately),
  tap-to-click, disable-while-typing, touchpad scroll speed.
- **displays** — visual arrangement, KDE-style: drag monitor rectangles on
  the canvas (edge-snapped, origin-normalized, committed on release), click
  to select, then per-output mode (from the compositor's `availableModes`),
  scale presets, mirror source, enable/disable, and the HDR10 opt-in.
  Risky changes (mode/mirror/enable/HDR) arm a 12s auto-revert unless
  confirmed, so a bad mode can't strand the session. Live data comes over
  IPC (`debug.geometry`); all writes go through `settings.apply` +
  `minka-settings.json` — deliberately not wlr-output-management, so the
  settings file stays the single source of truth (the protocol can be added
  compositor-side later for third-party tools; `wayland-protocols-wlr` is
  already a dependency).

## Running

```sh
qs -p /home/seirra/Documents/src/MinkaDE/MinkaConf
```

A desktop entry (`MinkaConf`) is installed at
`~/.local/share/applications/MinkaConf.desktop`, so the MinkaShell launcher
finds it.

## Backlog

- Wallpaper switching (moved here from the shell, per scope decision).
- Keyboard settings (layout, repeat rate — the config values exist).
- Theme editing once the shared theme.json (M4) lands.