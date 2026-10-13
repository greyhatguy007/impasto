// ╭──────────────────────────────────────────────────────────────────────────╮
// │   E N G I N E   ·   b a r                                                │
// │   one reading, as a track and what is filled of it                      │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "Engine.js" as Engine

Item {
    id: root

    property var spec: null
    property var values: ({})
    property var ink: null
    property real base: 22

    // A reading that has not been answered yet draws an empty track rather
    // than failing to be a number, so the widget looks like it is waiting.
    readonly property real reading: Engine.reading(root.spec ? root.spec.value : null,
                                                   root.values) ?? 0
    readonly property real done: Engine.fraction(root.reading, root.spec ? root.spec.min : 0,
                                                 root.spec ? root.spec.max : 100)
    readonly property color fill: Engine.colour(root.spec && root.spec.role
        ? root.spec.role : "accent", root.ink)
    readonly property int thickness: root.spec && root.spec.thickness > 0
        ? root.spec.thickness : 8
    readonly property string label: root.spec && root.spec.label ? root.spec.label : ""
    readonly property bool rounded: !root.spec || root.spec.rounded !== false

    implicitWidth: 60
    implicitHeight: (root.label !== "" ? label.implicitHeight + 3 : 0) + root.thickness

    ColumnLayout {
        anchors.fill: parent
        spacing: 3

        Text {
            id: label

            visible: root.label !== ""
            Layout.fillWidth: true
            text: Engine.fill(root.label, root.values)
            font.family: Theme.fontFamily
            font.pixelSize: Math.min(root.base, 14)
            color: Engine.colour("muted", root.ink)
            elide: Text.ElideRight
        }

        Rectangle {
            id: track

            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: root.thickness
            color: Engine.colour("raised", root.ink)
            radius: root.rounded ? Math.min(width, height) / 2 : Theme.radiusSmall

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.done
                color: root.fill
                radius: parent.radius

                Behavior on width {
                    NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
                }
            }
        }
    }
}
