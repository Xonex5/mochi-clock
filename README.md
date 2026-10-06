# Chrono

All-in-one clock, stopwatch, and timer plugin for Mochi.

## Features

- Clock: Real-time clock display with seconds, full date, day progress tracking, and selectable world clocks (Los Angeles, New York, London, Paris, Dubai, Singapore, Tokyo, Sydney).
- Stopwatch: Precise timer with tenth-of-a-second resolution, split laps, run history, and clipboard export via `wl-copy`.
- Multi-timers: Simultaneous countdown timers with optional labels, progress indicators, and individual controls.
- Natural duration input: Intuitive syntax such as `5m`, `90s`, `1h 30m`, `10:00`, or `15m Tea`.
- Alarm volume control: Adjustable volume from 0 to 100%, preview button, and custom sound file support.
- Media sync: Automatically pauses active media playback when a timer completes.
- Launcher provider: Quick timer creation and stopwatch controls with `:t <duration> [label]`.
- Global keybindings: Control stopwatch in any application or game via Hyprland shortcuts.
- Dynamic Island: Compact bubble showing progress and time, expanding into full controls on click.

## Global keybindings

Added to `~/.config/hypr/config/bindings.lua`:

- `SUPER + K`: Pause or resume stopwatch
- `SUPER + SHIFT + K`: Record a lap
- `SUPER + CTRL + R`: Reset stopwatch and save run to history

## Launcher commands

Type `:t` into Mochi launcher:

- `:t 10m Pizza`: Starts a 10-minute timer labeled Pizza
- `:t 25m`: Starts a 25-minute timer
- `:t sw`: Toggles stopwatch

## IPC commands

Run actions with `mochi ipc chrono`:

```sh
# Status
mochi ipc chrono status

# Mode switch (clock, stopwatch, timer)
mochi ipc chrono mode timer

# Multi-timers
mochi ipc chrono timer_start "10m" "Pizza"
mochi ipc chrono timer_start "25m"
mochi ipc chrono timer_pause
mochi ipc chrono timer_pause "t1"
mochi ipc chrono timer_add "5m"
mochi ipc chrono timer_stop
mochi ipc chrono timer_stop "t1"

# Alarm volume (0 to 100)
mochi ipc chrono timer_volume 75
mochi ipc chrono timer_test_sound

# Stopwatch
mochi ipc chrono stopwatch_start
mochi ipc chrono stopwatch_pause
mochi ipc chrono stopwatch_lap
mochi ipc chrono stopwatch_export
mochi ipc chrono stopwatch_reset
```

## Configuration

In `~/.config/mochi/config.toml`:

```toml
[module.chrono]
default_timer_minutes = 5
clock_format = "%H:%M:%S"
clock_24h = true
area = "CenterRight"
timer_bubble = true
stopwatch_bubble = true
sound = true
alarm_volume = 80
pause_media = true
# sound_file = "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
```
