// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   O M N I   R O U T E       F   A   C   E                                │
// │   the gateway as a needle gauge · success, trend, busiest models         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// The gateway as a gauge: the needle sits at the share of requests that
// succeeded, red when it falls. The trend runs under it on the wide faces, so
// the reading and where it has been are in one object.
Instrument {
    id: face

    readonly property bool ready: OmniRouteService.available

    line: !face.ready ? OmniRouteService.statusNote
        : `${OmniRouteService.compact(OmniRouteService.tokens)} tokens · ${OmniRouteService.money(OmniRouteService.cost)}`
    reading: face.ready ? `${Math.round(OmniRouteService.success)}%` : "—"
    note: !face.ready ? OmniRouteService.statusNote
        : `${OmniRouteService.compact(OmniRouteService.requests)} requests · ${OmniRouteService.modelCount} models`

    filled: true

    Gauge {
        anchors.centerIn: parent
        ink: face.ink
        size: Math.min(parent.width, parent.height)
        fraction: OmniRouteService.quality
        warns: true
        lowIsBad: true
        ends: ["0", "100"]

        Text {
            x: (parent.width - width) / 2
            y: parent.height * 0.24
            text: "󰚩"
            font.family: Theme.fontMono
            font.pixelSize: 20
            color: face.ink.text
        }
    }

    extra: [
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 4

            Sparkline {
                width: parent.width
                height: 28
                visible: OmniRouteService.trend.length > 1
                values: OmniRouteService.trendTokens
                maximum: 0
                stroke: face.ink.accent
            }

            Text {
                width: parent.width
                text: {
                    const top = OmniRouteService.models[0]
                    if (!face.ready || !top)
                        return ""
                    return `${top.model} · ${OmniRouteService.compact(top.tokens)}`
                }
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: face.ink.muted
            }
        }
    ]
}
