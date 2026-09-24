// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O D I N G   M O D U L E                                              │
// │   leetcode or codeforces · a year of practice when open                  │
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

    // Default implicit size for the chip view; will expand when detail is shown.
    implicitWidth: Theme.capsuleHeight * 2
    implicitHeight: Theme.capsuleHeight

    // The colours a cell takes, by level; the two platforms read at a glance.
    readonly property var levels: CodingService.platform === "codeforces"
        ? Theme.codeforcesLevels : Theme.leetcodeLevels

    // Only a choice to make when both handles are set.
    readonly property bool offersChoice: CodingService.configured.length > 1

    // Show detail when width exceeds threshold (i.e., when opened in the island).
    property bool showDetail: width > Theme.capsuleHeight * 3

    Component.onCompleted: CodingService.subscribe()
    Component.onDestruction: CodingService.release()

    Loader {
        anchors.fill: parent
        sourceComponent: showDetail ? detail : chip
    }

    // ── CHIP VIEW ───────────────────────────────────────────────────────────
    // Shows a simple symbol and total active days (or streak) for the bar.
    Component {
        id: chip
        RowLayout {
            spacing: 4
            Text {
                text: "</>"
                font.family: Theme.fontMono
                font.pixelSize: 16
                color: Theme.indicator
            }
            Text {
                text: CodingService.total
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: CodingService.available ? Theme.text : Theme.textMuted
                // If no data yet, show a placeholder.
                visible: CodingService.available || CodingService.total > 0
            }
            // Show a waiting indicator when loading.
            Text {
                text: "–"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
                visible: !CodingService.available && CodingService.total === 0
            }
        }
    }

    // ── DETAIL VIEW ─────────────────────────────────────────────────────────
    // The contribution grid shown in the island.
    Component {
        id: detail
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 6

            // Platform selector (if both configured).
            RowLayout {
                visible: root.offersChoice
                spacing: 12

                Text {
                    text: "Platform"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }

                // Only when there is a choice to make.
                SegmentedControl {
                    options: CodingService.platforms.map(
                        entry => ({ id: entry.id, label: entry.label }))
                    current: CodingService.platform
                    onSelected: id => CodingService.setPlatform(id)
                }
            }

            ContributionGrid {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                weeks: CodingService.weeks
                levels: root.levels
                // As many recent weeks as fit the island; the full year is the
                // widget's.
                maxWeeks: 30
                spacing: 3
            }

            // Shows the reading's age, since it comes from the network.
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: CodingService.age !== "" ? CodingService.age : ""
                visible: text !== ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmaller
                color: Theme.textMuted
            }
        }
    }
}