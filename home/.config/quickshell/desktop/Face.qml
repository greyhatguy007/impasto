// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   F   A   C   E                                                          │
// │   picks a widget face by module, family and theme                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../engine"
import "../services"
import "./faces"
import "./faces/analogue"

// Picks the face for a module, a family (size) and a theme. Modern has one
// registry per family, falling back within that registry for modules without a
// row; Analogue has a single registry whose faces lay themselves out at any
// size. Notes always use NoteFace, and the spectrum is its bars in either
// theme. Faces read their colours from the widget's resolved `ink`.
//
// A widget defined in a file is none of these: it carries its own view per
// family, so `CustomFace` draws it in either theme.
Item {
    id: root

    property string moduleId: ""
    property string family: "4x2"
    property string theme: DesktopService.themeOf(null)
    property var ink: DesktopService.inkFor(null)

    // The desktop row, for faces that draw something the row names (a note,
    // a picture). Null for tray tiles, which show the front of the deck or
    // an empty frame.
    property var row: null

    readonly property bool analogue: root.theme === "analogue"
        && root.moduleId !== "notes" && root.moduleId !== "spectrum"

    // A widget defined in a file brings its own view for each family, so it is
    // drawn by the engine rather than by one of the registries below.
    readonly property bool custom: WidgetService.widgetOf(root.moduleId) !== ""

    Loader {
        anchors.fill: parent
        sourceComponent: {
            if (root.custom)
                return customFace
            if (root.analogue)
                return analogue
            if (root.family === "2x2")
                return squares
            if (root.family === "4x4")
                return larges
            if (root.family === "8x2")
                return bands
            return wides
        }
    }

    Component {
        id: customFace
        CustomFace {
            moduleId: root.moduleId
            family: root.family
            ink: root.ink
            row: root.row
        }
    }

    Component {
        id: analogue
        Analogue { moduleId: root.moduleId; family: root.family; ink: root.ink; row: root.row }
    }

    Component {
        id: squares
        Squares { moduleId: root.moduleId; ink: root.ink; row: root.row }
    }

    Component {
        id: wides
        Wides { moduleId: root.moduleId; ink: root.ink; row: root.row }
    }

    Component {
        id: larges
        Larges { moduleId: root.moduleId; ink: root.ink; row: root.row }
    }

    Component {
        id: bands
        Bands { moduleId: root.moduleId; ink: root.ink; row: root.row }
    }
}
