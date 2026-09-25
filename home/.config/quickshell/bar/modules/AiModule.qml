// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A I   M O D U L E                                                      │
// │   assistant usage · current block and week                               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// What the assistant has been used for: the tokens in the current five-hour
// block and the tokens in the last seven days, read from the local transcripts
// of whichever assistant the settings name. No quota is asked for and no
// percentage is claimed — the ring and the bars are each window against the
// biggest this desk has itself seen, which is a reading of the same
// transcripts rather than a limit somebody has to keep true.
Item {
    id: root

    property bool compact: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Component.onCompleted: AiUsageService.subscribe()
    Component.onDestruction: AiUsageService.release()

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    // Ring face: the block against the busiest block on record, or its own
    // clock when there is no history yet. `ChipFace` draws the figure.
    Component {
        id: chip

        Item {
            RingIndicator {
                id: mark

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.capsuleHeight
                height: Theme.capsuleHeight
                thickness: 2.5
                progress: AiUsageService.gauge
                trackColor: Theme.indicatorDim
                fillColor: AiUsageService.tone

                Behavior on fillColor { ColorAnimation { duration: Theme.durationMedium } }

                AiMark {
                    anchors.centerIn: parent
                    width: Math.round(Theme.capsuleHeight * 0.53)
                    height: Math.round(Theme.capsuleHeight * 0.53)
                    color: Theme.indicator
                }
            }
        }
    }

    Component {
        id: detail

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 13

                RingIndicator {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    thickness: 3
                    progress: AiUsageService.gauge
                    trackColor: Theme.indicatorDim
                    fillColor: AiUsageService.tone

                    Behavior on fillColor { ColorAnimation { duration: Theme.durationMedium } }

                    AiMark {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        color: Theme.indicator
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        // The tokens themselves, in the same size and weight
                        // the battery module gives its charge.
                        text: AiUsageService.available
                            ? `${AiUsageService.compact(AiUsageService.blockTokens)} tokens`
                            : "—"
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        // Which window this is, and when it rolls: the
                        // gateway's own reset time when it will say, the
                        // block's clock otherwise.
                        text: {
                            if (!AiUsageService.available)
                                return "No transcripts on disk"
                            const window = Tr.t("this block")
                            return AiUsageService.gatewayResets !== ""
                                ? `${window} · ${AiUsageService.gatewayResets}`
                                : AiUsageService.resetsIn !== ""
                                ? `${window} · ${AiUsageService.resetsIn}`
                                : window
                        }
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }
            }

            // One figure per window, in the battery module's hand: a caption,
            // the number, and what it is a count of. The bar under each is
            // that window against the biggest one on record, so a bar with
            // any height means this desk has seen a bigger one.
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Repeater {
                    model: [
                        {
                            label: "BLOCK",
                            tokens: AiUsageService.blockTokens,
                            count: AiUsageService.blockMessages,
                            share: AiUsageService.blockShare,
                            peak: AiUsageService.peakBlockTokens,
                            window: Tr.t("this block")
                        },
                        {
                            label: "WEEK",
                            tokens: AiUsageService.weekTokens,
                            count: AiUsageService.weekMessages,
                            share: AiUsageService.weekShare,
                            peak: AiUsageService.peakWeekTokens,
                            window: Tr.t("this week")
                        }
                    ]

                    ColumnLayout {
                        id: column

                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 6

                        Figure {
                            Layout.fillWidth: true
                            label: column.modelData.label
                            value: AiUsageService.available
                                ? AiUsageService.compact(column.modelData.tokens) : "—"
                            // Messages as the note: they tell a long session
                            // apart from one large file.
                            note: AiUsageService.available
                                ? AiUsageService.messages(column.modelData.count)
                                : Tr.t("nothing read yet")
                        }

                        UsageBar {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 40
                            implicitHeight: 5
                            // With no history to measure against, the bar is
                            // empty rather than full, which is the difference
                            // between "the biggest on record" and a guess.
                            progress: column.modelData.share
                            fillColor: AiUsageService.tone
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: column.modelData.peak > 0
                                    && AiUsageService.available
                            text: column.modelData.share > 0
                                ? Tr.t("%1 of the busiest on record").arg(
                                    AiUsageService.percent(column.modelData.share))
                                : ""
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.textMuted
                        }
                    }
                }
            }
        }
    }
}
