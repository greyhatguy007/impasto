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

// The phone as a control surface, in the same hand as the battery module: the
// charge ring beside the charge, the phone's state and kind as the figures
// below, and only the actions KDE Connect says this pairing offers. A phone
// that cannot be rung — a tablet, or a pairing without the plugin — is not
// shown a ringing bell it will ignore.
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

            // The charge ring and the number, in the battery module's exact
            // hand: the ring, then the charge as a headline figure with the
            // state under it. The phone's own name goes in the figures below
            // rather than above, so a desk with a laptop and a phone on it
            // reads the two charge lines the same way.
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
                        text: KdeConnectService.reachable
                                && KdeConnectService.hasBattery
                            ? `${KdeConnectService.battery}%`
                            : KdeConnectService.reachable
                                ? (KdeConnectService.type === "tablet"
                                    ? Tr.t("tablet") : Tr.t("phone"))
                                : "—"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: KdeConnectService.reachable
                            && KdeConnectService.hasBattery
                            ? KdeConnectService.tone : Theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        // The name, or the reason there is none: one line that
                        // is always about the phone this desk is paired to.
                        text: KdeConnectService.statusNote
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }
            }

            // What the phone is, and what it is doing — the two figures the
            // battery module shows for a cell, asked of a phone instead.
            RowLayout {
                Layout.fillWidth: true
                visible: KdeConnectService.available
                spacing: 14

                Figure {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: "STATE"
                    value: !KdeConnectService.reachable ? Tr.t("asleep")
                        : KdeConnectService.charging ? Tr.t("charging")
                        : KdeConnectService.low ? Tr.t("low")
                        : Tr.t("idle")
                    note: KdeConnectService.charging
                        ? Tr.t("going in") : Tr.t("coming out")
                    valueColor: KdeConnectService.reachable
                        ? KdeConnectService.tone : Theme.textMuted
                }

                Figure {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: Tr.t("Signal")
                    value: KdeConnectService.reachable && KdeConnectService.network
                        ? (KdeConnectService.network.name !== ""
                            ? KdeConnectService.network.name
                            : KdeConnectService.network.type)
                        : "—"
                    note: KdeConnectService.reachable && KdeConnectService.network
                        ? `${KdeConnectService.network.strength}% ${Tr.t("strong")}`
                        : Tr.t("no cellular report")
                }

                Figure {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: Tr.t("Phone")
                    value: KdeConnectService.type === "tablet"
                        ? Tr.t("tablet") : Tr.t("phone")
                    note: KdeConnectService.notifications > 0
                        ? `${KdeConnectService.notifications} ${Tr.t("notifications")}`
                        : (KdeConnectService.hasBattery
                            ? Tr.t("battery reported") : Tr.t("no battery report"))
                }
            }

            // What the phone will do when asked, with a word over each button
            // so a glyph is never the only thing explaining itself.
            //
            // The phone's own music is deliberately not here: the desk's music
            // widget already plays the phone's track as its own, so a second
            // transport in this card would be the same thing twice — and it
            // fought the lyrics the player draws. Only what KDE Connect does
            // and the player does not is left.
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
                        { icon: "󰇰", hint: Tr.t("Ring the phone"),
                          ask: () => KdeConnectService.ring(),
                          offer: KdeConnectService.can.ring },
                        { icon: "󰍣", hint: Tr.t("Send a ping"),
                          ask: () => KdeConnectService.ping(Tr.t("From the desk")),
                          offer: KdeConnectService.can.ping },
                        { icon: "󰎚", hint: Tr.t("Take the phone's clipboard"),
                          ask: () => KdeConnectService.fetchClipboard(),
                          offer: KdeConnectService.can.clipboard },
                        { icon: "󰨋", hint: Tr.t("Send this desk's clipboard"),
                          ask: () => KdeConnectService.pushClipboard(),
                          offer: KdeConnectService.allowsClipboard },
                        { icon: "󰒧", hint: Tr.t("Lock the phone"),
                          ask: () => KdeConnectService.lock(),
                          offer: KdeConnectService.can.lock }
                    ]

                    IconButton {
                        required property var modelData

                        Layout.fillWidth: true
                        visible: modelData.offer
                        icon: modelData.icon
                        iconSize: 13
                        hint: modelData.hint
                        onClicked: modelData.ask()
                    }
                }
            }
        }
    }
}
