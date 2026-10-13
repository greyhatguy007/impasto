// ╭──────────────────────────────────────────────────────────────────────────╮
// │   E N G I N E   ·   d i v i d e r                                        │
// │   a hairline between two pieces of a widget                              │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "Engine.js" as Engine

Item {
    id: root

    property var spec: null
    property var ink: null

    readonly property bool vertical: root.spec && root.spec.vertical === true
    readonly property int thickness: root.spec && root.spec.thickness > 0
        ? root.spec.thickness : 1

    implicitWidth: root.vertical ? root.thickness : 0
    implicitHeight: root.vertical ? 0 : root.thickness

    Rectangle {
        anchors.fill: parent
        color: Engine.colour(root.spec && root.spec.role ? root.spec.role : "border", root.ink)
    }
}
