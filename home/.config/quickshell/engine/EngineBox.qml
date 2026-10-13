// ╭──────────────────────────────────────────────────────────────────────────╮
// │   E N G I N E   ·   b o x                                                │
// │   a container · a row, a column or a grid of elements                    │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "Engine.js" as Engine

// A container lays its children out. It is its own file rather than a
// component inside `EngineElement.qml` because a component that instantiates
// itself is refused outright by QML, and the two files naming each other is
// refused as well. A box therefore reaches its children through
// `ElementLoader`, which is what lets a view nest as deep as it likes.
//
// `grow` takes what is left over and a child without it is as big as what is
// in it. `align` places a child across its row or column, `justify` places the
// children along it.
Item {
    id: root

    property var spec: null
    property var values: ({})
    property var samples: ({})
    property var ink: null
    property real base: 22
    property string module: ""

    readonly property string kind: root.spec ? root.spec.kind : "row"
    readonly property int gap: root.spec && root.spec.gap !== undefined ? root.spec.gap : 6
    // `items` rather than `children`: an item has a `children` of its own, and
    // a property that shadows it hides the objects that were actually made.
    readonly property var items: root.spec && root.spec.children ? root.spec.children : []
    readonly property string justify: root.spec && root.spec.justify ? root.spec.justify : "start"

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    // The items with a filler where `justify` asks for one, so one Repeater
    // draws the lot and no empty item has to remember to stay out of the way.
    function laid(): var {
        if (root.justify === "start")
            return root.items
        const out = []
        if (root.justify === "center")
            out.push({ filler: true })
        for (const child of root.items)
            out.push(child)
        if (root.justify === "center" || root.justify === "end")
            out.push({ filler: true })
        return out
    }

    Loader {
        id: layout

        anchors.fill: parent
        sourceComponent: root.kind === "grid" ? grid
            : (root.kind === "column" ? column : row)
    }

    // A child of a row: it fills the height unless `align` says otherwise, and
    // the width is its own or what is left.
    Component {
        id: rowChild

        Item {
            id: cell

            required property var modelData

            readonly property bool filler: modelData !== null && modelData.filler === true
            readonly property string alight: modelData && modelData.align ? modelData.align : "fill"

            implicitWidth: inner.implicitWidth
            implicitHeight: inner.implicitHeight

            Layout.fillWidth: cell.filler || modelData.grow > 0
            Layout.fillHeight: !cell.filler && cell.alight === "fill"
            Layout.preferredWidth: !cell.filler && modelData.width > 0 ? modelData.width : -1
            Layout.preferredHeight: !cell.filler && modelData.height > 0 ? modelData.height : -1
            Layout.alignment: cell.alight === "start" ? Qt.AlignTop
                : cell.alight === "end" ? Qt.AlignBottom : Qt.AlignVCenter

            ElementLoader {
                id: inner
                anchors.fill: parent
                spec: cell.modelData
                values: root.values
                samples: root.samples
                ink: root.ink
                base: root.base
                module: root.module
            }
        }
    }

    // A child of a column: it fills the width unless `align` says otherwise.
    Component {
        id: columnChild

        Item {
            id: cell

            required property var modelData

            readonly property bool filler: modelData !== null && modelData.filler === true
            readonly property string alight: modelData && modelData.align ? modelData.align : "fill"

            implicitWidth: inner.implicitWidth
            implicitHeight: inner.implicitHeight

            Layout.fillWidth: !cell.filler && cell.alight === "fill"
            Layout.fillHeight: cell.filler || modelData.grow > 0
            Layout.preferredWidth: !cell.filler && modelData.width > 0 ? modelData.width : -1
            Layout.preferredHeight: !cell.filler && modelData.height > 0 ? modelData.height : -1
            Layout.alignment: cell.alight === "start" ? Qt.AlignLeft
                : cell.alight === "end" ? Qt.AlignRight : Qt.AlignHCenter

            ElementLoader {
                id: inner
                anchors.fill: parent
                spec: cell.modelData
                values: root.values
                samples: root.samples
                ink: root.ink
                base: root.base
                module: root.module
            }
        }
    }

    Component {
        id: row

        RowLayout {
            spacing: root.gap

            Repeater {
                model: root.laid()
                delegate: rowChild
            }
        }
    }

    Component {
        id: column

        ColumnLayout {
            spacing: root.gap

            Repeater {
                model: root.laid()
                delegate: columnChild
            }
        }
    }

    Component {
        id: grid

        GridLayout {
            columns: root.spec && root.spec.columns > 0 ? root.spec.columns : 2
            columnSpacing: root.gap
            rowSpacing: root.gap

            Repeater {
                model: root.items

                delegate: Item {
                    id: tile

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ElementLoader {
                        anchors.fill: parent
                        spec: tile.modelData
                        values: root.values
                        samples: root.samples
                        ink: root.ink
                        base: root.base
                        module: root.module
                    }
                }
            }
        }
    }
}
