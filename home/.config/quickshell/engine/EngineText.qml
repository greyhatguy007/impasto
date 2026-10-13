// ╭──────────────────────────────────────────────────────────────────────────╮
// │   E N G I N E   ·   t e x t                                              │
// │   a template over the widget's readings                                  │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"
import "Engine.js" as Engine

Item {
    id: root

    property var spec: null
    property var values: ({})
    property var ink: null
    property real base: 22

    readonly property int size: root.spec && root.spec.size > 0 ? root.spec.size : root.base
    readonly property string role: root.spec && root.spec.role ? root.spec.role : "text"
    readonly property string align: root.spec && root.spec.align ? root.spec.align : "left"
    readonly property string valign: root.spec && root.spec.valign ? root.spec.valign : "center"

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label

        anchors.fill: parent
        text: Engine.fill(root.spec ? root.spec.text : "", root.values)
        font.family: root.spec && root.spec.mono ? Theme.fontMono : Theme.fontFamily
        font.pixelSize: root.size
        font.weight: root.spec && root.spec.bold ? Font.Bold : Font.Normal
        color: Engine.colour(root.role, root.ink)
        horizontalAlignment: root.align === "center" ? Text.AlignHCenter
            : root.align === "right" ? Text.AlignRight : Text.AlignLeft
        verticalAlignment: root.valign === "top" ? Text.AlignTop
            : root.valign === "bottom" ? Text.AlignBottom : Text.AlignVCenter
        // A template that wraps grows downwards; without wrapping a long one
        // is cut rather than pushing its neighbours out of the cell.
        wrapMode: root.spec && root.spec.wrap ? Text.WordWrap : Text.NoWrap
        elide: root.spec && root.spec.wrap ? Text.ElideNone : Text.ElideRight
    }
}
