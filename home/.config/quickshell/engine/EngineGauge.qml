// ╭──────────────────────────────────────────────────────────────────────────╮
// │   E N G I N E   ·   g a u g e                                            │
// │   one reading, as a ring · whatever the definition puts in the middle    │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../components"
import "../theme"
import "Engine.js" as Engine

Item {
    id: root

    property var spec: null
    property var values: ({})
    property var ink: null
    property real base: 22

    // Undefined until the source first answers, which is an empty ring rather
    // than a number QML cannot assign.
    readonly property real reading: Engine.reading(root.spec ? root.spec.value : null,
                                                   root.values) ?? 0
    readonly property real progress: Engine.fraction(root.reading, root.spec ? root.spec.min : 0,
                                                     root.spec ? root.spec.max : 100)
    readonly property int thickness: root.spec && root.spec.thickness > 0
        ? root.spec.thickness : 10
    readonly property string label: root.spec && root.spec.label ? root.spec.label : ""

    // A ring wants a square, and takes the smaller side of what it is given,
    // so it stays round in a row, in a column or on its own.
    readonly property real side: Math.max(18, Math.min(width, height))

    implicitWidth: root.base * 3
    implicitHeight: root.base * 3

    RingIndicator {
        id: ring

        anchors.centerIn: parent
        width: root.side
        height: root.side
        thickness: root.thickness
        progress: root.progress
        trackColor: Engine.colour("dim", root.ink)
        fillColor: Engine.colour(root.spec && root.spec.role ? root.spec.role : "accent", root.ink)

        Text {
            anchors.centerIn: parent
            visible: root.label !== ""
            text: Engine.fill(root.label, root.values)
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(10, Math.round(root.side * 0.28))
            color: Engine.colour("text", root.ink)
        }
    }
}
