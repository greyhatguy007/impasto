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

    // The bar and a desktop fallback both build this module, so it subscribes
    // itself: nothing is fetched without a watcher, and MPRIS position — which
    // the line is found by — is only polled while something holds a
    // subscription.
    Component.onCompleted: {
        MediaService.subscribe()
        LyricsService.subscribe()
    }
    Component.onDestruction: {
        MediaService.release()
        LyricsService.release()
    }

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