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

// Token and message counts for the current five-hour block and the last seven
// days, read from the local transcripts of whichever assistant the settings
// name. A percentage is shown only against a quota the settings set; the ring
// is time elapsed in the block until then.
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

    // Ring face: the block's clock. `ChipFace` draws the figure.
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
                        // The assistant the settings name, or every one found
                        // on disk when they name none in particular.
                        text: AiUsageService.label !== ""
                            ? AiUsageService.label : "Assistants"
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        // A block runs five hours from its first message, so
                        // the reset time is exact.
                        text: AiUsageService.available
                            ? `Session ${AiUsageService.resetsIn}`
                            : "No transcripts on disk"
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Repeater {
                    model: [
                        {
                            label: "SESSION",
                            tokens: AiUsageService.blockTokens,
                            count: AiUsageService.blockMessages,
                            fraction: AiUsageService.sessionFraction,
                            measured: AiUsageService.sessionMeasured
                        },
                        {
                            label: "WEEK",
                            tokens: AiUsageService.weekTokens,
                            count: AiUsageService.weekMessages,
                            fraction: AiUsageService.weeklyFraction,
                            measured: AiUsageService.weeklyMeasured
                        }
                    ]

                    ColumnLayout {
                        id: column

                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 5

                        Figure {
                            Layout.fillWidth: true
                            label: column.modelData.label
                            value: `${AiUsageService.compact(column.modelData.tokens)} tokens`
                            // Messages as the note: they tell a long session
                            // apart from one large file.
                            note: AiUsageService.messages(column.modelData.count)
                        }

                        // Only against a quota the settings set.
                        RowLayout {
                            Layout.fillWidth: true
                            visible: column.modelData.measured
                            spacing: 7

                            UsageBar {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 40
                                implicitHeight: 5
                                progress: column.modelData.fraction
                                fillColor: AiUsageService.tone
                            }

                            Text {
                                text: AiUsageService.percent(column.modelData.fraction)
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                color: Theme.textMuted
                            }
                        }
                    }
                }
            }
        }
    }
}
