# Media Control for Omarchy

[English](README.md) | [简体中文](README.zh-CN.md)

A GNOME-style now-playing widget for the [Omarchy](https://omarchy.org) bar, with full VLC-style keyboard shortcuts and extended playback controls.

A single play/pause glyph appears in the bar only while media is playing. Click it (or press your shortcut) and a panel slides out with the app that is playing, the cover art, track details, transport controls, repeat/shuffle toggles, and a seek bar — very much like the media section in GNOME's quick settings.

![Media Control panel showing VLC media player](docs/screenshot.png)

## Features

- **Unobtrusive indicator** – a ▶ / ⏸ glyph that shows up only when a player has a track loaded and disappears when nothing is playing. Optionally hide it while paused.
- **GNOME-style panel** – app icon and name, cover art, title / artist / album, seek bar, and transport controls: ⏮ ⏯ ⏭ 🔁 🔀.
- **Repeat & Shuffle modes** – 3-state loop cycling (Off / Playlist / Track) and random playback toggle, with dynamic glyphs and visual active highlights.
- **Full keyboard control (VLC style)** – focus-grabbing layer-shell panel with standard VLC media player shortcuts: Space to play/pause, `s` to stop, `l` for loop, `r` for shuffle, `m` for mute, arrows for seeking/skipping, and Ctrl+Up/Down for volume.
- **Seek bar** – elapsed and total time, draggable when the player supports seeking (shown only when the player reports a track length).
- **Multiple players** – when more than one MPRIS source is active (e.g. browser + Spotify + VLC), the panel lists them and lets you switch the active source using mouse or Up/Down keys.
- **Multi-monitor awareness** – opens seamlessly on whichever monitor currently has keyboard/cursor focus.
- **Robust MPRIS integration** – integrates with Omarchy's built-in `omarchy.media` service while seamlessly falling back directly to DBus MPRIS services (`Quickshell.Services.Mpris`).
- **Tooltips & feedback** – native bar tooltips on all buttons indicating action or current state (e.g. `循环: 列表循环`, `随机播放: 开启`).
- **IPC surface** – bind keys or script it: `omarchy-shell debba.media-control toggle|open|close|playPause|next|previous|repeat|shuffle|stop`.
- **Native look** – built with Omarchy's own UI components, following your theme, bar position, accent colors, and font.

Works with anything that speaks MPRIS: Firefox / Zen / Chromium tabs, Spotify, mpv (with `mpv-mpris`), VLC, Rhythmbox, and so on. Under the hood it reuses Omarchy's built-in `omarchy.media` service when present, ensuring media keys and the OSD stay in sync.

## Requirements

- Omarchy 4.x (Quickshell-based shell)

## Install

```bash
git clone https://github.com/qiongyus/omarchy-media-control ~/Projects/omarchy-media-control
~/Projects/omarchy-media-control/install.sh
```

The installer symlinks the repository into `~/.config/omarchy/plugins/debba.media-control` and enables the widget in the right section of the bar. Pass a section name to put it elsewhere:

```bash
~/Projects/omarchy-media-control/install.sh center
```

Because the plugin is a symlink, `git pull` is all it takes to update.

If you had Omarchy's stock `omarchy.media` widget on the bar you may want to remove it to avoid two indicators:

```bash
omarchy plugin disable omarchy.media
```

## Usage

### Mouse Actions

| Action                          | Result                         |
|---------------------------------|--------------------------------|
| Left click on indicator         | Open / close the panel         |
| Right click on indicator        | Play / pause                   |
| Middle click on indicator       | Next track                     |
| Mouse wheel on indicator        | Previous / next track          |
| Click Repeat button             | Cycle loop mode (Off → Playlist → Track) |
| Click Shuffle button            | Toggle random playback (On / Off) |
| Drag the seek bar               | Seek (if the player allows it) |
| Click a source in the list      | Make that player the active one |

### Keyboard Shortcuts (when panel is open)

Matches standard VLC media player shortcuts:

| Key | Action |
|-----|--------|
| `Space` / `Enter` | Play / Pause |
| `s` | Stop |
| `n` / `Right` | Next track |
| `p` / `Left` | Previous track |
| `l` | Cycle Repeat mode (Off → Playlist → Track) |
| `r` | Toggle Shuffle / Random playback |
| `m` | Mute / Unmute |
| `Ctrl + Up` / `Ctrl + Down` | Volume up / down (±5%) |
| `Shift + Left` / `Shift + Right` | Extra-short jump (±3 seconds) |
| `Alt + Left` / `Alt + Right` | Short jump (±10 seconds) |
| `Ctrl + Left` / `Ctrl + Right` | Medium jump (±60 seconds) |
| `Up` / `Down` | Switch active player source |
| `Esc` / `Ctrl + Q` | Close panel |

### Global Hotkey

Add to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + M", "Media panel", "omarchy-shell debba.media-control toggle")
```

### IPC Commands

Control playback or panel visibility from the command line or custom keybindings:

```bash
# Toggle / Open / Close the panel
omarchy-shell debba.media-control toggle
omarchy-shell debba.media-control open
omarchy-shell debba.media-control close

# Playback controls
omarchy-shell debba.media-control playPause
omarchy-shell debba.media-control next
omarchy-shell debba.media-control previous
omarchy-shell debba.media-control stop

# Mode toggles
omarchy-shell debba.media-control repeat    # Cycle loop modes
omarchy-shell debba.media-control shuffle   # Toggle shuffle on/off
```

## Settings

Change settings with `omarchy bar set` or directly in `~/.config/omarchy/shell.json`:

```bash
omarchy bar set debba.media-control hideWhenPaused true
omarchy bar set debba.media-control panelWidth 380
```

| Key              | Type    | Default | Description                                                        |
|------------------|---------|---------|--------------------------------------------------------------------|
| `hideWhenPaused` | boolean | `false` | Hide the indicator while playback is paused (it stays while the panel is open) |
| `panelWidth`     | number  | `360`   | Width of the panel in pixels                                        |

## Uninstall

```bash
~/Projects/omarchy-media-control/uninstall.sh
```

## Notes

- Browsers only expose track length for some sites, so the seek bar may not appear for every tab.
- `mpv-mpris` registers two bus names for a single mpv instance, so mpv shows up twice in the source list. That is an mpv quirk, not a bug in the widget.

## Acknowledgements & License

Forked and enhanced from [debba/omarchy-media-control](https://github.com/debba/omarchy-media-control) by Andrea Debernardi.

MIT — see [LICENSE](LICENSE).
