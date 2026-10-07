//! Chrono Mochi plugin: All-in-one Clock, Stopwatch, and Countdown Timer.

use std::collections::HashMap;
use std::process::ExitCode;
use std::time::Duration;
use tokio::time::Instant;

use mochi_sdk::{
    ActivitySpec, Area, BubbleId, BubbleSpec, ModuleCommand, ModuleCtx, ModuleEvent, Priority,
    Value, json,
};
use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
#[serde(default, deny_unknown_fields)]
struct Settings {
    default_timer_minutes: u64,
    clock_format: String,
    clock_24h: bool,
    area: Area,
    timer_bubble: bool,
    stopwatch_bubble: bool,
    sound: bool,
    alarm_volume: u32,
    sound_file: Option<String>,
    pause_media: bool,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            default_timer_minutes: 5,
            clock_format: "%H:%M:%S".to_string(),
            clock_24h: true,
            area: Area::CenterRight,
            timer_bubble: true,
            stopwatch_bubble: true,
            sound: true,
            alarm_volume: 80,
            sound_file: None,
            pause_media: true,
        }
    }
}

#[derive(Debug, Clone, Serialize)]
struct Lap {
    index: usize,
    split_ms: u64,
    total_ms: u64,
    formatted_split: String,
    formatted_total: String,
}

#[derive(Debug, Clone, Serialize)]
struct StopwatchSession {
    index: usize,
    formatted_total: String,
    total_ms: u64,
    lap_count: usize,
    timestamp: String,
}

#[derive(Debug)]
struct Stopwatch {
    running: bool,
    paused: bool,
    start_instant: Option<Instant>,
    accumulated: Duration,
    last_lap_total: Duration,
    laps: Vec<Lap>,
    history: Vec<StopwatchSession>,
}

impl Stopwatch {
    fn new() -> Self {
        Self {
            running: false,
            paused: false,
            start_instant: None,
            accumulated: Duration::ZERO,
            last_lap_total: Duration::ZERO,
            laps: Vec::new(),
            history: Vec::new(),
        }
    }

    fn elapsed(&self) -> Duration {
        if self.running && !self.paused {
            self.accumulated + self.start_instant.map(|i| i.elapsed()).unwrap_or_default()
        } else {
            self.accumulated
        }
    }

    fn start(&mut self) {
        if !self.running {
            self.running = true;
            self.paused = false;
            self.accumulated = Duration::ZERO;
            self.last_lap_total = Duration::ZERO;
            self.laps.clear();
            self.start_instant = Some(Instant::now());
        } else if self.paused {
            self.paused = false;
            self.start_instant = Some(Instant::now());
        }
    }

    fn pause(&mut self) {
        if self.running && !self.paused {
            if let Some(i) = self.start_instant.take() {
                self.accumulated += i.elapsed();
            }
            self.paused = true;
        }
    }

    fn resume(&mut self) {
        if self.running && self.paused {
            self.paused = false;
            self.start_instant = Some(Instant::now());
        }
    }

    fn toggle_pause(&mut self) {
        if !self.running {
            self.start();
        } else if self.paused {
            self.resume();
        } else {
            self.pause();
        }
    }

    fn reset(&mut self, timestamp: &str) {
        let total = self.elapsed();
        if total.as_millis() > 0 {
            let session_idx = self.history.len() + 1;
            self.history.insert(
                0,
                StopwatchSession {
                    index: session_idx,
                    formatted_total: format_tenths(total),
                    total_ms: total.as_millis() as u64,
                    lap_count: self.laps.len(),
                    timestamp: timestamp.to_string(),
                },
            );
            if self.history.len() > 5 {
                self.history.truncate(5);
            }
        }
        self.running = false;
        self.paused = false;
        self.start_instant = None;
        self.accumulated = Duration::ZERO;
        self.last_lap_total = Duration::ZERO;
        self.laps.clear();
    }

