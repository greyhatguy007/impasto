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

// A rolling year of practice from LeetCode or Codeforces, drawn with the same
// contribution grid as GitHub's. Desktop only (`bar: false` in the catalogue).
// When both handles are set, the segmented control switches which one is
// drawn; otherwise the configured one stands alone. Shows the reading's age,
// since it comes from the network.
Item {
    id: root

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    // The colours a cell takes, by level; the two platforms read at a glance.
    readonly property var levels: CodingService.platform === "codeforces"
        ? Theme.codeforcesLevels : Theme.leetcodeLevels

    // What the counts mean on each platform.
    readonly property string unit: CodingService.platform === "codeforces"
        ? "accepted" : "submissions"

    readonly property bool offersChoice: CodingService.configured.length > 1

    Component.onCompleted: CodingService.subscribe()
    Component.onDestruction: CodingService.release()

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: detail
    }

    Component {
        id: detail

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 13

                Text {
                    text: "󰅩"
                    font.family: Theme.fontMono
                    font.pixelSize: 28
                    color: Theme.indicator
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            text: CodingService.user !== ""
                                ? CodingService.user : CodingService.platformName
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            text: `${CodingService.totalLabel}`
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            const parts = [`${CodingService.platformName} · ${root.unit} this year`]
                            if (CodingService.streak > 0)
                                parts.push(`${CodingService.streak}-day streak`)
                            if (CodingService.age !== "")
                                parts.push(CodingService.age)
                            return parts.join(" · ")
                        }
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }

                // Only when there is a choice to make.
                SegmentedControl {
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.offersChoice
                    options: CodingService.platforms.map(
                        entry => ({ id: entry.id, label: entry.label }))
                    current: CodingService.platform
                    onSelected: id => CodingService.setPlatform(id)
                }
            }

            ContributionGrid {
                Layout.fillWidth: true
                Layout.fillHeight: true
                weeks: CodingService.weeks
                levels: root.levels
                // As many recent weeks as fit the island; the full year is the
                // widget's.
                maxWeeks: 30
                spacing: 3
            }
        }
    }
}
