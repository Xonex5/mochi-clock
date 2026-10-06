.pragma library

// Formate les secondes en mm:ss ou hh:mm:ss
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

// Formate les millisecondes en mm:ss.t
function formatTenths(millis) {
    const totalMs = Math.max(0, Math.floor(millis ?? 0));
    const totalSecs = Math.floor(totalMs / 1000);
    const tenths = Math.floor((totalMs % 1000) / 100);
    const m = Math.floor(totalSecs / 60);
    const s = totalSecs % 60;
    return `${m < 10 ? "0" : ""}${m}:${s < 10 ? "0" : ""}${s}.${tenths}`;
}
