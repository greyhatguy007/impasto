// ╭──────────────────────────────────────────────────────────────────────────╮
// │   E N G I N E   ·   i c o n                                              │
// │   a glyph from the shell's font, or a picture of your own               │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../theme"
import "Engine.js" as Engine

Item {
    id: root

    property var spec: null
    property var ink: null
    property real base: 22

    readonly property string glyph: root.spec && root.spec.glyph ? root.spec.glyph : ""
    readonly property string picture: root.spec
        ? (root.spec.svg || root.spec.image || "") : ""
    readonly property int size: root.spec && root.spec.size > 0 ? root.spec.size : root.base
    readonly property color tint: Engine.colour(root.spec && root.spec.role
        ? root.spec.role : "accent", root.ink)

    implicitWidth: root.size
    implicitHeight: root.size

    // A glyph is the shell's own mono font, which is where the bar's marks
    // come from; a picture is a path, `~` and all, or a URL.
    Text {
        anchors.centerIn: parent
        visible: root.glyph !== "" && root.picture === ""
        text: root.glyph
        font.family: Theme.fontMono
        font.pixelSize: root.size
        color: root.tint
    }

    Image {
        anchors.fill: parent
        visible: root.picture !== ""
        source: {
            const path = root.picture
            if (path === "")
                return ""
            if (path.indexOf("://") >= 0)
                return path
            if (path.charAt(0) === "~")
                return "file://" + Quickshell.env("HOME") + path.slice(1)
            return "file://" + path
        }
        sourceSize.width: Math.max(1, Math.round(root.width))
        sourceSize.height: Math.max(1, Math.round(root.height))
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
