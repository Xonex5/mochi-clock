import QtQuick
import qs.island
import "ClockHelper.js" as ClockHelper

// Dedicated Hub Page view for Chrono (Clock, Stopwatch, and Timer)
Item {
    id: root

    property var payload: null
    readonly property string mode: payload?.mode ?? "timer"
    readonly property var clock: payload?.clock ?? ({})
    readonly property var stopwatch: payload?.stopwatch ?? ({})
    readonly property var timer: payload?.timer ?? ({})
    readonly property var laps: stopwatch.laps ?? []

    implicitWidth: 800
    implicitHeight: 380

    function startTimerWithText(text) {
        const secs = ClockHelper.parseDuration(text);
        if (secs && secs > 0) {
            Daemon.command("chrono", "timer_start", [`${secs}s`]);
            return true;
        }
        return false;
    }

    Column {
        anchors.fill: parent
        spacing: 16

        // Tab bar navigation
        Segmented {
            id: nav

            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, 420)
            height: 38
            color: Theme.raised
            options: [
                { "value": "clock", "label": "Clock", "icon": "clock" },
                { "value": "stopwatch", "label": "Stopwatch", "icon": "bolt" },
                { "value": "timer", "label": "Timer", "icon": "bell" }
            ]
            current: root.mode
            onPicked: value => Daemon.command("chrono", "mode", [value])
        }

        // ================= CLOCK VIEW =================
        Item {
            visible: root.mode === "clock"
            width: parent.width
            height: parent.height - nav.height - 16

            Row {
                anchors.centerIn: parent
                spacing: 48

                // Time and date display
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        text: root.clock.time ?? "00:00:00"
                        color: Theme.foreground
                        font.pixelSize: Theme.textDisplay * 1.4
                        font.family: Theme.displayFamily
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                    }

                    Text {
                        text: root.clock.date ?? ""
                        color: Theme.muted
                        font.pixelSize: Theme.textSubtitle
                        font.family: Theme.fontFamily
                    }
                }

                // Day progress card
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 220
                    height: 110
                    radius: Theme.radiusLarge
                    color: Theme.surface

                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        width: parent.width - 28

                        Item {
                            width: parent.width
                            height: 20

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Day elapsed"
                                color: Theme.muted
                                font.pixelSize: Theme.textLabel
                                font.family: Theme.fontFamily
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: `${Math.round((root.clock.day_progress ?? 0) * 100)}%`
                                color: Theme.accent
                                font.pixelSize: Theme.textLabel
                                font.family: Theme.fontFamily
                                font.weight: Font.DemiBold
                            }
                        }

                        ProgressBar {
                            width: parent.width
                            value: root.clock.day_progress ?? 0
                            fill: Theme.accent
                        }
                    }
                }
            }
        }

        // ================= STOPWATCH VIEW =================
        Item {
            visible: root.mode === "stopwatch"
            width: parent.width
            height: parent.height - nav.height - 16

            Row {
                anchors.fill: parent
                spacing: 24

                // Controls and big time
                Column {
                    width: (parent.width - 24) * 0.48
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 18

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.stopwatch.formatted ?? "00:00.0"
                        color: Theme.foreground
                        font.pixelSize: Theme.textDisplay * 1.3
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10

                        Button {
                            visible: !root.stopwatch.running
                            text: "Start"
                            icon: "play"
                            tone: "accent"
                            onClicked: Daemon.command("chrono", "stopwatch_start", [])
                        }

                        Button {
                            visible: root.stopwatch.running
                            text: root.stopwatch.paused ? "Resume" : "Pause"
                            icon: root.stopwatch.paused ? "play" : "pause"
                            tone: root.stopwatch.paused ? "accent" : "neutral"
                            onClicked: Daemon.command("chrono", "stopwatch_pause", [])
                        }

                        Button {
                            visible: root.stopwatch.running && !root.stopwatch.paused
                            text: "Lap"
                            icon: "plus"
                            tone: "neutral"
                            onClicked: Daemon.command("chrono", "stopwatch_lap", [])
                        }

                        Button {
                            visible: root.stopwatch.running
                            text: "Reset"
                            icon: "stop"
                            tone: "danger"
                            onClicked: Daemon.command("chrono", "stopwatch_reset", [])
                        }
                    }
                }

                // Recorded laps card
                Rectangle {
                    width: (parent.width - 24) * 0.52
                    height: parent.height - 10
                    anchors.verticalCenter: parent.verticalCenter
                    radius: Theme.radiusLarge
                    color: Theme.surface
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Text {
                            text: `Recorded laps (${root.laps.length})`
                            color: Theme.muted
                            font.pixelSize: Theme.textCaption
                            font.family: Theme.fontFamily
                            font.weight: Font.DemiBold
                        }

                        Text {
                            visible: root.laps.length === 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 80
                            text: "No laps recorded"
                            color: Theme.muted
                            font.pixelSize: Theme.textLabel
                            font.family: Theme.fontFamily
                        }

                        ListView {
                            visible: root.laps.length > 0
                            width: parent.width
                            height: parent.height - 28
                            clip: true
                            model: root.laps.slice().reverse()
                            spacing: 4

                            delegate: Rectangle {
                                width: parent.width
                                height: 32
                                radius: Theme.radiusSmall
                                color: Theme.raised

                                Item {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12

                                    Text {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: `Lap ${modelData.index}`
                                        color: Theme.muted
                                        font.pixelSize: Theme.textLabel
                                        font.family: Theme.fontFamily
                                    }

                                    Row {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 16

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: `+${modelData.formatted_split}`
                                            color: Theme.accent
                                            font.pixelSize: Theme.textLabel
                                            font.family: Theme.fontFamily
                                            font.features: { "tnum": 1 }
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.formatted_total
                                            color: Theme.foreground
                                            font.pixelSize: Theme.textLabel
                                            font.family: Theme.fontFamily
                                            font.weight: Font.DemiBold
                                            font.features: { "tnum": 1 }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ================= TIMER VIEW =================
        Item {
            visible: root.mode === "timer"
            width: parent.width
            height: parent.height - nav.height - 16

            Row {
                anchors.centerIn: parent
                spacing: 36

                // Circular countdown ring
                Item {
                    width: 140
                    height: 140
                    anchors.verticalCenter: parent.verticalCenter

                    Ring {
                        anchors.fill: parent
                        line: 6
                        color: root.timer.paused ? Theme.muted : Theme.accent
                        progress: root.timer.running ? (root.timer.progress ?? 1) : 1
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.timer.running ? (root.timer.formatted ?? "00:00") : `${root.timer.default_minutes ?? 5}:00`
                            color: Theme.foreground
                            font.pixelSize: Theme.textTitle
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.timer.paused ? "Paused" : (root.timer.running ? "Running" : "Ready")
                            color: Theme.muted
                            font.pixelSize: Theme.textCaption
                            font.family: Theme.fontFamily
                        }
                    }
                }

                // Controls, Input and Presets
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14
                    width: 360

                    // Intuitive text input field to type duration
                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: parent.width - (root.timer.running ? 0 : pageStartBtn.width + 8)
                            height: 38
                            radius: 19
                            color: Theme.surface

                            Symbol {
                                id: pageInputIcon
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                name: "bell"
                                size: 14
                                color: Theme.muted
                            }

                            TextInput {
                                id: pageTimerInput
                                anchors.left: pageInputIcon.right
                                anchors.leftMargin: 8
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.foreground
                                selectionColor: Theme.accent
                                font.pixelSize: Theme.textBody
                                font.family: Theme.fontFamily
                                clip: true
                                onAccepted: {
                                    if (root.startTimerWithText(text)) {
                                        text = "";
                                    }
                                }

                                Text {
                                    visible: pageTimerInput.text === ""
                                    text: "Type duration (e.g. 5m, 90s, 1h 30m, 10:00)..."
                                    color: Theme.muted
                                    font: pageTimerInput.font
                                }
                            }
                        }

                        Button {
                            id: pageStartBtn
                            visible: !root.timer.running
                            text: "Start"
                            icon: "play"
                            tone: "accent"
                            onClicked: {
                                if (pageTimerInput.text !== "") {
                                    if (root.startTimerWithText(pageTimerInput.text)) {
                                        pageTimerInput.text = "";
                                    }
                                } else {
                                    Daemon.command("chrono", "timer_start", []);
                                }
                            }
                        }
                    }

                    // Action buttons when running
                    Row {
                        spacing: 8
                        visible: root.timer.running

                        Button {
                            text: root.timer.paused ? "Resume" : "Pause"
                            icon: root.timer.paused ? "play" : "pause"
                            tone: root.timer.paused ? "accent" : "neutral"
                            onClicked: Daemon.command("chrono", "timer_pause", [])
                        }

                        Button {
                            text: "+1 min"
                            tone: "neutral"
                            onClicked: Daemon.command("chrono", "timer_add", ["1m"])
                        }

                        Button {
                            text: "+5 min"
                            tone: "neutral"
                            onClicked: Daemon.command("chrono", "timer_add", ["5m"])
                        }

                        Button {
                            text: "Stop"
                            icon: "stop"
                            tone: "danger"
                            onClicked: Daemon.command("chrono", "timer_stop", [])
                        }
                    }

                    // Quick presets grid
                    Column {
                        spacing: 6

                        Text {
                            text: "Quick presets:"
                            color: Theme.muted
                            font.pixelSize: Theme.textCaption
                            font.family: Theme.fontFamily
                        }

                        Grid {
                            columns: 4
                            spacing: 6

                            Repeater {
                                model: [
                                    { "label": "1 min", "val": "1m" },
                                    { "label": "3 min", "val": "3m" },
                                    { "label": "5 min", "val": "5m" },
                                    { "label": "10 min", "val": "10m" },
                                    { "label": "15 min", "val": "15m" },
                                    { "label": "20 min", "val": "20m" },
                                    { "label": "25 min (Pomodoro)", "val": "25m" },
                                    { "label": "30 min", "val": "30m" }
                                ]

                                Button {
                                    text: modelData.label
                                    tone: "raised"
                                    onClicked: Daemon.command("chrono", "timer_start", [modelData.val])
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
