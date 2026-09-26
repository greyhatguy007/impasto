// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P H O N E   W I D G E T                                                 │
// │   the phone's charge as a ring · its music and its own actions inside    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../../components"

// The paired phone's charge as a ring, in the same hand as the battery
// widget, so a desk with a laptop and a phone on it can read both. The
// middle says what the phone is doing: its charge, or a bolt while charging.
// The phone's music is the music widget's business, not this ring's.
//
// A phone that reports no battery still shows a track rather than a lie, and
// the glyph in the middle is the phone's own.
RingIndicator {
    id: root

    // Smaller inside the island, where the capsule's edge would clip it.
    property real size: Theme.capsuleHeight

    // A desktop face passes its own ink so the ring reads on its background.
    property color glyphColor: Theme.indicator
    property color track: Theme.indicatorDim

    implicitWidth: root.size
    implicitHeight: root.size

    progress: KdeConnectService.hasBattery ? KdeConnectService.charge : 0
    thickness: 2.5

    trackColor: root.track
    // A phone that has gone to sleep draws as the empty ring it is: paired,
    // and saying nothing.
    fillColor: KdeConnectService.reachable
        ? KdeConnectService.tone : root.track

    Behavior on fillColor { ColorAnimation { duration: Theme.durationMedium } }

    Text {
        anchors.centerIn: parent
        text: KdeConnectService.reachable && KdeConnectService.charging ? "󰚦"
            : (KdeConnectService.hasBattery ? "󰓢" : "󰒐")
        font.family: Theme.fontMono
        font.pixelSize: Math.round(root.size * 0.44)
        color: KdeConnectService.reachable
            ? (KdeConnectService.hasBattery ? KdeConnectService.tone : root.glyphColor)
            : root.track
    }
}
