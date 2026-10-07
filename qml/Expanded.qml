import QtQuick
import qs.island

// Expanded view for the Dynamic Island (Timer, Stopwatch, or Alert)
Item {
    id: root

    property var payload: ({})
    readonly property string kind: payload?.kind ?? "timer"
    readonly property string text: payload?.text ?? ""
    readonly property string label: payload?.label ?? ""
    readonly property string title: payload?.title ?? ""
    readonly property string duration: payload?.duration ?? ""
    readonly property bool paused: payload?.paused ?? false
    readonly property real progress: payload?.progress ?? 0

    implicitWidth: 320
    implicitHeight: mainColumn.implicitHeight + Theme.padding * 2

    Column {
        id: mainColumn

        anchors.fill: parent
        anchors.margins: Theme.padding
        spacing: 12

        // When displaying a finished timer alert
        Item {
            visible: root.title !== ""
            width: parent.width
            implicitHeight: alertCol.implicitHeight

            Column {
                id: alertCol
                width: parent.width
                spacing: 8

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Symbol {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "bell"
                        size: 20
                        color: Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.title
                        color: Theme.foreground
                        font.pixelSize: Theme.textTitle
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                    }
                }

                Text {
                    visible: root.duration !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.duration
                    color: Theme.muted
                    font.pixelSize: Theme.textBody
                    font.family: Theme.fontFamily
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Button {
                        text: "Restart"
                        tone: "accent"
                        onClicked: Daemon.command("chrono", "timer_start", [root.payload?.duration_arg ?? "5m", root.payload?.label ?? ""])
                    }

                    Button {
                        text: "+5m"
                        tone: "neutral"
                        onClicked: Daemon.command("chrono", "timer_start", ["5m", root.payload?.label ?? ""])
                    }
                }
            }
        }

        // Active Timer Expanded View
        Item {
            visible: root.title === "" && root.kind === "timer"
            width: parent.width
            implicitHeight: timerRow.implicitHeight

            Row {
                id: timerRow
                width: parent.width
                spacing: 14

                Ring {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: 48
                    line: 4
                    color: root.paused ? Theme.muted : Theme.accent
                    progress: root.progress
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 48 - 14
                    spacing: 2

                    Text {
                        text: root.text !== "" ? root.text : "00:00"
                        color: Theme.foreground
                        font.pixelSize: Theme.textDisplay * 0.9
                        font.family: Theme.displayFamily
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                    }

                    Text {
                        text: root.label !== "" ? root.label : (root.paused ? "Paused" : "Countdown")
                        color: Theme.muted
                        font.pixelSize: Theme.textLabel
                        font.family: Theme.fontFamily
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // Active Stopwatch Expanded View
        Item {
            visible: root.title === "" && root.kind === "stopwatch"
            width: parent.width
            implicitHeight: swRow.implicitHeight

            Row {
                id: swRow
                width: parent.width
                spacing: 14

                Symbol {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "clock"
                    size: 32
                    color: root.paused ? Theme.muted : Theme.accent
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 32 - 14
                    spacing: 2

                    Text {
                        text: root.text !== "" ? root.text : "00:00.0"
                        color: Theme.foreground
                        font.pixelSize: Theme.textDisplay * 0.9
                        font.family: Theme.displayFamily
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                    }

                    Text {
                        text: root.paused ? "Paused" : "Running"
                        color: Theme.muted
                        font.pixelSize: Theme.textLabel
                        font.family: Theme.fontFamily
                    }
                }
            }
        }

        // Action Buttons Row for Timer
        Row {
            visible: root.title === "" && root.kind === "timer"
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Button {
                text: root.paused ? "Resume" : "Pause"
                icon: root.paused ? "play" : "pause"
                tone: root.paused ? "accent" : "neutral"
                onClicked: Daemon.command("chrono", "timer_pause", [])
            }

            Button {
                text: "+1m"
                tone: "neutral"
                onClicked: Daemon.command("chrono", "timer_add", ["1m"])
            }

            Button {
                text: "Stop"
                icon: "stop"
                tone: "danger"
                onClicked: Daemon.command("chrono", "timer_stop", [])
            }
        }

        // Action Buttons Row for Stopwatch
        Row {
            visible: root.title === "" && root.kind === "stopwatch"
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Button {
                text: root.paused ? "Resume" : "Pause"
                icon: root.paused ? "play" : "pause"
                tone: root.paused ? "accent" : "neutral"
                onClicked: Daemon.command("chrono", "stopwatch_pause", [])
            }

            Button {
                visible: !root.paused
                text: "Lap"
                icon: "plus"
                tone: "neutral"
                onClicked: Daemon.command("chrono", "stopwatch_lap", [])
            }

            Button {
                text: "Reset"
                icon: "stop"
                tone: "danger"
                onClicked: Daemon.command("chrono", "stopwatch_reset", [])
            }
        }
    }
}
