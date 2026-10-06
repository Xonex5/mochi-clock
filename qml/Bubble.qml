import QtQuick
import qs.island

// La bulle affichée près de l'îlot pour le minuteur ou le chronomètre
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

        // Anneau de compte à rebours pour le minuteur
        Ring {
            visible: root.isTimer
            anchors.verticalCenter: parent.verticalCenter
            width: 15
            height: 15
            line: 2
            color: root.tint
            progress: root.payload.progress ?? 0
        }

        // Symbole pour le chronomètre
        Symbol {
            visible: !root.isTimer
            anchors.verticalCenter: parent.verticalCenter
            name: "bolt"
            size: 13
            color: root.tint
        }

        // Temps restant ou écoulé
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.payload.text ?? "00:00"
            color: root.tint
            font.pixelSize: Theme.textCaption
            font.family: Theme.fontFamily
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }
}
