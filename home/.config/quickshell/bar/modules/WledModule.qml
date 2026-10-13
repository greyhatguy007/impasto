// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W L E D   M O D U L E                                                  │
// │   strip lights · the stream, on and off                                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// The screen-to-light stream, as a piece. Like the night light: a click turns
// it on or off, and the detail says what the controller answered and how fast
// the frames are going. Without a host the detail says where to set one.
Item {
    id: root

    property bool compact: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Component.onCompleted: WledService.discover()

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    // Ring face. The circle is full while streaming, empty while off, and a
    // fault blinks it — a light that should be on and is not is worth looking
    // twice at.
    Component {
        id: chip

        Item {
            RingIndicator {
                id: mark

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.capsuleHeight
                progress: WledService.on ? 1 : 0
                thickness: 2.5
                trackColor: Theme.indicatorDim
                fillColor: WledService.reason !== "" ? Theme.indicatorBad
                    : WledService.tint

                Behavior on fillColor { ColorAnimation { duration: Theme.durationMedium } }

                Text {
                    anchors.centerIn: parent
                    text: WledService.icon
                    font.family: Theme.fontMono
                    font.pixelSize: Math.round(Theme.capsuleHeight * 0.38)
                    color: WledService.tint
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
                    thickness: 2.5
                    progress: WledService.on ? 1 : 0
                    trackColor: Theme.indicatorDim
                    fillColor: WledService.reason !== "" ? Theme.indicatorBad
                        : WledService.tint

                    Text {
                        anchors.centerIn: parent
                        text: WledService.icon
                        font.family: Theme.fontMono
                        font.pixelSize: 18
                        color: WledService.reason !== "" ? Theme.indicatorBad
                            : WledService.tint
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: WledService.configured
                            ? WledService.displayName : Tr.t("No host")
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        text: WledService.note()
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: WledService.reason !== "" ? Theme.indicatorBad
                            : Theme.textMuted
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                PillButton {
                    Layout.fillWidth: true
                    text: WledService.on ? Tr.t("Stop the stream")
                        : Tr.t("Stream the screen")
                    icon: WledService.on ? "󰚦" : "󰚥"
                    enabled: WledService.configured
                    onClicked: WledService.toggle()
                }

                PillButton {
                    text: Tr.t("Settings")
                    icon: "󰍛"
                    onClicked: ModuleService.requestPanel("integrations")
                }
            }
        }
    }
}
