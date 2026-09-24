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
    implicit width: Theme.capsuleHeight * 2
    implicit height: Theme.capsuleHeight

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

                ComboBox {
                    id: platformBox
                    model: CodingService.platforms.map(function(p) { return p.label })
                    currentIndex: CodingService.platforms.findIndex(function(p) { return p.id === CodingService.platform })
                    onCurrentIndexChanged: CodingService.platform = CodingService.platforms[currentIndex].id
                }
            }

            ContributionGrid {
                id: grid
                Layout.fillWidth: true
                levels: root.levels
                unit: root.unit
                grid: CodingService.grid
                total: CodingService.total
                streak: CodingService.streak
                today: CodingService.today
                busiest: CodingService.busiest
                // Show the age of the data.
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: {
                        var age = Math.floor((Date.now() - CodingService.updatedAt) / 1000);
                        if (age < 60) return "just now";
                        if (age < 3600) return Math.floor(age / 60) + "m";
                        if (age < 86400) return Math.floor(age / 3600) + "h";
                        return Math.floor(age / 86400) + "d";
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmaller
                    color: Theme.textMuted
                }
            }
        }
    }
}