import QtQuick
import qs.island

// Carte Hub et Widget Bureau pour Chrono (Horloge, Chronomètre, Minuteur)
Item {
    id: root

    property var payload: null
    readonly property string mode: payload?.mode ?? "clock"
    readonly property var clock: payload?.clock ?? ({})
    readonly property var stopwatch: payload?.stopwatch ?? ({})
    readonly property var timer: payload?.timer ?? ({})

    implicitHeight: mainColumn.implicitHeight

    Column {
        id: mainColumn

        width: parent.width
        spacing: 12

        // Sélecteur de mode 3-en-1
        Segmented {
            id: switcher

            width: parent.width
            height: 34
            color: Theme.raised
            options: [
                { "value": "clock", "label": "Horloge", "icon": "clock" },
                { "value": "stopwatch", "label": "Chrono", "icon": "bolt" },
                { "value": "timer", "label": "Minuteur", "icon": "bell" }
            ]
            current: root.mode
            onPicked: value => Daemon.command("chrono", "mode", [value])
        }

        // Vue Horloge
        Item {
            id: clockView

            visible: root.mode === "clock"
            width: parent.width
            implicitHeight: 64

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Column {
                    spacing: 2

                    Text {
                        text: root.clock.time ?? "00:00:00"
                        color: Theme.foreground
                        font.pixelSize: Theme.textTitle
                        font.family: Theme.displayFamily
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }

                    Text {
                        text: root.clock.date ?? ""
                        color: Theme.muted
                        font.pixelSize: Theme.textLabel
                        font.family: Theme.fontFamily
                    }
                }
            }

            Column {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                width: 90

                Text {
                    anchors.right: parent.right
                    text: `${Math.round((root.clock.day_progress ?? 0) * 100)}% journée`
                    color: Theme.muted
                    font.pixelSize: Theme.textCaption
                    font.family: Theme.fontFamily
                }

                ProgressBar {
                    width: parent.width
                    value: root.clock.day_progress ?? 0
                    fill: Theme.accent
                }
            }
        }

        // Vue Chronomètre
        Item {
            id: stopwatchView

            visible: root.mode === "stopwatch"
            width: parent.width
            implicitHeight: 64

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Symbol {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "bolt"
                    size: 26
                    color: root.stopwatch.running ? (root.stopwatch.paused ? Theme.muted : Theme.accent) : Theme.muted
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: root.stopwatch.formatted ?? "00:00.0"
                        color: Theme.foreground
                        font.pixelSize: Theme.textTitle
                        font.family: Theme.fontFamily
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }

                    Text {
                        text: {
                            if (!root.stopwatch.running) return "Prêt";
                            if (root.stopwatch.paused) return "En pause";
                            if ((root.stopwatch.lap_count ?? 0) > 0) {
                                return `Tour ${root.stopwatch.lap_count} · ${root.stopwatch.last_lap?.formatted_split ?? ""}`;
                            }
                            return "En cours";
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
                    text: "Démarrer"
                    icon: "play"
                    tone: "accent"
                    onClicked: Daemon.command("chrono", "stopwatch_start", [])
                }

                Button {
                    visible: root.stopwatch.running && !root.stopwatch.paused
                    text: "Tour"
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

        // Vue Minuteur
        Item {
            id: timerView

            visible: root.mode === "timer"
            width: parent.width
            implicitHeight: 64

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Ring {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    line: 3
                    color: root.timer.paused ? Theme.muted : Theme.accent
                    progress: root.timer.running ? (root.timer.progress ?? 1) : 1
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: root.timer.running ? (root.timer.formatted ?? "00:00") : `${root.timer.default_minutes ?? 5} min`
                        color: Theme.foreground
                        font.pixelSize: Theme.textTitle
                        font.family: Theme.fontFamily
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }

                    Text {
                        text: {
                            if (!root.timer.running) return "Prêt";
                            return root.timer.paused ? "En pause" : "Compte à rebours";
                        }
                        color: Theme.muted
                        font.pixelSize: Theme.textLabel
                        font.family: Theme.fontFamily
                    }
                }
            }

            // Boutons quand le minuteur n'est pas actif (Préréglages rapides)
            Row {
                visible: !root.timer.running
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Button {
                    text: "1m"
                    tone: "ghost"
                    onClicked: Daemon.command("chrono", "timer_start", ["1"])
                }

                Button {
                    text: "5m"
                    tone: "accent"
                    onClicked: Daemon.command("chrono", "timer_start", ["5"])
                }

                Button {
                    text: "15m"
                    tone: "ghost"
                    onClicked: Daemon.command("chrono", "timer_start", ["15"])
                }

                Button {
                    text: "25m"
                    tone: "ghost"
                    onClicked: Daemon.command("chrono", "timer_start", ["25"])
                }
            }

            // Boutons quand le minuteur est actif
            Row {
                visible: root.timer.running
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Button {
                    text: "+1m"
                    tone: "ghost"
                    onClicked: Daemon.command("chrono", "timer_add", ["1"])
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
        }
    }
}
