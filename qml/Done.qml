import QtQuick
import qs.island

// Activité présentée sur l'îlot central quand le minuteur se termine
Item {
    id: root

    property var payload: ({})

    implicitWidth: row.implicitWidth + Theme.padding * 2
    implicitHeight: 40

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 10

        Symbol {
            anchors.verticalCenter: parent.verticalCenter
            name: "bell"
            color: Theme.accent
            size: 18
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                text: root.payload.title ?? "Minuteur terminé !"
                color: Theme.foreground
                font.pixelSize: Theme.textBody
                font.family: Theme.fontFamily
                font.weight: Font.DemiBold
            }

            Text {
                visible: (root.payload.duration ?? "") !== ""
                text: root.payload.duration ?? ""
                color: Theme.muted
                font.pixelSize: Theme.textCaption
                font.family: Theme.fontFamily
            }
        }
    }
}