    fn lap(&mut self) {
        if self.running {
            let total = self.elapsed();
            let split = total.saturating_sub(self.last_lap_total);
            self.last_lap_total = total;
            let index = self.laps.len() + 1;
            self.laps.push(Lap {
                index,
                split_ms: split.as_millis() as u64,
                total_ms: total.as_millis() as u64,
                formatted_split: format_tenths(split),
                formatted_total: format_tenths(total),
            });
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ActiveTimer {
    id: String,
    label: String,
    total_secs: u64,
    left_secs: u64,
    running: bool,
    paused: bool,
    formatted: String,
    progress: f64,
    #[serde(skip)]
    target_instant: Option<Instant>,
}

impl ActiveTimer {
    fn new(id: String, label: String, duration: Duration) -> Self {
        let total_secs = duration.as_secs().max(1);
        Self {
            id,
            label,
            total_secs,
            left_secs: total_secs,
            running: true,
            paused: false,
            formatted: format_timer(duration),
            progress: 1.0,
            target_instant: Some(Instant::now() + duration),
        }
    }

    fn pause(&mut self) {
        if self.running && !self.paused {
            if let Some(target) = self.target_instant.take() {
                self.left_secs = target
                    .saturating_duration_since(Instant::now())
                    .as_secs_f64()
                    .ceil() as u64;
            }
            self.paused = true;
            self.formatted = format_timer(Duration::from_secs(self.left_secs));
        }
    }

    fn resume(&mut self) {
        if self.running && self.paused {
            self.paused = false;
            self.target_instant = Some(Instant::now() + Duration::from_secs(self.left_secs));
        }
    }

    fn toggle_pause(&mut self) {
        if self.paused {
            self.resume();
        } else {
            self.pause();
        }
    }

    fn add(&mut self, extra: Duration) {
        let extra_secs = extra.as_secs();
        self.total_secs += extra_secs;
        self.left_secs += extra_secs;
        if !self.paused {
            if let Some(target) = self.target_instant {
                self.target_instant = Some(target + extra);
            } else {
                self.target_instant = Some(Instant::now() + Duration::from_secs(self.left_secs));
            }
        }
        self.formatted = format_timer(Duration::from_secs(self.left_secs));
        let total = self.total_secs.max(1) as f64;
        self.progress = (self.left_secs as f64 / total).clamp(0.0, 1.0);
    }

    fn tick(&mut self, now: Instant) -> bool {
        if self.running && !self.paused {
            if let Some(target) = self.target_instant {
                if now >= target {
                    self.running = false;
                    self.left_secs = 0;
                    self.target_instant = None;
                    self.formatted = "00:00".to_string();
                    self.progress = 0.0;
                    return true;
                } else {
                    let remaining = target.duration_since(now);
                    self.left_secs = remaining.as_secs_f64().ceil() as u64;
                    self.formatted = format_timer(remaining);
                    let total = self.total_secs.max(1) as f64;
                    self.progress = (self.left_secs as f64 / total).clamp(0.0, 1.0);
                }
            }
        }
        false
    }
}

struct ChronoPlugin {
    settings: Settings,
    mode: String,
    stopwatch: Stopwatch,
    timers: Vec<ActiveTimer>,
    next_timer_id: u64,
    alarm_volume: u32,
    media_playing: bool,
    active_bubble: Option<BubbleId>,
    selected_cities: Vec<String>,
}

impl ChronoPlugin {
    fn primary_timer(&self) -> Option<&ActiveTimer> {
        self.timers
            .iter()
            .filter(|t| t.running || t.paused)
            .min_by_key(|t| t.left_secs)
    }

    fn primary_timer_mut(&mut self) -> Option<&mut ActiveTimer> {
        self.timers
            .iter_mut()
            .filter(|t| t.running || t.paused)
            .min_by_key(|t| t.left_secs)
    }
}

fn main() -> ExitCode {
    mochi_sdk::run(run)
}

async fn run(mut ctx: ModuleCtx) -> Result<(), mochi_sdk::Error> {
    let settings: Settings = ctx.settings()?;
    let init_volume = settings.alarm_volume;
    let mut plugin = ChronoPlugin {
        settings,
        mode: "timer".to_string(),
        stopwatch: Stopwatch::new(),
        timers: Vec::new(),
        next_timer_id: 0,
        alarm_volume: init_volume,
        media_playing: false,
        active_bubble: None,
        selected_cities: vec!["paris".into(), "tokyo".into(), "new_york".into()],
    };

    plugin.publish(&ctx);

    loop {
        let tick_duration = if plugin.stopwatch.running && !plugin.stopwatch.paused {
            Duration::from_millis(100)
        } else {
            Duration::from_millis(500)
        };

        tokio::select! {
            event = ctx.next_event() => match event {
                None => return Ok(()),
                Some(ModuleEvent::Command(command)) => plugin.handle_command(&ctx, command),
                Some(ModuleEvent::BubbleClicked(_)) => plugin.handle_bubble_click(&ctx),
                Some(ModuleEvent::State { module, state }) if module == "media" => {
                    plugin.media_playing = state["status"] == "playing";
                }
                Some(_) => {}
            },
            _ = tokio::time::sleep(tick_duration) => {
                plugin.tick(&ctx);
            }
        }
    }
}

impl ChronoPlugin {
    fn handle_command(&mut self, ctx: &ModuleCtx, command: ModuleCommand) {
        let action = command.action.clone();
        match action.as_str() {
            "status" => {
                let (time_str, date_str, _, _, _, _) =
                    current_local_time(&self.settings.clock_format);
                let sw_desc = if self.stopwatch.running {
                    let state = if self.stopwatch.paused {
                        "paused"
                    } else {
                        "running"
                    };
                    format!(
                        "{} ({state}, {} laps)",
                        format_tenths(self.stopwatch.elapsed()),
                        self.stopwatch.laps.len()
                    )
                } else {
                    "idle".to_string()
                };
                let timer_desc = if !self.timers.is_empty() {
                    let details: Vec<String> = self
                        .timers
                        .iter()
                        .map(|t| {
                            let label = if t.label.is_empty() {
                                "Timer".to_string()
                            } else {
                                t.label.clone()
                            };
                            let state = if t.paused { "paused" } else { "running" };
                            format!("{label}: {} left ({state})", t.formatted)
                        })
                        .collect();
                    details.join("; ")
                } else {
                    "idle".to_string()
                };
                command.answer(Ok(format!(
                    "Clock: {time_str} ({date_str})\nStopwatch: {sw_desc}\nTimers: {timer_desc}\nAlarm volume: {}%\nActive mode: {}",
                    self.alarm_volume, self.mode
                )));
            }
            "mode" => {
                if let Some(new_mode) = command.args.str("mode") {
                    self.mode = new_mode.to_string();
                    self.publish(ctx);
                    command.reply(Ok(()));
                } else {
                    command.reply(Err("mode required (clock, stopwatch, timer)".into()));
                }
            }
            "timer_start" => {
                let input_str = command.args.str("duration").map(|s| s.to_string());
                let explicit_label = command.args.str("label").map(|s| s.to_string());

                let (duration, parsed_label) = if let Some(ref s) = input_str {
                    match parse_duration_and_label(s) {
                        Some((d, l)) => (d, l),
                        None => {
                            command.reply(Err(format!(
                                "invalid duration '{s}': use e.g. 5m, 90s, 1h 30m, 10:00"
                            )));
                            return;
                        }
                    }
                } else {
                    (
                        Duration::from_secs(self.settings.default_timer_minutes * 60),
                        None,
                    )
                };

                let final_label = explicit_label.or(parsed_label).unwrap_or_default();
                self.next_timer_id += 1;
                let id = format!("t{}", self.next_timer_id);
                let new_timer = ActiveTimer::new(id, final_label, duration);
                self.timers.push(new_timer);
                self.mode = "timer".to_string();
                self.sync_bubble(ctx);
                self.publish(ctx);
                command.reply(Ok(()));
            }
            "timer_pause" => {
                let id_opt = command.args.str("id");
                if let Some(id) = id_opt {
                    if let Some(t) = self.timers.iter_mut().find(|t| t.id == id) {
                        t.toggle_pause();
                    }
                } else if let Some(t) = self.primary_timer_mut() {
                    t.toggle_pause();
                }
                self.sync_bubble(ctx);
                self.publish(ctx);
                command.reply(Ok(()));
            }
            "timer_stop" => {
                let id_opt = command.args.str("id");
                if let Some(id) = id_opt {
                    self.timers.retain(|t| t.id != id);
                } else {
                    self.timers.clear();
                }
                self.sync_bubble(ctx);
                self.publish(ctx);
                command.reply(Ok(()));
            }
            "timer_add" => {
                let dur_str = command.args.str("duration").map(|s| s.to_string());
                if let Some(ref s) = dur_str {
                    if let Some(extra) = parse_duration(s) {
                        let id_opt = command.args.str("id");
                        if let Some(id) = id_opt {
                            if let Some(t) = self.timers.iter_mut().find(|t| t.id == id) {
                                t.add(extra);
                            }
                        } else if let Some(t) = self.primary_timer_mut() {
                            t.add(extra);
                        }
                        self.sync_bubble(ctx);
                        self.publish(ctx);
                        command.reply(Ok(()));
                    } else {
                        command.reply(Err(format!("invalid duration: {s}")));
                    }
                } else {
                    command.reply(Err("duration argument required".into()));
                }
            }
            "timer_volume" => {
                if let Some(vol) = command.args.int("volume") {
                    self.alarm_volume = (vol as i64).clamp(0, 100) as u32;
                    self.publish(ctx);
                    command.reply(Ok(()));
                } else {
                    command.reply(Err("volume required (0 to 100)".into()));
                }
            }
            "timer_test_sound" => {
                play_alarm(self.settings.sound_file.as_deref(), self.alarm_volume);
                command.reply(Ok(()));
            }
            "stopwatch_start" => {
                self.mode = "stopwatch".to_string();
                self.stopwatch.start();
                self.sync_bubble(ctx);
                self.publish(ctx);
                command.reply(Ok(()));
            }
            "stopwatch_pause" => {
                self.stopwatch.toggle_pause();
                self.sync_bubble(ctx);
                self.publish(ctx);
                command.reply(Ok(()));
            }
            "stopwatch_reset" => {
                let (time_str, _, _, _, _, _) = current_local_time("%H:%M:%S");
                self.stopwatch.reset(&time_str);
                self.sync_bubble(ctx);
                self.publish(ctx);
                command.reply(Ok(()));
            }
            "stopwatch_lap" => {
                if self.stopwatch.running {
                    self.stopwatch.lap();
                    self.publish(ctx);
                    command.reply(Ok(()));
                } else {
                    command.reply(Err("stopwatch is not running".into()));
                }
            }
            "stopwatch_export" => {
                let mut text = String::new();
                if !self.stopwatch.laps.is_empty() {
                    text.push_str("Stopwatch Laps:\n");
                    for lap in &self.stopwatch.laps {
                        text.push_str(&format!(
                            "Lap {}: +{} ({})\n",
                            lap.index, lap.formatted_split, lap.formatted_total
                        ));
                    }
                    text.push_str(&format!(
                        "Total: {}\n",
                        format_tenths(self.stopwatch.elapsed())
                    ));
                } else if !self.stopwatch.history.is_empty() {
                    text.push_str("Stopwatch History:\n");
                    for run in &self.stopwatch.history {
                        text.push_str(&format!(
                            "Run #{}: {} ({} laps) - {}\n",
                            run.index, run.formatted_total, run.lap_count, run.timestamp
                        ));
                    }
                } else {
                    text.push_str(&format!(
                        "Stopwatch: {}\n",
                        format_tenths(self.stopwatch.elapsed())
                    ));
                }

                let mut copied = false;
                if let Ok(mut child) = std::process::Command::new("wl-copy")
                    .stdin(std::process::Stdio::piped())
                    .spawn()
                {
                    use std::io::Write;
                    if let Some(mut stdin) = child.stdin.take() {
                        let _ = stdin.write_all(text.as_bytes());
                    }
                    let _ = child.wait();
                    copied = true;
                }

                if copied {
                    command.reply(Ok(()));
                } else {
                    command.answer(Ok(text));
                }
            }
            "stopwatch_clear_history" => {
                self.stopwatch.history.clear();
                self.publish(ctx);
                command.reply(Ok(()));
            }
            "launcher_search" => {
                let query = command.args.str("query").unwrap_or("").trim();
                let mut results = Vec::new();

                if query.is_empty() {
                    results.push(json!({
                        "title": "Start 5 min timer",
                        "subtitle": ":t 5m",
                        "icon": "bell",
                        "id": "start:5m"
                    }));
                    results.push(json!({
                        "title": "Start 25 min timer",
                        "subtitle": ":t 25m",
                        "icon": "bell",
                        "id": "start:25m"
                    }));
                    results.push(json!({
                        "title": "Stopwatch: Start / Pause",
                        "subtitle": ":t sw",
                        "icon": "bolt",
                        "id": "sw_toggle"
                    }));
                    if !self.timers.is_empty() {
                        results.push(json!({
                            "title": "Stop all active timers",
                            "subtitle": format!("{} timers active", self.timers.len()),
                            "icon": "stop",
                            "id": "timer_stop_all"
                        }));
                    }
                } else if query.eq_ignore_ascii_case("sw")
                    || query.eq_ignore_ascii_case("stopwatch")
                {
                    results.push(json!({
                        "title": if self.stopwatch.running { "Pause stopwatch" } else { "Start stopwatch" },
                        "subtitle": format_tenths(self.stopwatch.elapsed()),
                        "icon": "bolt",
                        "id": "sw_toggle"
                    }));
                    if self.stopwatch.running {
                        results.push(json!({
                            "title": "Record lap",
                            "subtitle": format!("{} laps", self.stopwatch.laps.len()),
                            "icon": "plus",
                            "id": "sw_lap"
                        }));
                        results.push(json!({
                            "title": "Reset stopwatch",
                            "subtitle": "Stop and clear laps",
                            "icon": "stop",
                            "id": "sw_reset"
                        }));
                    }
                } else if let Some((dur, label)) = parse_duration_and_label(query) {
                    let dur_text = format_timer(dur);
                    let title = if let Some(ref l) = label {
                        format!("Start timer: {dur_text} ({l})")
                    } else {
                        format!("Start timer: {dur_text}")
                    };
                    results.push(json!({
                        "title": title,
                        "subtitle": format!("Timer duration: {dur_text}"),
                        "icon": "bell",
                        "id": format!("start:{query}")
                    }));
                } else {
                    results.push(json!({
                        "title": format!("Start timer: {query}"),
                        "subtitle": "Type duration (e.g. 10m, 90s, 1h 30m)",
                        "icon": "bell",
                        "id": format!("start:{query}")
                    }));
                }

                let output_lines: Vec<String> =
                    results.into_iter().map(|r| r.to_string()).collect();
                command.answer(Ok(output_lines.join("\n")));
            }
            "launcher_pick" => {
                let id = command.args.str("id").unwrap_or("").to_string();
                if id == "sw_toggle" {
                    self.stopwatch.toggle_pause();
                } else if id == "sw_lap" {
                    self.stopwatch.lap();
                } else if id == "sw_reset" {
                    let (time_str, _, _, _, _, _) = current_local_time("%H:%M:%S");
                    self.stopwatch.reset(&time_str);
                } else if id == "timer_stop_all" {
                    self.timers.clear();
                } else if let Some(rest) = id.strip_prefix("start:") {
                    if let Some((dur, label)) = parse_duration_and_label(rest) {
                        self.next_timer_id += 1;
                        let tid = format!("t{}", self.next_timer_id);
                        let timer = ActiveTimer::new(tid, label.unwrap_or_default(), dur);
                        self.timers.push(timer);
                        self.mode = "timer".to_string();
                    }
                }
                self.sync_bubble(ctx);
                self.publish(ctx);
                command.reply(Ok(()));
            }
            "clock_add_city" => {
                let city_opt = command.args.str("city");
                if let Some(c) = city_opt {
                    if !self.selected_cities.iter().any(|x| x == c) {
                        self.selected_cities.push(c.to_string());
                    }
                    self.publish(ctx);
                    command.reply(Ok(()));
                } else {
                    command.reply(Err("city argument required".into()));
                }
            }
            "clock_remove_city" => {
                let city_opt = command.args.str("city");
                if let Some(c) = city_opt {
                    self.selected_cities.retain(|x| x != c);
                    self.publish(ctx);
                    command.reply(Ok(()));
                } else {
                    command.reply(Err("city argument required".into()));
                }
            }
            other => command.reply(Err(format!("unknown action: {other}"))),
        }
    }

    fn handle_bubble_click(&mut self, ctx: &ModuleCtx) {
        if let Some(t) = self.primary_timer_mut() {
            t.toggle_pause();
        } else if self.stopwatch.running || self.stopwatch.paused {
            self.stopwatch.toggle_pause();
        }
        self.sync_bubble(ctx);
        self.publish(ctx);
    }

    fn tick(&mut self, ctx: &ModuleCtx) {
        let now = Instant::now();
        let mut finished = Vec::new();

        for (idx, timer) in self.timers.iter_mut().enumerate() {
            if timer.tick(now) {
                finished.push((idx, timer.label.clone(), timer.total_secs));
            }
        }

        if !finished.is_empty() {
            for (_, label, total_secs) in &finished {
                let total_mins = total_secs / 60;
                let rem_secs = total_secs % 60;
                let dur_text = if total_mins > 0 && rem_secs > 0 {
                    format!("{total_mins} min {rem_secs} s")
                } else if total_mins > 0 {
                    format!("{total_mins} min")
                } else {
                    format!("{total_secs} sec")
                };
                let dur_arg = if total_mins > 0 && rem_secs > 0 {
                    format!("{total_mins}m {rem_secs}s")
                } else if total_mins > 0 {
                    format!("{total_mins}m")
                } else {
                    format!("{total_secs}s")
                };
                let title = if label.is_empty() {
                    "Timer finished!".to_string()
                } else {
                    format!("Timer '{label}' finished!")
                };

                ctx.present(
                    ActivitySpec::new("Done")
                        .expanded("Expanded")
                        .priority(Priority::HIGH)
                        .timeout(Duration::from_secs(8))
                        .payload(json!({
                            "title": title,
                            "duration": dur_text,
                            "duration_arg": dur_arg,
                            "label": label,
                        })),
                );

                if self.settings.sound {
                    play_alarm(self.settings.sound_file.as_deref(), self.alarm_volume);
                }

                if self.settings.pause_media && self.media_playing {
                    let call = ctx.call("media", "pause", &[]);
                    tokio::spawn(async move {
                        let _ = call.await;
                    });
                }
            }

            for (idx, _, _) in finished.iter().rev() {
                self.timers.remove(*idx);
            }

            self.sync_bubble(ctx);
        } else if !self.timers.is_empty() || self.stopwatch.running {
            self.sync_bubble(ctx);
        }

        self.publish(ctx);
    }

    fn sync_bubble(&mut self, ctx: &ModuleCtx) {
        let primary = self.primary_timer();
        let show_timer = self.settings.timer_bubble && primary.is_some();
        let show_stopwatch =
            self.settings.stopwatch_bubble && (self.stopwatch.running || self.stopwatch.paused);

        if show_timer {
            let t = primary.unwrap();
            let payload = json!({
                "kind": "timer",
                "text": t.formatted,
                "label": t.label,
                "paused": t.paused,
                "progress": t.progress,
                "count": self.timers.len(),
            });
            if let Some(id) = self.active_bubble {
                ctx.update_bubble(id, payload);
            } else {
                let id = ctx.show_bubble(
                    BubbleSpec::new("Bubble")
                        .wide("Expanded")
                        .key("chrono")
                        .area(self.settings.area)
                        .priority(Priority::LOW)
                        .payload(payload)
                        .news(),
                );
                self.active_bubble = Some(id);
            }
        } else if show_stopwatch {
            let elapsed = self.stopwatch.elapsed();
            let payload = json!({
                "kind": "stopwatch",
                "text": format_tenths(elapsed),
                "paused": self.stopwatch.paused,
                "laps": self.stopwatch.laps.len(),
            });
            if let Some(id) = self.active_bubble {
                ctx.update_bubble(id, payload);
            } else {
                let id = ctx.show_bubble(
                    BubbleSpec::new("Bubble")
                        .wide("Expanded")
                        .key("chrono")
                        .area(self.settings.area)
                        .priority(Priority::LOW)
                        .payload(payload)
                        .news(),
                );
                self.active_bubble = Some(id);
            }
        } else if let Some(id) = self.active_bubble.take() {
            ctx.hide_bubble(id);
        }
    }

    fn publish(&self, ctx: &ModuleCtx) {
        let (time_str, date_str, local_gmtoff, h, m, s) =
            current_local_time(&self.settings.clock_format);
        let sw_elapsed = self.stopwatch.elapsed();

        let (world_clocks_map, available_cities) =
            get_world_clocks(&self.settings.clock_format, local_gmtoff);

        let primary = self.primary_timer();
        let timer_state = if let Some(p) = primary {
            json!({
                "running": true,
                "paused": p.paused,
                "left_secs": p.left_secs,
                "total_secs": p.total_secs,
                "formatted": p.formatted,
                "label": p.label,
                "progress": p.progress,
                "count": self.timers.len(),
                "active_timers": self.timers,
                "default_minutes": self.settings.default_timer_minutes,
                "volume": self.alarm_volume,
            })
        } else {
            json!({
                "running": false,
                "paused": false,
                "left_secs": self.settings.default_timer_minutes * 60,
                "total_secs": self.settings.default_timer_minutes * 60,
                "formatted": format!("{}:00", self.settings.default_timer_minutes),
                "label": "",
                "progress": 1.0,
                "count": 0,
                "active_timers": [],
                "default_minutes": self.settings.default_timer_minutes,
                "volume": self.alarm_volume,
            })
        };

        let state = json!({
            "mode": self.mode,
            "clock": {
                "time": time_str,
                "date": date_str,
                "hours": h,
                "minutes": m,
                "seconds": s,
                "day_progress": ((h * 3600 + m * 60 + s) as f64) / 86400.0,
                "world_clocks": json!(world_clocks_map),
                "available_cities": available_cities,
                "selected_cities": self.selected_cities,
            },
            "stopwatch": {
                "running": self.stopwatch.running,
                "paused": self.stopwatch.paused,
                "elapsed_ms": sw_elapsed.as_millis() as u64,
                "formatted": format_tenths(sw_elapsed),
                "laps": self.stopwatch.laps,
                "lap_count": self.stopwatch.laps.len(),
                "last_lap": self.stopwatch.laps.last(),
                "history": self.stopwatch.history,
            },
            "timer": timer_state,
        });
        ctx.publish_state(state);
    }
}

fn current_local_time(format: &str) -> (String, String, i64, u32, u32, u32) {
    let now = std::time::SystemTime::now();
    let epoch = now.duration_since(std::time::UNIX_EPOCH).unwrap_or_default();
    let secs = epoch.as_secs() as i64;
    unsafe {
        let mut tm = std::mem::zeroed();
        libc::localtime_r(&secs, &mut tm);

        let mut time_buf = [0u8; 64];
        let c_fmt = std::ffi::CString::new(format)
            .unwrap_or_else(|_| std::ffi::CString::new("%H:%M:%S").unwrap());
        let t_len = libc::strftime(
            time_buf.as_mut_ptr() as *mut libc::c_char,
            time_buf.len(),
            c_fmt.as_ptr(),
            &tm,
        );
        let formatted_time = if t_len > 0 {
            String::from_utf8_lossy(&time_buf[..t_len]).to_string()
        } else {
            "00:00:00".to_string()
        };

        let mut date_buf = [0u8; 128];
        let d_fmt = std::ffi::CString::new("%A, %B %e, %Y").unwrap();
        let d_len = libc::strftime(
            date_buf.as_mut_ptr() as *mut libc::c_char,
            date_buf.len(),
            d_fmt.as_ptr(),
            &tm,
        );
        let formatted_date = if d_len > 0 {
            String::from_utf8_lossy(&date_buf[..d_len]).to_string()
        } else {
            String::new()
        };

        (
            formatted_time,
            formatted_date,
            tm.tm_gmtoff,
            tm.tm_hour as u32,
            tm.tm_min as u32,
            tm.tm_sec as u32,
        )
    }
}

struct CityDef {
    id: &'static str,
    city: &'static str,
    country: &'static str,
    timezone: &'static str,
}

const WORLD_CITIES: &[CityDef] = &[
    // Americas
    CityDef { id: "new_york", city: "New York", country: "United States", timezone: "America/New_York" },
    CityDef { id: "los_angeles", city: "Los Angeles", country: "United States", timezone: "America/Los_Angeles" },
    CityDef { id: "chicago", city: "Chicago", country: "United States", timezone: "America/Chicago" },
    CityDef { id: "san_francisco", city: "San Francisco", country: "United States", timezone: "America/Los_Angeles" },
    CityDef { id: "toronto", city: "Toronto", country: "Canada", timezone: "America/Toronto" },
    CityDef { id: "vancouver", city: "Vancouver", country: "Canada", timezone: "America/Vancouver" },
    CityDef { id: "montreal", city: "Montreal", country: "Canada", timezone: "America/Toronto" },
    CityDef { id: "mexico_city", city: "Mexico City", country: "Mexico", timezone: "America/Mexico_City" },
    CityDef { id: "sao_paulo", city: "São Paulo", country: "Brazil", timezone: "America/Sao_Paulo" },
    CityDef { id: "buenos_aires", city: "Buenos Aires", country: "Argentina", timezone: "America/Argentina/Buenos_Aires" },
    CityDef { id: "santiago", city: "Santiago", country: "Chile", timezone: "America/Santiago" },
    CityDef { id: "bogota", city: "Bogotá", country: "Colombia", timezone: "America/Bogota" },
    CityDef { id: "lima", city: "Lima", country: "Peru", timezone: "America/Lima" },

    // Europe
    CityDef { id: "london", city: "London", country: "United Kingdom", timezone: "Europe/London" },
    CityDef { id: "paris", city: "Paris", country: "France", timezone: "Europe/Paris" },
    CityDef { id: "berlin", city: "Berlin", country: "Germany", timezone: "Europe/Berlin" },
    CityDef { id: "rome", city: "Rome", country: "Italy", timezone: "Europe/Rome" },
    CityDef { id: "madrid", city: "Madrid", country: "Spain", timezone: "Europe/Madrid" },
    CityDef { id: "amsterdam", city: "Amsterdam", country: "Netherlands", timezone: "Europe/Amsterdam" },
    CityDef { id: "brussels", city: "Brussels", country: "Belgium", timezone: "Europe/Brussels" },
    CityDef { id: "zurich", city: "Zurich", country: "Switzerland", timezone: "Europe/Zurich" },
    CityDef { id: "vienna", city: "Vienna", country: "Austria", timezone: "Europe/Vienna" },
    CityDef { id: "stockholm", city: "Stockholm", country: "Sweden", timezone: "Europe/Stockholm" },
    CityDef { id: "oslo", city: "Oslo", country: "Norway", timezone: "Europe/Oslo" },
    CityDef { id: "copenhagen", city: "Copenhagen", country: "Denmark", timezone: "Europe/Copenhagen" },
    CityDef { id: "helsinki", city: "Helsinki", country: "Finland", timezone: "Europe/Helsinki" },
    CityDef { id: "warsaw", city: "Warsaw", country: "Poland", timezone: "Europe/Warsaw" },
    CityDef { id: "prague", city: "Prague", country: "Czech Republic", timezone: "Europe/Prague" },
    CityDef { id: "athens", city: "Athens", country: "Greece", timezone: "Europe/Athens" },
    CityDef { id: "dublin", city: "Dublin", country: "Ireland", timezone: "Europe/Dublin" },
    CityDef { id: "lisbon", city: "Lisbon", country: "Portugal", timezone: "Europe/Lisbon" },
    CityDef { id: "istanbul", city: "Istanbul", country: "Turkey", timezone: "Europe/Istanbul" },
    CityDef { id: "kyiv", city: "Kyiv", country: "Ukraine", timezone: "Europe/Kyiv" },
    CityDef { id: "moscow", city: "Moscow", country: "Russia", timezone: "Europe/Moscow" },

    // Asia & Middle East
    CityDef { id: "tokyo", city: "Tokyo", country: "Japan", timezone: "Asia/Tokyo" },
    CityDef { id: "seoul", city: "Seoul", country: "South Korea", timezone: "Asia/Seoul" },
    CityDef { id: "beijing", city: "Beijing", country: "China", timezone: "Asia/Shanghai" },
    CityDef { id: "hong_kong", city: "Hong Kong", country: "Hong Kong", timezone: "Asia/Hong_Kong" },
    CityDef { id: "taipei", city: "Taipei", country: "Taiwan", timezone: "Asia/Taipei" },
    CityDef { id: "singapore", city: "Singapore", country: "Singapore", timezone: "Asia/Singapore" },
    CityDef { id: "bangkok", city: "Bangkok", country: "Thailand", timezone: "Asia/Bangkok" },
    CityDef { id: "hanoi", city: "Hanoi", country: "Vietnam", timezone: "Asia/Bangkok" },
    CityDef { id: "jakarta", city: "Jakarta", country: "Indonesia", timezone: "Asia/Jakarta" },
    CityDef { id: "kuala_lumpur", city: "Kuala Lumpur", country: "Malaysia", timezone: "Asia/Kuala_Lumpur" },
    CityDef { id: "manila", city: "Manila", country: "Philippines", timezone: "Asia/Manila" },
    CityDef { id: "mumbai", city: "Mumbai", country: "India", timezone: "Asia/Kolkata" },
    CityDef { id: "dubai", city: "Dubai", country: "United Arab Emirates", timezone: "Asia/Dubai" },
    CityDef { id: "doha", city: "Doha", country: "Qatar", timezone: "Asia/Qatar" },
    CityDef { id: "riyadh", city: "Riyadh", country: "Saudi Arabia", timezone: "Asia/Riyadh" },
    CityDef { id: "jerusalem", city: "Jerusalem", country: "Israel", timezone: "Asia/Jerusalem" },

    // Africa
    CityDef { id: "cairo", city: "Cairo", country: "Egypt", timezone: "Africa/Cairo" },
    CityDef { id: "johannesburg", city: "Johannesburg", country: "South Africa", timezone: "Africa/Johannesburg" },
    CityDef { id: "casablanca", city: "Casablanca", country: "Morocco", timezone: "Africa/Casablanca" },
    CityDef { id: "nairobi", city: "Nairobi", country: "Kenya", timezone: "Africa/Nairobi" },
    CityDef { id: "lagos", city: "Lagos", country: "Nigeria", timezone: "Africa/Lagos" },

    // Oceania & Pacific
    CityDef { id: "sydney", city: "Sydney", country: "Australia", timezone: "Australia/Sydney" },
    CityDef { id: "melbourne", city: "Melbourne", country: "Australia", timezone: "Australia/Melbourne" },
    CityDef { id: "brisbane", city: "Brisbane", country: "Australia", timezone: "Australia/Brisbane" },
    CityDef { id: "perth", city: "Perth", country: "Australia", timezone: "Australia/Perth" },
    CityDef { id: "auckland", city: "Auckland", country: "New Zealand", timezone: "Pacific/Auckland" },
    CityDef { id: "honolulu", city: "Honolulu", country: "United States (Hawaii)", timezone: "Pacific/Honolulu" },
];

unsafe extern "C" {
    fn tzset();
}

fn get_world_clocks(format: &str, local_gmtoff: i64) -> (HashMap<String, Value>, Vec<Value>) {
    let now = std::time::SystemTime::now();
    let epoch = now.duration_since(std::time::UNIX_EPOCH).unwrap_or_default();
    let secs = epoch.as_secs() as i64;

    let mut local_tm = unsafe { std::mem::zeroed() };
    unsafe {
        libc::localtime_r(&secs, &mut local_tm);
    }

    let mut map = HashMap::new();
    let mut available = Vec::with_capacity(WORLD_CITIES.len());

    for city in WORLD_CITIES {
        available.push(json!({
            "id": city.id,
            "city": city.city,
            "country": city.country,
            "timezone": city.timezone,
        }));

        unsafe {
            let orig_tz = libc::getenv(b"TZ\0".as_ptr() as *const libc::c_char);
            let orig_tz_str = if !orig_tz.is_null() {
                Some(std::ffi::CStr::from_ptr(orig_tz).to_bytes().to_vec())
            } else {
                None
            };

            let c_tz = std::ffi::CString::new(city.timezone).unwrap();
            libc::setenv(b"TZ\0".as_ptr() as *const libc::c_char, c_tz.as_ptr(), 1);
            tzset();

            let mut tm = std::mem::zeroed();
            libc::localtime_r(&secs, &mut tm);

            let mut time_buf = [0u8; 64];
            let c_fmt = std::ffi::CString::new(format)
                .unwrap_or_else(|_| std::ffi::CString::new("%H:%M:%S").unwrap());
            let t_len = libc::strftime(
                time_buf.as_mut_ptr() as *mut libc::c_char,
                time_buf.len(),
                c_fmt.as_ptr(),
                &tm,
            );
            let time_str = if t_len > 0 {
                String::from_utf8_lossy(&time_buf[..t_len]).to_string()
            } else {
                "00:00:00".to_string()
            };

            let mut date_buf = [0u8; 64];
            let d_fmt = std::ffi::CString::new("%a, %b %e").unwrap();
            let d_len = libc::strftime(
                date_buf.as_mut_ptr() as *mut libc::c_char,
                date_buf.len(),
                d_fmt.as_ptr(),
                &tm,
            );
            let date_str = if d_len > 0 {
                String::from_utf8_lossy(&date_buf[..d_len]).to_string()
            } else {
                String::new()
            };

            let diff_secs = tm.tm_gmtoff - local_gmtoff;
            let diff_hours = diff_secs / 3600;
            let diff_str = if diff_hours == 0 {
                "Same time".to_string()
            } else if diff_hours > 0 {
                format!("+{diff_hours} hrs")
            } else {
                format!("{diff_hours} hrs")
            };

            let rel_day = if tm.tm_year == local_tm.tm_year {
                if tm.tm_yday == local_tm.tm_yday {
                    "Today"
                } else if tm.tm_yday > local_tm.tm_yday {
                    "Tomorrow"
                } else {
                    "Yesterday"
                }
            } else if tm.tm_year > local_tm.tm_year {
                "Tomorrow"
            } else {
                "Yesterday"
            };

            if let Some(orig) = orig_tz_str {
                let c_orig = std::ffi::CString::new(orig).unwrap();
                libc::setenv(b"TZ\0".as_ptr() as *const libc::c_char, c_orig.as_ptr(), 1);
            } else {
                libc::unsetenv(b"TZ\0".as_ptr() as *const libc::c_char);
            }
            tzset();

            map.insert(
                city.id.to_string(),
                json!({
                    "id": city.id,
                    "city": city.city,
                    "country": city.country,
                    "timezone": city.timezone,
                    "time": time_str,
                    "date": date_str,
                    "offset": diff_str,
                    "relative_day": rel_day,
                    "hours": tm.tm_hour,
                    "minutes": tm.tm_min,
                }),
            );
        }
    }

    (map, available)
}

fn format_tenths(d: Duration) -> String {
    let total_millis = d.as_millis();
    let total_secs = total_millis / 1000;
    let tenths = (total_millis % 1000) / 100;
    let hours = total_secs / 3600;
    let mins = (total_secs % 3600) / 60;
    let secs = total_secs % 60;
    if hours > 0 {
        format!("{hours:02}:{mins:02}:{secs:02}.{tenths}")
    } else {
        format!("{mins:02}:{secs:02}.{tenths}")
    }
}

fn format_timer(d: Duration) -> String {
    let total_secs = d.as_secs_f64().ceil() as u64;
    let hours = total_secs / 3600;
    let mins = (total_secs % 3600) / 60;
    let secs = total_secs % 60;
    if hours > 0 {
        format!("{hours:02}:{mins:02}:{secs:02}")
    } else {
        format!("{mins:02}:{secs:02}")
    }
}

fn is_duration_token(s: &str) -> bool {
    let lower = s.to_lowercase();
    if lower.ends_with('h') || lower.ends_with('m') || lower.ends_with('s') {
        let num_part = &lower[..lower.len() - 1];
        num_part.parse::<f64>().is_ok()
    } else {
        lower.parse::<f64>().is_ok()
    }
}

fn parse_duration_and_label(input: &str) -> Option<(Duration, Option<String>)> {
    let trimmed = input.trim();
    if trimmed.is_empty() {
        return None;
    }

    let tokens: Vec<&str> = trimmed.split_whitespace().collect();
    if tokens.is_empty() {
        return None;
    }

    if tokens[0].contains(':') {
        let dur = parse_duration(tokens[0])?;
        let label = if tokens.len() > 1 {
            Some(tokens[1..].join(" "))
        } else {
            None
        };
        return Some((dur, label));
    }

    let mut dur_tokens = Vec::new();
    let mut label_tokens = Vec::new();
    let mut in_label = false;

    for &tok in &tokens {
        if in_label {
            label_tokens.push(tok);
            continue;
        }

        let is_dur = is_duration_token(tok);
        if is_dur {
            dur_tokens.push(tok);
        } else {
            in_label = true;
            label_tokens.push(tok);
        }
    }

    if dur_tokens.is_empty() {
        return None;
    }

    let dur_str = dur_tokens.join(" ");
    let dur = parse_duration(&dur_str)?;
    let label = if label_tokens.is_empty() {
        None
    } else {
        Some(label_tokens.join(" "))
    };

    Some((dur, label))
}

fn parse_duration(input: &str) -> Option<Duration> {
    let s = input.trim().to_lowercase();
    if s.is_empty() {
        return None;
    }

    if s.contains(':') {
        let parts: Vec<&str> = s.split(':').collect();
        if parts.len() == 2 {
            let m: u64 = parts[0].trim().parse().ok()?;
            let sec: u64 = parts[1].trim().parse().ok()?;
            return Some(Duration::from_secs(m * 60 + sec));
        } else if parts.len() == 3 {
            let h: u64 = parts[0].trim().parse().ok()?;
            let m: u64 = parts[1].trim().parse().ok()?;
            let sec: u64 = parts[2].trim().parse().ok()?;
            return Some(Duration::from_secs(h * 3600 + m * 60 + sec));
        }
    }

    let mut total_secs: f64 = 0.0;
    let mut matched = false;
    let mut num_str = String::new();

    for c in s.chars() {
        if c.is_ascii_digit() || c == '.' {
            num_str.push(c);
        } else if c.is_alphabetic() {
            if !num_str.is_empty() {
                if let Ok(val) = num_str.parse::<f64>() {
                    num_str.clear();
                    match c {
                        'h' => {
                            total_secs += val * 3600.0;
                            matched = true;
                        }
                        'm' => {
                            total_secs += val * 60.0;
                            matched = true;
                        }
                        's' => {
                            total_secs += val;
                            matched = true;
                        }
                        _ => {}
                    }
                }
            }
        }
    }

    if matched {
        return Some(Duration::from_secs_f64(total_secs.max(1.0)));
    }

    if let Ok(num) = s.parse::<f64>() {
        if num > 0.0 {
            return Some(Duration::from_secs_f64((num * 60.0).max(1.0)));
        }
    }

    None
}

fn play_alarm(custom_sound: Option<&str>, volume: u32) {
    if volume == 0 {
        return;
    }
    let default_sound = "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga";
    let sound_path = custom_sound.unwrap_or(default_sound).to_string();
    let vol_float = (volume as f64 / 100.0).clamp(0.01, 1.0);
    let pa_vol = ((volume as f64 / 100.0) * 65536.0).round() as u64;

    std::thread::spawn(move || {
        let pw_res = std::process::Command::new("pw-play")
            .arg("--volume")
            .arg(format!("{vol_float:.2}"))
            .arg(&sound_path)
            .status();

        if pw_res.is_err() || !pw_res.unwrap().success() {
            let pa_res = std::process::Command::new("paplay")
                .arg(format!("--volume={pa_vol}"))
                .arg(&sound_path)
                .status();

            if pa_res.is_err() || !pa_res.unwrap().success() {
                let _ = std::process::Command::new("canberra-gtk-play")
                    .arg("-i")
                    .arg("alarm-clock-elapsed")
                    .status();
            }
        }
    });
}
