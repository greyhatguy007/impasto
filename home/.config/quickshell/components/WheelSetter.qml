// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W H E E L   S E T T E R                                                │
// │   the scroll wheel as a stepper · one signal per detent                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

// A transparent MouseArea that turns the wheel into two signals. Drop it over
// any widget and the wheel adjusts what the widget shows, the way the media
// keys do. `step` carries the detent count; `up` and `down` are the usual one
// detent each.
MouseArea {
    id: root

    signal up(int steps)
    signal down(int steps)

    acceptedButtons: Qt.NoButton
    hoverEnabled: false
    cursorShape: Qt.ArrowCursor

    onWheel: wheel => {
        const detents = Math.max(1, Math.ceil(Math.abs(wheel.angleDelta.y) / 120))
        if (wheel.angleDelta.y > 0)
            root.up(detents)
        else if (wheel.angleDelta.y < 0)
            root.down(detents)
    }
}
