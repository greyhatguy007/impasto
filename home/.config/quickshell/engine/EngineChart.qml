// ╭──────────────────────────────────────────────────────────────────────────╮
// │   E N G I N E   ·   c h a r t                                            │
// │   a reading over time · line, area or bars                              │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import "../theme"
import "Engine.js" as Engine

Item {
    id: root

    property var spec: null
    property var values: ({})
    property var samples: ({})
    property var ink: null
    property real base: 22

    readonly property var points: Engine.series(root.spec ? root.spec.span : 0, root.samples)
    readonly property real low: root.spec && root.spec.min !== undefined ? root.spec.min : 0
    readonly property real high: root.spec && root.spec.max !== undefined ? root.spec.max : 100
    readonly property color stroke: Engine.colour(root.spec && root.spec.role
        ? root.spec.role : "accent", root.ink)
    readonly property string style: root.spec && root.spec.style ? root.spec.style : "area"

    implicitWidth: 80
    implicitHeight: root.base * 1.6

    // One sample is a dot, so nothing is drawn until the second arrives: the
    // readings behind it are already in `values`.
    readonly property bool drawn: root.points.length > 1

    function spot(index: int): point {
        const count = Math.max(2, root.points.length)
        const value = (root.points[index] - root.low) / (root.high - root.low)
        return Qt.point(index / (count - 1) * root.width,
                        root.height - Math.max(0, Math.min(1, value)) * root.height)
    }

    function outline(): var {
        const line = []
        for (let index = 0; index < root.points.length; index++)
            line.push(root.spot(index))
        return line
    }

    function area(): var {
        const closed = root.outline()
        closed.push(Qt.point(root.width, root.height))
        closed.push(Qt.point(0, root.height))
        return closed
    }

    Shape {
        anchors.fill: parent
        visible: root.drawn && root.style !== "bars"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: Math.max(1, root.spec && root.spec.thickness ? root.spec.thickness : 1.8)
            strokeColor: root.stroke
            fillColor: root.style === "area"
                ? Qt.rgba(root.stroke.r, root.stroke.g, root.stroke.b, 0.22)
                : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: root.style === "area" ? root.area() : root.outline()
            }
        }
    }

    // Bars: one per sample, oldest left, each drawn to the ceiling rather than
    // to the tallest of them, so the row reads as a level over time.
    Item {
        anchors.fill: parent
        visible: root.drawn && root.style === "bars"

        readonly property real step: root.points.length > 0
            ? root.width / root.points.length : 0

        Repeater {
            model: root.points

            Rectangle {
                required property int index
                required property real modelData

                readonly property real done: Math.max(0, Math.min(1,
                    (modelData - root.low) / (root.high - root.low)))

                x: index * parent.step
                width: Math.max(1, parent.step - 1)
                height: Math.max(1, root.height * done)
                y: root.height - height
                color: root.stroke
                radius: 1
            }
        }
    }
}
