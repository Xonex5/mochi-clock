//! Plugin Mochi Chrono : Horloge, Chronomètre et Minuteur tout-en-un.

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

#[derive(Debug)]
struct Stopwatch {
    running: bool,
    paused: bool,
    start_instant: Option<Instant>,
    accumulated: Duration,
    last_lap_total: Duration,
    laps: Vec<Lap>,
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

    fn reset(&mut self) {
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

#[derive(Debug)]
struct Timer {
    running: bool,
    paused: bool,
    total: Duration,
    left: Duration,
    target_instant: Option<Instant>,
}

impl Timer {
    fn new(default_minutes: u64) -> Self {
        let default_dur = Duration::from_secs(default_minutes * 60);
        Self {
            running: false,
            paused: false,
            total: default_dur,
            left: default_dur,
            target_instant: None,
        }
    }

    fn start(&mut self, duration: Duration) {
        self.running = true;
        self.paused = false;
        self.total = duration;
        self.left = duration;
        self.target_instant = Some(Instant::now() + duration);
    }

    fn pause(&mut self) {
        if self.running && !self.paused {
            if let Some(target) = self.target_instant.take() {
                self.left = target.saturating_duration_since(Instant::now());
            }
            self.paused = true;
        }
    }

    fn resume(&mut self) {
        if self.running && self.paused {
            self.paused = false;
            self.target_instant = Some(Instant::now() + self.left);
        }
    }

    fn toggle_pause(&mut self, default_duration: Duration) {
        if !self.running {
            let dur = if self.left > Duration::ZERO {
                self.left
            } else {
                default_duration
            };
            self.start(dur);
        } else if self.paused {
            self.resume();
        } else {
            self.pause();
        }
    }

    fn stop(&mut self) {
        self.running = false;
        self.paused = false;
        self.target_instant = None;
        self.left = self.total;
    }

    fn add(&mut self, extra: Duration) {
        if self.running {
            self.total += extra;
            if self.paused {
                self.left += extra;
            } else if let Some(target) = self.target_instant {
                let new_target = target + extra;
                self.target_instant = Some(new_target);
                self.left = new_target.saturating_duration_since(Instant::now());
            }
        } else {
            self.total += extra;
            self.left += extra;
        }
    }

    fn tick(&mut self) -> bool {
        if self.running && !self.paused {
            if let Some(target) = self.target_instant {
                let now = Instant::now();
                if now >= target {
                    self.running = false;
                    self.target_instant = None;
                    self.left = Duration::ZERO;
                    return true;
                } else {
                    self.left = target.duration_since(now);
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
    timer: Timer,
    active_bubble: Option<BubbleId>,
}

fn main() -> ExitCode {
    mochi_sdk::run(run)
}

async fn run(mut ctx: ModuleCtx) -> Result<(), mochi_sdk::Error> {
    let settings: Settings = ctx.settings()?;
    let default_min = settings.default_timer_minutes;
    let mut plugin = ChronoPlugin {
        settings,
        mode: "clock".to_string(),
        stopwatch: Stopwatch::new(),
        timer: Timer::new(default_min),
        active_bubble: None,
    };

    plugin.publish(&ctx);

    loop {
        // Ticking interval adapts based on whether stopwatch is running (100ms for precision) or idle (500ms)
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
                let (time_str, date_str, _, _, _) = current_local_time(&self.settings.clock_format);
                let sw_desc = if self.stopwatch.running {
                    let state = if self.stopwatch.paused { "en pause" } else { "en cours" };
                    format!(
                        "{} ({state}, {} tours)",
                        format_tenths(self.stopwatch.elapsed()),
                        self.stopwatch.laps.len()
                    )
                } else {
                    "arrêté".to_string()
                };
                let timer_desc = if self.timer.running {
                    let state = if self.timer.paused { "en pause" } else { "en cours" };
                    format!("{} restant ({state})", format_timer(self.timer.left))
                } else {
                    "arrêté".to_string()
                };
                command.answer(Ok(format!(
                    "Horloge : {time_str} ({date_str})\nChronomètre : {sw_desc}\nMinuteur : {timer_desc}\nMode actif : {}",
                    self.mode
                )));
            }
            "mode" => {
                if let Some(new_mode) = command.args.str("mode") {
                    self.mode = new_mode.to_string();
                    self.publish(ctx);
                    command.reply(Ok(()));
                } else {
                    command.reply(Err("mode requis (clock, stopwatch, timer)".into()));
                }
            }
            "timer_start" => {
                let minutes = command.args.int("minutes").map(|m| m.max(0) as u64);
                let seconds = command.args.int("seconds").map(|s| s.max(0) as u64);
                let duration = match (minutes, seconds) {
                    (Some(m), Some(s)) if m > 0 || s > 0 => Duration::from_secs(m * 60 + s),
                    (Some(m), None) if m > 0 => Duration::from_secs(m * 60),
                    (None, Some(s)) if s > 0 => Duration::from_secs(s),
                    _ => Duration::from_secs(self.settings.default_timer_minutes * 60),
                };
                self.mode = "timer".to_string();
                self.timer.start(duration);
                self.sync_bubble(ctx);
                self.publish(ctx);
                command.reply(Ok(()));
            }
            "timer_pause" => {
                self.timer.toggle_pause(Duration::from_secs(self.settings.default_timer_minutes * 60));
                self.sync_bubble(ctx);
                self.publish(ctx);
                command.reply(Ok(()));
            }
            "timer_stop" => {
                self.timer.stop();
                self.sync_bubble(ctx);
                self.publish(ctx);
                command.reply(Ok(()));
            }
            "timer_add" => {
                if let Some(minutes) = command.args.int("minutes") {
                    let extra = Duration::from_secs((minutes.max(1) as u64) * 60);
                    self.timer.add(extra);
                    self.sync_bubble(ctx);
                    self.publish(ctx);
                    command.reply(Ok(()));
                } else {
                    command.reply(Err("spécifiez les minutes à ajouter".into()));
                }
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
                self.stopwatch.reset();
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
                    command.reply(Err("le chronomètre n'est pas actif".into()));
                }
            }
            other => command.reply(Err(format!("action inconnue: {other}"))),
        }
    }

    fn handle_bubble_click(&mut self, ctx: &ModuleCtx) {
        if self.timer.running || self.timer.paused {
            self.timer.toggle_pause(Duration::from_secs(self.settings.default_timer_minutes * 60));
        } else if self.stopwatch.running || self.stopwatch.paused {
            self.stopwatch.toggle_pause();
        }
        self.sync_bubble(ctx);
        self.publish(ctx);
    }

    fn tick(&mut self, ctx: &ModuleCtx) {
        let timer_finished = self.timer.tick();

        if timer_finished {
            self.sync_bubble(ctx);
            let total_mins = self.timer.total.as_secs() / 60;
            let duration_text = if total_mins > 0 {
                format!("{total_mins} min")
            } else {
                format!("{} s", self.timer.total.as_secs())
            };
            ctx.present(
                ActivitySpec::new("Done")
                    .priority(Priority::HIGH)
                    .timeout(Duration::from_secs(8))
                    .payload(json!({
                        "title": "Minuteur terminé !",
                        "duration": duration_text,
                    })),
            );
            if self.settings.sound {
                trigger_alarm();
            }
        } else if self.timer.running || self.stopwatch.running {
            self.sync_bubble(ctx);
        }

        self.publish(ctx);
    }

    fn sync_bubble(&mut self, ctx: &ModuleCtx) {
        let show_timer = self.settings.timer_bubble && (self.timer.running || self.timer.paused);
        let show_stopwatch = self.settings.stopwatch_bubble && (self.stopwatch.running || self.stopwatch.paused);

        if show_timer {
            let payload = self.bubble_payload("timer");
            if let Some(id) = self.active_bubble {
                ctx.update_bubble(id, payload);
            } else {
                let id = ctx.show_bubble(
                    BubbleSpec::new("Bubble")
                        .key("chrono")
                        .area(self.settings.area)
                        .priority(Priority::LOW)
                        .payload(payload)
                        .news(),
                );
                self.active_bubble = Some(id);
            }
        } else if show_stopwatch {
            let payload = self.bubble_payload("stopwatch");
            if let Some(id) = self.active_bubble {
                ctx.update_bubble(id, payload);
            } else {
                let id = ctx.show_bubble(
                    BubbleSpec::new("Bubble")
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

    fn bubble_payload(&self, kind: &str) -> Value {
        match kind {
            "timer" => {
                let left_secs = self.timer.left.as_secs_f64().ceil() as u64;
                let total_secs = self.timer.total.as_secs().max(1);
                let progress = (left_secs as f64) / (total_secs as f64);
                json!({
                    "kind": "timer",
                    "text": format_timer(self.timer.left),
                    "paused": self.timer.paused,
                    "progress": progress.clamp(0.0, 1.0),
                })
            }
            "stopwatch" => {
                let elapsed = self.stopwatch.elapsed();
                json!({
                    "kind": "stopwatch",
                    "text": format_tenths(elapsed),
                    "paused": self.stopwatch.paused,
                })
            }
            _ => json!({}),
        }
    }

    fn publish(&self, ctx: &ModuleCtx) {
        let (time_str, date_str, h, m, s) = current_local_time(&self.settings.clock_format);
        let sw_elapsed = self.stopwatch.elapsed();
        let timer_progress = if self.timer.total.as_secs_f64() > 0.0 {
            (self.timer.left.as_secs_f64() / self.timer.total.as_secs_f64()).clamp(0.0, 1.0)
        } else {
            0.0
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
            },
            "stopwatch": {
                "running": self.stopwatch.running,
                "paused": self.stopwatch.paused,
                "elapsed_ms": sw_elapsed.as_millis() as u64,
                "formatted": format_tenths(sw_elapsed),
                "laps": self.stopwatch.laps,
                "lap_count": self.stopwatch.laps.len(),
                "last_lap": self.stopwatch.laps.last(),
            },
            "timer": {
                "running": self.timer.running,
                "paused": self.timer.paused,
                "left_secs": self.timer.left.as_secs_f64().ceil() as u64,
                "total_secs": self.timer.total.as_secs(),
                "formatted": format_timer(self.timer.left),
                "progress": timer_progress,
                "default_minutes": self.settings.default_timer_minutes,
            }
        });
        ctx.publish_state(state);
    }
}

fn current_local_time(format: &str) -> (String, String, u32, u32, u32) {
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
        let d_fmt = std::ffi::CString::new("%A %d %B %Y").unwrap();
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
            tm.tm_hour as u32,
            tm.tm_min as u32,
            tm.tm_sec as u32,
        )
    }
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

fn trigger_alarm() {
    std::thread::spawn(|| {
        let _ = std::process::Command::new("canberra-gtk-play")
            .arg("-i")
            .arg("alarm-clock-elapsed")
            .status()
            .or_else(|_| {
                std::process::Command::new("canberra-gtk-play")
                    .arg("-i")
                    .arg("complete")
                    .status()
            });
    });
}
