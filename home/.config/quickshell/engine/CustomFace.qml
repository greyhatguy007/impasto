// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C U S T O M   F A C E                                              │
// │   draws a widget that was defined in a file                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../services"
import "../theme"

// The one face custom widgets need: the shell's built-ins have a face per
// theme and family, while a definition carries its own view for each family
// and for the island's detail — so this draws whatever the file said, at the
// size it was given.
//
// Roles resolve through `ink`, which the desktop fills with `inkFor`; the
// island passes nothing and gets the island's own palette. A definition
// therefore names `accent` or `muted` and never a colour, and the wallpaper
// keeps its say.
Item {
    id: root

    property string moduleId: ""
    // One of the four families, or `island` for the bar's detail.
    property string family: "4x2"
    property var row: null

    property var ink: ({
        ground: Theme.island, border: Theme.islandBorder,
        text: Theme.text, muted: Theme.textMuted,
        accent: Theme.accent, accentText: Theme.accentText,
        raised: Theme.islandSurfaceHover, dim: Theme.indicatorDim,
        good: Theme.indicatorGood, warn: Theme.indicatorWarn, bad: Theme.indicatorBad
    })

    readonly property string widget: WidgetService.widgetOf(root.moduleId)
    readonly property bool island: root.family === "island"
    readonly property var readings: WidgetService.readings[root.widget] ?? ({})
    readonly property var samples: WidgetService.history[root.widget] ?? ({})
    readonly property string failure: WidgetService.failureOf(root.moduleId)

    readonly property var items: root.island
        ? (WidgetService.islandOf(root.moduleId)?.detail ?? [])
        : WidgetService.viewOf(root.moduleId, root.family)

    // A widget that has never been answered has nothing to draw: if something
    // went wrong, that is the whole of what there is to say.
    readonly property bool silent: root.failure !== ""
        && Object.keys(root.readings).length === 0

    // What a text without a `size:` gets, so a definition says what it means
    // rather than a number for each family.
    readonly property real base: ({
        "2x2": 30, "4x2": 22, "4x4": 26, "8x2": 20, island: 20
    })[root.family] ?? 22

    // The built-in faces sit 14 px inside a capsule; the island's own detail
    // has a tighter one.
    readonly property int pad: root.island ? 6 : 14

    Item {
        anchors.fill: parent
        anchors.margins: root.pad

        visible: !root.silent

        // A view is a list, drawn top to bottom; the engine's column is what
        // puts it there, so a definition can nest as deep as it likes.
        EngineElement {
            anchors.fill: parent
            spec: ({ kind: "column", gap: 6, children: root.items })
            values: root.readings
            samples: root.samples
            ink: root.ink
            base: root.base
            module: root.moduleId
        }
    }

    // Nothing has been answered yet and something went wrong: the reason sits
    // in the widget rather than a row of dashes that says nothing about why.
    Text {
        anchors.centerIn: parent
        width: Math.max(20, parent.width - 20)
        visible: root.silent
        text: root.failure
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pixelSize: 12
        color: root.ink.muted
    }
}
