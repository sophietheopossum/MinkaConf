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
- **displays** — connected outputs (via `debug.geometry`) with the mode and
  the scale the compositor is *currently running*, plus 100–200% scale
  presets per output.

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