// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O D I N G   M O D U L E                                              │
// │   activity · github, leetcode, codeforces and gitlab, or all at once     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// A year of activity in one grid. The bar draws the symbol and the total for
// whatever the toggle is showing; the island opens it into the grid, with the
// toggle across the top when more than one platform has a handle.
//
// `All` adds the platforms' days together, so a busy day reads at a glance
// and the wall belongs to no single platform. The same choice is on the
// desktop widget (`SourcePicker`), and both write the one setting.
Item {
    id: root

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    // Only a choice to make when more than one platform is set.
    readonly property bool offersChoice: CodingService.platforms.length > 1

    Component.onCompleted: CodingService.subscribe()
    Component.onDestruction: CodingService.release()

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: detail
    }

    // ── DETAIL ──────────────────────────────────────────────────────────────

    Component {
        id: detail

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 6

            // The toggle, and what the reading adds up to.
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                SegmentedControl {
                    visible: root.offersChoice
                    options: CodingService.platforms.map(
                        entry => ({ id: entry.id, label: Tr.t(entry.label) }))
                    current: CodingService.platform
                    onSelected: id => CodingService.setPlatform(id)
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: CodingService.available
                    text: `${CodingService.totalLabel}`
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
            }

            ContributionGrid {
                Layout.fillWidth: true
                Layout.fillHeight: true
                weeks: CodingService.weeks
                levels: CodingService.levels
                // As many recent weeks as fit the island; the full year is the
                // widget's.
                maxWeeks: 30
                spacing: 3
            }

            // The platform drawn, and the reading's age, since it comes from
            // the network.
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: CodingService.platformName
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }

                Text {
                    visible: CodingService.age !== ""
                    text: CodingService.age
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }
            }
        }
    }
}
