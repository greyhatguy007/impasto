// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A I       F   A   C   E                                                  │
// │   assistant usage as a fuel gauge                                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// Assistant usage as a fuel gauge: F with the window untouched, E when this
// block is the biggest one on record, red when it is nearly the biggest. The
// ring is tokens against the biggest this desk has itself seen — not against
// a quota, which would be a number to keep true. With no history behind it the
// ring is the block's own elapsed time, and the line says so rather than
// quoting a share of nothing.
Instrument {
    id: face

    // The server's countdown when it has one, the block's own clock otherwise.
    readonly property string resets: AiUsageService.gatewayResets !== ""
        ? AiUsageService.gatewayResets
        : AiUsageService.resetsIn

    // Tokens, never a percentage: what this block cost to run.
    readonly property string figure: !AiUsageService.available ? "—"
        : AiUsageService.compact(AiUsageService.blockTokens)

    line: !AiUsageService.available ? "No transcripts found"
        : `${face.figure} tokens this block`
    reading: face.figure

    note: {
        if (!AiUsageService.available)
            return "no transcripts found"
        const where = AiUsageService.plan !== "" ? `on ${AiUsageService.plan}` : ""
        return [`${face.resets}`, where].filter(text => text !== "").join(" · ")
    }

    filled: true

    Gauge {
        anchors.centerIn: parent
        ink: face.ink
        size: Math.min(parent.width, parent.height)
        fraction: 1 - AiUsageService.gauge
        lowIsBad: true
        ends: ["E", "F"]

        AiMark {
            x: (parent.width - width) / 2
            y: parent.height * 0.28
            width: 22
            height: 22
            color: face.ink.text
        }
    }

    extra: [
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 4

            UsageBar {
                width: parent.width
                progress: AiUsageService.weekBarFraction
                fillColor: face.ink.accent
                trackColor: face.ink.raised
            }

            Text {
                text: !AiUsageService.available ? "—"
                    : `${AiUsageService.compact(AiUsageService.weekTokens)} this week`
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: face.ink.muted
            }
        }
    ]
}
