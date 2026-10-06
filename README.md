# Chrono

All-in-one Clock, Stopwatch, and Countdown Timer plugin for Mochi.

## Features

- Clock: Real-time clock display with seconds, full date, and day progress tracking (available in the dedicated Chrono page).
- Stopwatch: Precise timer with tenth-of-a-second resolution and lap tracking (split and total time).
- Countdown Timer: Customizable countdown timer with intuitive natural text input (e.g. `5m`, `90s`, `1h 30m`, `10:00`), circular progress ring, one-click presets, audio notification, and island activity alerts.
- Dynamic Bubble: Shows remaining time or active stopwatch next to the island pill. Clicking the bubble toggles pause/resume.
- Hub & Desktop Integration: Compact interactive Hub card and desktop widget (Timer and Stopwatch), plus a full-featured Hub page.

## Installation

In `~/.config/mochi/plugins.toml`:

```toml
[plugins.chrono]
source = "path:plugins/chrono"
```

Build and install the plugin:

```sh
mochi plugins install chrono
```

In `~/.config/mochi/config.toml`, add `"chrono"` to `modules`:

```toml
modules = [
    "idle",
    "osd",
    "workspaces",
    "hub",
    "chrono"
]
```

Reload Mochi:

```sh
mochi reload
```

## IPC Commands

Run actions from your terminal with `mochi ipc chrono`:

```sh
# Current status
mochi ipc chrono status

# Switch active mode (clock, stopwatch, timer)
mochi ipc chrono mode timer

# Countdown Timer (supports intuitive duration syntax)
mochi ipc chrono timer_start "10m"       # 10 minutes
mochi ipc chrono timer_start "90s"       # 90 seconds
mochi ipc chrono timer_start "1h 30m"    # 1 hour 30 minutes
mochi ipc chrono timer_start "05:00"     # 5 minutes
mochi ipc chrono timer_pause             # Pause or resume
mochi ipc chrono timer_add "5m"          # Add 5 minutes
mochi ipc chrono timer_stop              # Stop and reset

# Stopwatch
mochi ipc chrono stopwatch_start         # Start stopwatch
mochi ipc chrono stopwatch_lap           # Record a lap
mochi ipc chrono stopwatch_pause         # Pause or resume
mochi ipc chrono stopwatch_reset         # Reset stopwatch
```

## Configuration

In `~/.config/mochi/config.toml`:

```toml
[module.chrono]
# Default timer duration in minutes
default_timer_minutes = 5

# Clock time format
clock_format = "%H:%M:%S"

# Island bubble position (CenterRight, CenterLeft, Right, Left)
area = "CenterRight"

# Show bubble for timer or stopwatch
timer_bubble = true
stopwatch_bubble = true

# Sound alert when timer expires
sound = true
```
