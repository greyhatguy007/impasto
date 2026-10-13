// ╭──────────────────────────────────────────────────────────────────────────╮
// │   E N G I N E   ·   b u t t o n                                          │
// │   a press that runs an action the definition declares                    │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../services"
import "../theme"
import "Engine.js" as Engine

// The one element that does something. The press asks this desk's python to
// make the request, so a token stays out of the shell; `confirm` takes a
// second press within a few seconds, for anything that cannot be undone.
Item {
    id: root

    property var spec: null
    property var ink: null
    property real base: 22
    property string module: ""

    readonly property string action: root.spec && root.spec.action ? root.spec.action : ""
    readonly property string label: root.spec && root.spec.label ? root.spec.label : ""
    readonly property string glyph: root.spec && root.spec.glyph ? root.spec.glyph : ""
    readonly property bool accent: root.spec && root.spec.role === "accent"
    readonly property bool confirm: root.spec && root.spec.confirm === true
    readonly property int size: root.spec && root.spec.size > 0 ? root.spec.size : root.base
    readonly property bool waiting: WidgetService.running === root.module + "/" + root.action
    // A pointer over it, for the outline. Named here rather than reached
    // through the handler, since an id is not a property of what holds it.
    readonly property bool pointed: hover.hovered

    // Armed by the first press of a `confirm` action.
    property bool armed: false

    implicitWidth: Math.max(26, content.implicitWidth + 22)
    implicitHeight: Math.max(28, content.implicitHeight + 14)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: root.accent ? Engine.colour("accent", root.ink) : Engine.colour("raised", root.ink)
        border.width: root.armed ? 2 : (root.pointed ? 1 : 0)
        border.color: root.armed || root.pointed
            ? Engine.colour("accent", root.ink) : "transparent"
        opacity: root.waiting ? 0.55 : 1

        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

        Row {
            id: content

            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.glyph !== ""
                text: root.glyph
                font.family: Theme.fontMono
                font.pixelSize: root.size
                color: root.accent ? Engine.colour("accentText", root.ink)
                                   : Engine.colour("text", root.ink)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.label !== ""
                text: root.armed ? root.label + " again?" : root.label
                font.family: Theme.fontFamily
                font.pixelSize: Math.min(root.size, 15)
                color: root.accent ? Engine.colour("accentText", root.ink)
                                   : Engine.colour("text", root.ink)
            }
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.press()
    }

    Timer {
        id: disarm
        interval: 4000
        onTriggered: root.armed = false
    }

    function press(): void {
        if (root.action === "" || root.module === "")
            return
        if (root.confirm && !root.armed) {
            root.armed = true
            disarm.restart()
            return
        }
        root.armed = false
        WidgetService.run(root.module, root.action)
    }
}
