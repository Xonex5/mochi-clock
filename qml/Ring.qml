import QtQuick
import qs.island

// Anneau de progression circulaire
Canvas {
    id: root

    property real progress: 1
    property color color: Theme.accent
    property real line: 2.5

    onProgressChanged: requestPaint()
    onColorChanged: requestPaint()

    onPaint: {
        const context = getContext("2d");
        context.reset();
        const radius = Math.min(width, height) / 2 - line;
        if (radius <= 0) return;

        context.lineWidth = line;
        context.lineCap = "round";
        context.strokeStyle = Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.25);
        context.beginPath();
        context.arc(width / 2, height / 2, radius, 0, Math.PI * 2);
        context.stroke();

        if (progress > 0) {
            context.strokeStyle = root.color;
            context.beginPath();
            const start = -Math.PI / 2;
            context.arc(width / 2, height / 2, radius, start, start + Math.PI * 2 * Math.max(0, Math.min(1, progress)));
            context.stroke();
        }
    }
}
