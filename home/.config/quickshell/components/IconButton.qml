// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I C O N   B U T T O N                                                  │
// │   square icon action                                                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"

// Square icon button, transparent until hovered.
Rectangle {
    id: root

    property string icon: ""
    property int iconSize: 13
    property color iconColor: Theme.text
    property bool active: false

    // What the button does, shown in a small bubble over it while the pointer
    // is on it. Empty draws nothing, so a button that says it all in its
    // glyph stays silent.
    property string hint: ""

    // Set false where the bubble would be clipped or covered: the caller
    // draws the hint in its own line instead.
    property bool showBubble: true

    // Whether the pointer is on the button, for a caller that mirrors the
    // hint somewhere of its own.
    readonly property bool hovered: mouse.containsMouse

    signal clicked()

    implicitWidth: 32
    implicitHeight: 28
    radius: Theme.radiusSmall

    color: root.active ? Theme.accent
        : (mouse.containsMouse ? Theme.islandSurfaceHover : "transparent")
    border.color: root.active ? Theme.accent
        : (mouse.containsMouse ? Theme.islandBorder : "transparent")
    border.width: 1

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

    Text {
        anchors.centerIn: parent
        text: root.icon
        font.family: Theme.fontMono
        font.pixelSize: root.iconSize
        color: root.active ? Theme.accentText
            : (mouse.containsMouse ? Theme.accent : root.iconColor)

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // The hint, centred over the button. Drawn outside the button so it never
    // crowds the glyph.
    Rectangle {
        id: bubble

        visible: root.hint !== "" && root.showBubble && mouse.containsMouse
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 6
        width: bubbleText.implicitWidth + 16
        height: 24
        radius: height / 2
        color: Theme.island
        border.color: Theme.islandBorder
        border.width: 1
        z: 10

        Text {
            id: bubbleText
            anchors.centerIn: parent
            text: root.hint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabel
            color: Theme.text
        }
    }
}
