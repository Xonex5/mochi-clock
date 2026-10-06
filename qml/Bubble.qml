import QtQuick
import qs.island

// Island bubble for active countdown timer or stopwatch
Item {
    id: root

    property var payload: ({})
    readonly property bool isTimer: payload.kind === "timer"
    readonly property bool paused: payload.paused ?? false
    readonly property color tint: paused ? Theme.muted : Theme.accent

    implicitWidth: row.implicitWidth + 12
    implicitHeight: 26

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6

        // Countdown ring for timer
        Ring {
            visible: root.isTimer
            anchors.verticalCenter: parent.verticalCenter
            width: 15
            height: 15
            line: 2
            color: root.tint
            progress: root.payload.progress ?? 0
        }

        // Icon for stopwatch
        Symbol {
            visible: !root.isTimer
            anchors.verticalCenter: parent.verticalCenter
            name: "bolt"
            size: 13
            color: root.tint
        }

        // Time text
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.payload.text ?? "00:00"
            color: root.tint
            font.pixelSize: Theme.textCaption
            font.family: Theme.fontFamily
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        // Multi-timer badge (+1, +2...)
        Text {
            visible: root.isTimer && (root.payload.count ?? 1) > 1
            anchors.verticalCenter: parent.verticalCenter
            text: `+${(root.payload.count ?? 1) - 1}`
            color: Theme.muted
            font.pixelSize: Theme.textCaption * 0.85
            font.family: Theme.fontFamily
            font.weight: Font.Bold
        }
    }
}
