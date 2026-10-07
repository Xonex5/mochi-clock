import QtQuick
import qs.island
import "ClockHelper.js" as ClockHelper

// Hub Card and Desktop Widget for Chrono (Timer and Stopwatch)
Item {
    id: root

    property var payload: null
    readonly property string activeMode: payload?.mode === "stopwatch" ? "stopwatch" : "timer"
    readonly property var stopwatch: payload?.stopwatch ?? ({})
    readonly property var timer: payload?.timer ?? ({})

    implicitHeight: mainColumn.implicitHeight

    function startTimerWithText(text) {
        if (!text || text.trim() === "") return false;
        Daemon.command("chrono", "timer_start", [text.trim()]);
        return true;
    }

    Column {
        id: mainColumn

        width: parent.width
        spacing: 10

        // Switcher: Timer and Stopwatch only (no Clock in Home)
        Segmented {
            id: switcher

            width: parent.width
            height: 32
            color: Theme.raised
            options: [
                { "value": "timer", "label": "Timer", "icon": "bell" },
                { "value": "stopwatch", "label": "Stopwatch", "icon": "clock" }
            ]
            current: root.activeMode
            onPicked: value => Daemon.command("chrono", "mode", [value])
        }

        // ================= TIMER VIEW =================
        Item {
            id: timerSection

            visible: root.activeMode === "timer"
            width: parent.width
            implicitHeight: root.timer.running ? 60 : 76

            // When Timer is Running
            Item {
                visible: root.timer.running
                anchors.fill: parent

                Ring {
                    id: cardTimerRing
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    line: 3
                    color: root.timer.paused ? Theme.muted : Theme.accent
                    progress: root.timer.progress ?? 1
                }

                Row {
                    id: cardTimerActions
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Button {
                        text: "+1m"
                        tone: "ghost"
                        onClicked: Daemon.command("chrono", "timer_add", ["1m"])
                    }

                    Button {
                        icon: root.timer.paused ? "play" : "pause"
                        tone: root.timer.paused ? "accent" : "neutral"
                        onClicked: Daemon.command("chrono", "timer_pause", [])
                    }

                    Button {
                        icon: "stop"
                        tone: "danger"
                        onClicked: Daemon.command("chrono", "timer_stop", [])
                    }
                }

                Column {
                    anchors.left: cardTimerRing.right
                    anchors.leftMargin: 12
                    anchors.right: cardTimerActions.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    clip: true

                    Text {
                        text: root.timer.formatted ?? "00:00"
                        color: Theme.foreground
                        font.pixelSize: Theme.textTitle
                        font.family: Theme.displayFamily
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }

                    Text {
                        width: parent.width
                        text: {
                            if (root.timer.paused) return "Paused";
                            if (root.timer.label && root.timer.label !== "") {
                                return (root.timer.count > 1) ? `${root.timer.label} (+${root.timer.count - 1})` : root.timer.label;
                            }
                            return (root.timer.count > 1) ? `Countdown (${root.timer.count})` : "Countdown";
                        }
                        color: Theme.muted
                        font.pixelSize: Theme.textLabel
                        font.family: Theme.fontFamily
                        elide: Text.ElideRight
                    }
                }
            }

            // When Timer is Idle: intuitive text input + quick presets
            Column {
                visible: !root.timer.running
                width: parent.width
                spacing: 8

                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: parent.width - startBtn.width - 8
                        height: 34
                        radius: 17
                        color: Theme.raised

                        Symbol {
                            id: bellIcon
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            name: "bell"
                            size: 13
                            color: Theme.muted
                        }

                        TextInput {
                            id: timerInput
                            anchors.left: bellIcon.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 10
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
                                visible: timerInput.text === ""
                                text: "Set time (e.g. 5m, 10:00, 90s)..."
                                color: Theme.muted
                                font: timerInput.font
                            }
                        }
                    }

                    Button {
                        id: startBtn
                        text: "Start"
                        icon: "play"
                        tone: "accent"
                        onClicked: {
                            if (timerInput.text !== "") {
                                if (root.startTimerWithText(timerInput.text)) {
                                    timerInput.text = "";
                                }
                            } else {
                                Daemon.command("chrono", "timer_start", []);
                            }
                        }
                    }
                }

                // Quick presets
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6

                    Button {
                        text: "1m"
                        tone: "ghost"
                        onClicked: Daemon.command("chrono", "timer_start", ["1m"])
                    }

                    Button {
                        text: "5m"
                        tone: "neutral"
                        onClicked: Daemon.command("chrono", "timer_start", ["5m"])
                    }

                    Button {
                        text: "15m"
                        tone: "ghost"
                        onClicked: Daemon.command("chrono", "timer_start", ["15m"])
                    }

                    Button {
                        text: "25m"
                        tone: "ghost"
                        onClicked: Daemon.command("chrono", "timer_start", ["25m"])
                    }
                }
            }
        }

        // ================= STOPWATCH VIEW =================
        Item {
            id: stopwatchSection

            visible: root.activeMode === "stopwatch"
            width: parent.width
            implicitHeight: 60

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Symbol {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "clock"
                    size: 24
                    color: root.stopwatch.running ? (root.stopwatch.paused ? Theme.muted : Theme.accent) : Theme.muted
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: root.stopwatch.formatted ?? "00:00.0"
                        color: Theme.foreground
                        font.pixelSize: Theme.textTitle
                        font.family: Theme.displayFamily
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }

                    Text {
                        text: {
                            if (!root.stopwatch.running) return "Ready";
                            if (root.stopwatch.paused) return "Paused";
                            if ((root.stopwatch.lap_count ?? 0) > 0) {
                                return `Lap ${root.stopwatch.lap_count} · ${root.stopwatch.last_lap?.formatted_split ?? ""}`;
                            }
                            return "Running";
                        }
                        color: Theme.muted
                        font.pixelSize: Theme.textLabel
                        font.family: Theme.fontFamily
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Button {
                    visible: !root.stopwatch.running
                    text: "Start"
                    icon: "play"
                    tone: "accent"
                    onClicked: Daemon.command("chrono", "stopwatch_start", [])
                }

                Button {
                    visible: root.stopwatch.running && !root.stopwatch.paused
                    text: "Lap"
                    icon: "plus"
                    tone: "ghost"
                    onClicked: Daemon.command("chrono", "stopwatch_lap", [])
                }

                Button {
                    visible: root.stopwatch.running
                    icon: root.stopwatch.paused ? "play" : "pause"
                    tone: root.stopwatch.paused ? "accent" : "neutral"
                    onClicked: Daemon.command("chrono", "stopwatch_pause", [])
                }

                Button {
                    visible: root.stopwatch.running
                    icon: "stop"
                    tone: "danger"
                    onClicked: Daemon.command("chrono", "stopwatch_reset", [])
                }
            }
        }
    }
}
