// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P I N N E D   L Y R I C S                                              │
// │   the island pinned to the line being sung                               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../theme"
import "../../services"

// The resting island as one time-synced line, the way a phone shows a lyric
// bang in the middle of its notch: the line being sung, centred, and when it
// is longer than the notch, running on so the whole of it passes the middle
// and can be read. Hovering holds the run still and slides in an unpick at
// the end; the text runs under it and out at the lane's edge.
//
// The subscriptions are held for the layer's life, which keeps the MPRIS
// position polling — and so the line finding — alive while the pin is up,
// and the fetch running so a track change is followed.
Item {
    id: root

    // The island is told; it owns the pin.
    signal unpin()

    readonly property bool playing: MediaService.playing

    // The line being sung, or the first one while the intro plays.
    readonly property string lineText: LyricsService.display

    // A run only pays off when the line is meaningfully longer than the
    // notch; a hair over is better elided than jogged back and forth.
    readonly property bool longLine: metrics.width > root.width + 10

    Component.onCompleted: {
        MediaService.subscribe()
        LyricsService.subscribe()
    }
    Component.onDestruction: {
        MediaService.release()
        LyricsService.release()
    }

    clip: true

    TextMetrics {
        id: metrics

        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        text: root.lineText
    }

    HoverHandler {
        id: laneHover
    }

    Text {
        id: line

        // Slid left from the lane's start; the marquee's own value. A short
        // line is centred instead and never moves.
        property real offset: 0

        x: root.longLine ? line.offset : (root.width - metrics.width) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(root.width, metrics.width)
        height: parent.height
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        visible: root.lineText !== ""
        text: root.lineText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        color: LyricsService.singing ? Theme.text : Theme.textMuted

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    // Out with the whole line readable at either end, across in between,
    // forever; a short line, a pause or a pointer on the lane holds it.
    SequentialAnimation {
        id: marquee

        readonly property real travel: Math.max(0, metrics.width - root.width)
        readonly property int cross: Math.max(2400, Math.round(travel * 26))

        running: root.playing && LyricsService.available
            && root.longLine && !laneHover.hovered
        loops: Animation.Infinite

        PauseAnimation { duration: 1400 }
        NumberAnimation {
            target: line
            property: "offset"
            // From wherever the line was left, so a hover-pause does not
            // jump it back to the start on the way out.
            from: line.offset
            to: -marquee.travel
            duration: marquee.cross
            easing.type: Theme.easing
        }
        PauseAnimation { duration: 1400 }
        NumberAnimation {
            target: line
            property: "offset"
            from: -marquee.travel
            to: 0
            duration: marquee.cross
            easing.type: Theme.easing
        }
    }

    // The unpick. Backed in the island's own surface, so the line goes under
    // it and out rather than past the button; the backing reaches to the
    // lane's edge, where the clip takes over. Always placed, even with
    // nothing on the line — a player that quit while pinned would otherwise
    // leave a blank island with no way back — but its clicks only count once
    // the pointer is on the lane.
    Rectangle {
        id: unpick

        x: root.width - width
        width: 28
        height: root.height
        opacity: laneHover.hovered ? 1 : 0
        // The island at rest is pure black attached and a dark surface
        // floating, and while pinned it never lights.
        color: SettingsService.islandAttached ? Theme.island : Theme.islandSurface

        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

        Text {
            anchors.centerIn: parent
            text: "󰐃"
            font.family: Theme.fontMono
            font.pixelSize: 13
            color: unpickMouse.containsMouse ? Theme.text : Theme.textMuted

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        MouseArea {
            id: unpickMouse

            anchors.fill: parent
            enabled: laneHover.hovered
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.unpin()
        }
    }

    // Nothing to show: a pin without a set, or a track with none on
    // LRCLIB. The track, its artist and the time left, so the island is not
    // blank while it is pinned; muted, like an intro line. A clock of its
    // own counts the position down, so MediaService's polling stays reserved
    // for the line-finding and the media detail.
    Row {
        anchors.centerIn: parent
        spacing: 8
        visible: root.lineText === ""

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.width - 90)
            elide: Text.ElideRight
            text: MediaService.available
                ? (MediaService.title || MediaService.identity)
                  + (MediaService.artist !== "" ? ` — ${MediaService.artist}` : "")
                : ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: MediaService.seekable
            text: countdown.display
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeLabel
            color: Theme.textMuted
        }
    }

    SystemClock {
        id: countdown
        precision: SystemClock.Seconds

        readonly property string display: {
            const gone = Math.round(MediaService.position)
            const whole = Math.max(0, Math.floor(MediaService.length))
            const left = Math.max(0, whole - gone)
            const minutes = Math.floor(left / 60)
            const rest = left % 60
            return `${minutes}:${rest < 10 ? "0" : ""}${rest}`
        }
    }
}
