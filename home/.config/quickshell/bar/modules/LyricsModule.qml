// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L Y R I C S   M O D U L E                                              │
// │   current lyric line · from lrclib                                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

Item {
    id: root

    implicitWidth: column.implicitWidth + 14
    implicitHeight: Theme.capsuleHeight

    ColumnLayout {
        id: column
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "󰎇"
                font.family: Theme.fontMono
                font.pixelSize: 20
                color: Theme.indicator
            }

            Text {
                Layout.fillWidth: true
                text: LyricsService.display
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: LyricsService.singing ? Theme.indicator : Theme.textMuted
                font.weight: LyricsService.singing ? Font.DemiBold : Font.Normal
            }
        }
    }
}