// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P   H   O   N   E       F   A   C   E                                  │
// │   the paired phone as a battery · the ring fills as it charges          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// The phone as its own shape: an outline, a charge filling from the bottom, and
// the percentage over it. A notch at the top is the earpiece, so the face reads
// as a phone and not as a second battery — which is what a desk with both a
// laptop battery and a phone battery on it otherwise looks like.
Instrument {
    id: face

    line: KdeConnectService.available ? KdeConnectService.name
        : KdeConnectService.statusNote
    reading: KdeConnectService.reachable && KdeConnectService.hasBattery
        ? `${KdeConnectService.battery}%` : "—"
    note: KdeConnectService.reachable
        ? (KdeConnectService.charging
            ? `charging · ${KdeConnectService.name}`
            : KdeConnectService.chargeNote)
        : KdeConnectService.statusNote

    Item {
        id: plate

        anchors.fill: parent
        readonly property real side: Math.min(width, height)
        readonly property real body: side * 0.34

        // The outline, with a notch rather than a camera hole: a rounded
        // rectangle with a slot cut out of the top edge. The line is the
        // outline's own colour, named once so the notch cannot drift from it.
        Rectangle {
            id: shell

            readonly property color line: KdeConnectService.available
                ? face.ink.accent : face.ink.dim

            anchors.centerIn: parent
            width: plate.body
            height: plate.body * 1.9
            radius: plate.body * 0.18
            color: "transparent"
            border.width: 2
            border.color: shell.line
            opacity: KdeConnectService.available ? 1 : 0.5

            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.34
                height: 1.5
                color: shell.line
            }
        }

        // The charge, as a fill clipped to the shell's outline so the bottom
        // corners come with it.
        Item {
            id: level

            anchors.fill: shell
            visible: KdeConnectService.available && KdeConnectService.hasBattery
            clip: true

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * KdeConnectService.charge
                color: KdeConnectService.tone
                opacity: 0.35

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.durationMedium
                        easing.type: Theme.easing
                    }
                }
            }
        }

        // The bolt while the phone is charging: the one glyph about the
        // phone itself that the ring cannot say.
        Text {
            anchors.centerIn: parent
            text: KdeConnectService.charging ? "󰚦" : ""
            font.family: Theme.fontMono
            font.pixelSize: Math.round(plate.side * 0.22)
            color: KdeConnectService.available ? face.ink.accent : face.ink.muted
            visible: text !== ""
        }
    }
}
