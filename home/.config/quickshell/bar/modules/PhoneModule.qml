// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P H O N E   M O D U L E                                                │
// │   the paired phone · its charge, its music, and what it can be asked    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"
import "../widgets"

// The phone as a control surface, in the same hand as the Bluetooth module:
// the charge ring, the phone's name, and only the actions KDE Connect says
// this pairing offers. A phone that cannot be rung — a tablet, or a pairing
// without the plugin — is not shown a ringing bell it will ignore.
Item {
    id: root

    property bool compact: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Component.onCompleted: KdeConnectService.subscribe()
    Component.onDestruction: KdeConnectService.release()

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    // Ring face; `ChipFace` draws the phone's name beside it.
    Component {
        id: chip

        Item {
            PhoneWidget {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.capsuleHeight
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

                PhoneWidget {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    size: 44
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        // The name, or the reason there is none: one line that
                        // is always about the phone this desk is paired to.
                        text: KdeConnectService.statusNote
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!KdeConnectService.reachable)
                                return KdeConnectService.available
                                    ? Tr.t("out of reach") : Tr.t("not connected")
                            if (KdeConnectService.hasBattery)
                                return `${KdeConnectService.battery}%`
                                    + (KdeConnectService.charging
                                        ? ` · ${Tr.t("charging")}` : "")
                            return KdeConnectService.type === "tablet"
                                ? Tr.t("tablet") : Tr.t("phone")
                        }
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: KdeConnectService.reachable
                            && KdeConnectService.hasBattery
                            ? KdeConnectService.tone : Theme.textMuted
                    }
                }
            }

            // The phone's music, as the desk's music while it is playing: the
            // transport here is the same one the island shows.
            RowLayout {
                Layout.fillWidth: true
                visible: MediaService.origin === "phone"
                spacing: 9

                Text {
                    Layout.fillWidth: true
                    text: MediaService.title !== "" ? MediaService.title : "Paused"
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: MediaService.title !== "" ? Theme.text : Theme.textMuted
                }

                IconButton {
                    icon: "󰓮"
                    iconSize: 12
                    onClicked: MediaService.previous()
                }

                IconButton {
                    icon: MediaService.playing ? "󰏤" : "󰐊"
                    iconSize: 12
                    onClicked: MediaService.toggle()
                }

                IconButton {
                    icon: "󰓭"
                    iconSize: 12
                    onClicked: MediaService.next()
                }
            }

            // The phone's own volume, which is the only level a bar module has
            // room for; the desk's own volume has a module of its own. The
            // reading is the phone's, so a change made there moves this track
            // too, and not only the other way round.
            SliderRow {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                visible: MediaService.origin === "phone"
                icon: "󰕾"
                value: Math.round(KdeConnectService.volume * 100)
                available: KdeConnectService.can.media
                onMoved: value => KdeConnectService.setVolume(value / 100)
            }

            // The actions this pairing actually offers.
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    // Only what this pairing actually offers, in the order a
                    // desk reaches for them: find it, poke it, take the
                    // clipboard, send one back, lock it. Sharing a file would
                    // want a chooser this module has no room for, so it is
                    // left to the phone, which already receives files over
                    // the wire on its own.
                    model: [
                        { icon: "󰇰", ask: () => KdeConnectService.ring(),
                          offer: KdeConnectService.can.ring },
                        { icon: "󰍣", ask: () => KdeConnectService.ping(Tr.t("From the desk")),
                          offer: KdeConnectService.can.ping },
                        { icon: "󰎚", ask: () => KdeConnectService.fetchClipboard(),
                          offer: KdeConnectService.can.clipboard },
                        { icon: "󰨋", ask: () => KdeConnectService.pushClipboard(),
                          offer: KdeConnectService.allowsClipboard },
                        { icon: "󰒧", ask: () => KdeConnectService.lock(),
                          offer: KdeConnectService.can.lock }
                    ]

                    IconButton {
                        required property var modelData

                        Layout.fillWidth: true
                        visible: modelData.offer
                        icon: modelData.icon
                        iconSize: 13
                        onClicked: modelData.ask()
                    }
                }
            }
        }
    }
}
