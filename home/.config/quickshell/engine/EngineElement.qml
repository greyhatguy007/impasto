// ╭──────────────────────────────────────────────────────────────────────────╮
// │   E N G I N E   ·   e l e m e n t                                        │
// │   one piece of a view · a leaf, or a box of its own                      │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "Engine.js" as Engine

// Draws one element of a definition's view: a leaf here, a container in
// `EngineBox.qml`. The two files are what let a view nest — a component that
// instantiates itself is refused by QML, but a box of elements and an element
// in a box are two files and are fine.
Item {
    id: root

    property var spec: null
    property var values: ({})
    property var samples: ({})
    property var ink: null
    property real base: 22
    property string module: ""

    readonly property string kind: root.spec ? root.spec.kind : ""
    readonly property bool container: root.kind === "row" || root.kind === "column"
        || root.kind === "grid"

    visible: root.spec !== null
    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight

    Loader {
        id: body

        anchors.fill: parent
        sourceComponent: root.componentFor(root.kind)
    }

    function componentFor(kind: string): var {
        switch (kind) {
        case "text": return textLeaf
        case "bar": return barLeaf
        case "gauge": return gaugeLeaf
        case "chart": return chartLeaf
        case "icon": return iconLeaf
        case "button": return buttonLeaf
        case "divider": return dividerLeaf
        case "spacer": return spacerLeaf
        case "row":
        case "column":
        case "grid": return box
        }
        return null
    }

    Component {
        id: box

        EngineBox {
            spec: root.spec
            values: root.values
            samples: root.samples
            ink: root.ink
            base: root.base
            module: root.module
        }
    }

    Component {
        id: textLeaf
        EngineText { spec: root.spec; values: root.values; ink: root.ink; base: root.base }
    }

    Component {
        id: barLeaf
        EngineBar { spec: root.spec; values: root.values; ink: root.ink; base: root.base }
    }

    Component {
        id: gaugeLeaf
        EngineGauge { spec: root.spec; values: root.values; ink: root.ink; base: root.base }
    }

    Component {
        id: chartLeaf
        EngineChart {
            spec: root.spec
            values: root.values
            samples: root.samples
            ink: root.ink
            base: root.base
        }
    }

    Component {
        id: iconLeaf
        EngineIcon { spec: root.spec; ink: root.ink; base: root.base }
    }

    Component {
        id: buttonLeaf
        EngineButton { spec: root.spec; ink: root.ink; base: root.base; module: root.module }
    }

    Component {
        id: dividerLeaf
        EngineDivider { spec: root.spec; ink: root.ink }
    }

    Component {
        id: spacerLeaf
        Item { implicitWidth: 0; implicitHeight: 0 }
    }
}
