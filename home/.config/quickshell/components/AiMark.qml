// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A I   M A R K                                                           │
// │   a star for whatever assistant is being measured · drawn, not traced   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import "../theme"

// The mark for the usage ring, whichever assistant the settings name.
//
// A company's own logo would only ever be the right answer for the company
// that drew it, and the shell measures Claude, pi and whatever comes next
// with the same ring. So this is a star: drawn from its own numbers rather
// than traced, which is also why its arms can be as thin as they look
// right at sixteen pixels.
Item {
    id: root

    property color color: Theme.indicator

    // How many arms, and how deep the notches between them.
    property int arms: 8
    property real inner: 0.30

    implicitWidth: 16
    implicitHeight: 16

    // A star as one closed outline: out, in, out, in, and the first point
    // again at the end so the loop closes. Coordinates run -0.5 to 0.5 with
    // the centre at the origin, y down.
    readonly property var outline: {
        const points = []
        const outer = 0.48
        for (let index = 0; index < root.arms * 2; index++) {
            const radius = index % 2 === 0 ? outer : outer * root.inner
            // A quarter turn of slack, so the first arm points up rather
            // than to the right.
            const angle = (index / (root.arms * 2)) * Math.PI * 2
                    - Math.PI / 2
            points.push(Qt.point(
                Math.cos(angle) * radius, Math.sin(angle) * radius))
        }
        points.push(points[0])
        return points
    }

    readonly property real scale2: Math.min(root.width, root.height)

    readonly property var drawn: root.outline.map(point => Qt.point(
        root.width / 2 + point.x * root.scale2,
        root.height / 2 + point.y * root.scale2))

    Shape {
        anchors.fill: parent
        // The curve renderer antialiases the arm tips, which the default
        // one leaves visibly stepped at this size.
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.color

            PathPolyline { path: root.drawn }
        }
    }
}
