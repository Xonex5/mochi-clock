import QtQuick
import qs.island

// Vue Page dédiée dans le Hub pour Chrono
Item {
    id: root

    property var payload: null
    readonly property string mode: payload?.mode ?? "clock"
    readonly property var clock: payload?.clock ?? ({})
    readonly property var stopwatch: payload?.stopwatch ?? ({})
    readonly property var timer: payload?.timer ?? ({})
    readonly property var laps: stopwatch.laps ?? []

    implicitWidth: 800
    implicitHeight: 380

    Column {
        anchors.fill: parent
        spacing: 16

        // Barre d'onglets de navigation
        Segmented {
            id: nav

            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, 420)
            height: 38
            color: Theme.raised
            options: [
                { "value": "clock", "label": "Horloge", "icon": "clock" },
                { "value": "stopwatch", "label": "Chronomètre", "icon": "bolt" },
                { "value": "timer", "label": "Minuteur", "icon": "bell" }
            ]
            current: root.mode
            onPicked: value => Daemon.command("chrono", "mode", [value])
        }

        // ================= VUE HORLOGE =================
        Item {
            visible: root.mode === "clock"
            width: parent.width
            height: parent.height - nav.height - 16

            Row {
                anchors.centerIn: parent
                spacing: 48

                // Heure et date
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

                // Progression de la journée
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

                        Row {
                            width: parent.width

                            Text {
                                text: "Journée écoulée"
                                color: Theme.muted
                                font.pixelSize: Theme.textLabel
                                font.family: Theme.fontFamily
                            }

                            Item { width: 1; height: 1; Layout.fillWidth: true }

                            Text {
                                anchors.right: parent.right
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

        // ================= VUE CHRONOMÈTRE =================
        Item {
            visible: root.mode === "stopwatch"
            width: parent.width
            height: parent.height - nav.height - 16

            Row {
                anchors.fill: parent
                spacing: 24

                // Colonne principale : affichage du temps et contrôles
                Column {
                    width: parent.width * 0.48
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
                            text: "Démarrer"
                            icon: "play"
                            tone: "accent"
                            onClicked: Daemon.command("chrono", "stopwatch_start", [])
                        }

                        Button {
                            visible: root.stopwatch.running
                            text: root.stopwatch.paused ? "Reprendre" : "Pause"
                            icon: root.stopwatch.paused ? "play" : "pause"
                            tone: root.stopwatch.paused ? "accent" : "neutral"
                            onClicked: Daemon.command("chrono", "stopwatch_pause", [])
                        }

                        Button {
                            visible: root.stopwatch.running && !root.stopwatch.paused
                            text: "Tour"
                            icon: "plus"
                            tone: "neutral"
                            onClicked: Daemon.command("chrono", "stopwatch_lap", [])
                        }

                        Button {
                            visible: root.stopwatch.running
                            text: "Réinitialiser"
                            icon: "stop"
                            tone: "danger"
                            onClicked: Daemon.command("chrono", "stopwatch_reset", [])
                        }
                    }
                }

                // Colonne secondaire : Liste des tours
                Rectangle {
                    width: parent.width * 0.48
                    height: parent.height - 20
                    anchors.verticalCenter: parent.verticalCenter
                    radius: Theme.radiusLarge
                    color: Theme.surface
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Text {
                            text: `Tours enregistrés (${root.laps.length})`
                            color: Theme.muted
                            font.pixelSize: Theme.textCaption
                            font.family: Theme.fontFamily
                            font.weight: Font.DemiBold
                        }

                        Text {
                            visible: root.laps.length === 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 80
                            text: "Aucun tour enregistré"
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

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: `Tour ${modelData.index}`
                                        color: Theme.muted
                                        font.pixelSize: Theme.textLabel
                                        font.family: Theme.fontFamily
                                    }

                                    Item { width: 1; height: 1; Layout.fillWidth: true }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: totalText.left
                                        anchors.rightMargin: 16
                                        text: `+${modelData.formatted_split}`
                                        color: Theme.accent
                                        font.pixelSize: Theme.textLabel
                                        font.family: Theme.fontFamily
                                        font.features: { "tnum": 1 }
                                    }

                                    Text {
                                        id: totalText
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: parent.right
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

        // ================= VUE MINUTEUR =================
        Item {
            visible: root.mode === "timer"
            width: parent.width
            height: parent.height - nav.height - 16

            Row {
                anchors.centerIn: parent
                spacing: 36

                // Cadran avec anneau de compte à rebours
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
                            text: root.timer.paused ? "En pause" : (root.timer.running ? "En cours" : "Prêt")
                            color: Theme.muted
                            font.pixelSize: Theme.textCaption
                            font.family: Theme.fontFamily
                        }
                    }
                }

                // Contrôles et Préréglages
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    // Boutons de contrôle
                    Row {
                        spacing: 8

                        Button {
                            text: root.timer.running ? (root.timer.paused ? "Reprendre" : "Pause") : "Démarrer"
                            icon: (root.timer.running && !root.timer.paused) ? "pause" : "play"
                            tone: "accent"
                            onClicked: Daemon.command("chrono", "timer_pause", [])
                        }

                        Button {
                            visible: root.timer.running
                            text: "+1 min"
                            tone: "neutral"
                            onClicked: Daemon.command("chrono", "timer_add", ["1"])
                        }

                        Button {
                            visible: root.timer.running
                            text: "+5 min"
                            tone: "neutral"
                            onClicked: Daemon.command("chrono", "timer_add", ["5"])
                        }

                        Button {
                            visible: root.timer.running
                            text: "Arrêter"
                            icon: "stop"
                            tone: "danger"
                            onClicked: Daemon.command("chrono", "timer_stop", [])
                        }
                    }

                    // Grille de préréglages
                    Column {
                        spacing: 6

                        Text {
                            text: "Préréglages rapides :"
                            color: Theme.muted
                            font.pixelSize: Theme.textCaption
                            font.family: Theme.fontFamily
                        }

                        Grid {
                            columns: 4
                            spacing: 6

                            Repeater {
                                model: [
                                    { "label": "1 min", "val": "1" },
                                    { "label": "3 min", "val": "3" },
                                    { "label": "5 min", "val": "5" },
                                    { "label": "10 min", "val": "10" },
                                    { "label": "15 min", "val": "15" },
                                    { "label": "20 min", "val": "20" },
                                    { "label": "25 min (Pomodoro)", "val": "25" },
                                    { "label": "30 min", "val": "30" }
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
