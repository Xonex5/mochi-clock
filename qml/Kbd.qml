import QtQuick
import qs.island

// Sleek keyboard shortcut badge component
Rectangle {
    id: root

    property string key: ""
    property color textColor: Theme.foreground
    property color badgeColor: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
    property color borderColor: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.16)

    implicitWidth: Math.max(22, label.implicitWidth + 10)
    implicitHeight: 20
    radius: 4
    color: badgeColor
    border.width: 1
    border.color: borderColor

    Text {
        id: label
        anchors.centerIn: parent
        text: root.key
        color: root.textColor
        font.pixelSize: 10
        font.family: Theme.displayFamily
        font.weight: Font.DemiBold
    }
}
