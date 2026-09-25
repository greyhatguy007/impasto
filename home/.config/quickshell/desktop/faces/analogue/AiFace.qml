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

// Assistant usage as a fuel gauge: F with the quota untouched, E when it is
// spent, red at the empty end. The ring is measured against the limit in the
// settings; with no limit set it shows the block's own elapsed time, which is
// a guess, and the line says so rather than quoting a percentage of nothing.
Instrument {
    id: face

    readonly property string figure: !AiUsageService.available ? "—"
        : AiUsageService.sessionMeasured
        ? AiUsageService.percent(AiUsageService.sessionFraction)
        : AiUsageService.compact(AiUsageService.blockTokens)

    line: !AiUsageService.available ? "No usage found"
        : (AiUsageService.sessionMeasured
            ? `${face.figure} of the block`
            : `${face.figure} this block`)
    reading: face.figure
    note: !AiUsageService.available ? "no usage found"
        : AiUsageService.sessionMeasured
        ? `of the block · ${AiUsageService.resetsIn}`
        : `this block · ${AiUsageService.resetsIn}`
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
                text: AiUsageService.weeklyMeasured
                    ? `${AiUsageService.percent(AiUsageService.weeklyFraction)} of the week`
                    : "this week"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: face.ink.muted
            }
        }
    ]
}
