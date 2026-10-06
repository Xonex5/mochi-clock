.pragma library

// Formats seconds into mm:ss or hh:mm:ss
function formatSeconds(seconds) {
    const whole = Math.max(0, Math.floor(seconds ?? 0));
    const h = Math.floor(whole / 3600);
    const m = Math.floor((whole % 3600) / 60);
    const s = whole % 60;
    if (h > 0) {
        return `${h}:${m < 10 ? "0" : ""}${m}:${s < 10 ? "0" : ""}${s}`;
    }
    return `${m}:${s < 10 ? "0" : ""}${s}`;
}

// Formats milliseconds into mm:ss.t or hh:mm:ss.t
function formatTenths(millis) {
    const totalMs = Math.max(0, Math.floor(millis ?? 0));
    const totalSecs = Math.floor(totalMs / 1000);
    const tenths = Math.floor((totalMs % 1000) / 100);
    const h = Math.floor(totalSecs / 3600);
    const m = Math.floor((totalSecs % 3600) / 60);
    const s = totalSecs % 60;
    if (h > 0) {
        return `${h}:${m < 10 ? "0" : ""}${m}:${s < 10 ? "0" : ""}${s}.${tenths}`;
    }
    return `${m < 10 ? "0" : ""}${m}:${s < 10 ? "0" : ""}${s}.${tenths}`;
}

// Intuitively parses human-entered durations into total seconds
// Examples supported:
// - "10" -> 600s (10 min)
// - "5m", "10 min", "15 mins" -> 300s, 600s, 900s
// - "90s", "45 sec" -> 90s, 45s
// - "1h", "2 hr", "1h 30m", "1h30" -> 3600s, 5400s
// - "05:00", "1:30:00" -> 300s, 5400s
// - "2m 30s", "2.5m" -> 150s
function parseDuration(input) {
    if (!input) return null;
    let s = String(input).trim().toLowerCase();
    if (!s) return null;

    // Check mm:ss or hh:mm:ss format
    if (s.includes(":")) {
        const parts = s.split(":").map(p => parseInt(p, 10));
        if (parts.some(isNaN)) return null;
        if (parts.length === 2) {
            return parts[0] * 60 + parts[1];
        } else if (parts.length === 3) {
            return parts[0] * 3600 + parts[1] * 60 + parts[2];
        }
    }

    let totalSeconds = 0;
    let matched = false;

    const hourMatch = s.match(/(\d+(?:\.\d+)?)\s*(?:h|hr|hrs|hour|hours)/);
    if (hourMatch) {
        totalSeconds += parseFloat(hourMatch[1]) * 3600;
        matched = true;
    }

    const minMatch = s.match(/(\d+(?:\.\d+)?)\s*(?:m|min|mins|minute|minutes)/);
    if (minMatch) {
        totalSeconds += parseFloat(minMatch[1]) * 60;
        matched = true;
    }

    const secMatch = s.match(/(\d+(?:\.\d+)?)\s*(?:s|sec|secs|second|seconds)/);
    if (secMatch) {
        totalSeconds += parseFloat(secMatch[1]);
        matched = true;
    }

    if (matched) {
        return Math.max(1, Math.round(totalSeconds));
    }

    // Single number: default to minutes (e.g. "5" -> 5 minutes, "0.5" -> 30 seconds)
    const num = parseFloat(s);
    if (!isNaN(num) && num > 0) {
        return Math.max(1, Math.round(num * 60));
    }

    return null;
}
