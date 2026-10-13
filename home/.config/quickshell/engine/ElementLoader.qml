// ╭──────────────────────────────────────────────────────────────────────────╮
// │   E L E M E N T   L O A D E R                                            │
// │   an element, by name rather than by type                                │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

// A container holds elements and an element may be a container, so the two
// files have to refer to each other. QML refuses a type that reaches itself —
// a file may not name itself and two files that name each other deadlock while
// they compile — so the container takes its children through a URL instead.
// The loader is that one place, and it hands the whole of what an element
// needs to whichever one it made.
Loader {
    id: root

    property var spec: null
    property var values: ({})
    property var samples: ({})
    property var ink: null
    property real base: 22
    property string module: ""

    source: "EngineElement.qml"

    Binding { target: root.item; property: "spec"; value: root.spec; when: root.item !== null }
    Binding { target: root.item; property: "values"; value: root.values; when: root.item !== null }
    Binding { target: root.item; property: "samples"; value: root.samples; when: root.item !== null }
    Binding { target: root.item; property: "ink"; value: root.ink; when: root.item !== null }
    Binding { target: root.item; property: "base"; value: root.base; when: root.item !== null }
    Binding { target: root.item; property: "module"; value: root.module; when: root.item !== null }
}
