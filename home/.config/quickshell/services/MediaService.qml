// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M E D I A   S E R V I C E                                              │
// │   the player worth showing · mpris over d-bus                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

import "."

// Picks one MPRIS player and exposes it flatly: the one that is playing,
// otherwise the first controllable one, so a paused track stays on the island.
Singleton {
    id: root

    readonly property var players: Mpris.players.values

    readonly property MprisPlayer active: {
        const playing = root.players.find(player => player.isPlaying)
        if (playing)
            return playing
        return root.players.find(player => player.canControl) ?? null
    }

    readonly property bool available: root.active !== null
    readonly property bool playing: root.available && root.active.isPlaying

    readonly property string title: root.available ? (root.active.trackTitle ?? "") : ""
    readonly property string artist: root.available ? (root.active.trackArtist ?? "") : ""
    readonly property string album: root.available ? (root.active.trackAlbum ?? "") : ""
    readonly property string artUrl: root.available ? (root.active.trackArtUrl ?? "") : ""
    readonly property string identity: root.available ? (root.active.identity ?? "") : ""

    readonly property bool canNext: root.available && root.active.canGoNext
    readonly property bool canPrevious: root.available && root.active.canGoPrevious
    readonly property bool canToggle: root.available && root.active.canTogglePlaying
    readonly property bool canSeek: root.available && root.active.canSeek && root.length > 0

    // ── LENGTH AND POSITION ───────────────────────────────────────────────
    //
    // MPRIS pushes neither. Length arrives in the metadata and is read as a
    // property; position is cached by the shell and has to be asked for, so
    // it is polled while anything on screen holds a subscribe() — while
    // paused too, which is how a seek made while paused reads back at once
    // instead of snapping when playback resumes.
    //
    // Both are held through momentary nonsense: some players answer 0 during
    // a seek or a metadata change, which would otherwise flicker the seek
    // strip and snap the countdown.

    readonly property real rawLength: root.available ? (root.active.length ?? 0) : 0

    // Seconds. Streams report no length, so `progress` stays at 0.
    property real length: 0

    onRawLengthChanged: {
        if (root.rawLength > 0)
            root.length = root.rawLength
        else if (!root.available)
            root.length = 0
    }

    // The last position the player answered with, in seconds.
    property real lastPosition: 0

    readonly property real position: root.available
        ? Math.max(0, Math.min(root.lastPosition,
                               root.length > 0 ? root.length : root.lastPosition))
        : 0

    readonly property bool seekable: root.length > 0
    readonly property real progress: root.seekable
        ? Math.max(0, Math.min(1, root.position / root.length))
        : 0

    // Asks the player where it is, and keeps the answer sane. A 0 right
    // after a good reading — a player mid-seek — is ignored, unless the
    // track has genuinely changed (the caller resets `lastPosition`).
    function refresh(): void {
        if (!root.available) {
            root.lastPosition = 0
            return
        }
        // Quickshell re-reads the player when its `positionChanged` runs,
        // which is also how the bindings on it are notified.
        root.active.positionChanged()
        const read = root.active.position ?? 0
        if (read <= 0 && root.lastPosition > 1 && root.length > 0)
            return
        root.lastPosition = read
    }

    // MPRIS does not push position, so it is polled only while something on
    // screen holds a subscribe().
    property int watchers: 0

    readonly property Timer positionTimer: Timer {
        interval: 1000
        repeat: true
        running: root.watchers > 0 && root.available && root.seekable
        onTriggered: root.refresh()
    }

    // An immediate re-read after a seek, and another after a moment, since
    // players answer SetPosition at their own pace.
    readonly property Timer nudge: Timer {
        interval: 120
        onTriggered: root.refresh()
    }

    readonly property Timer nudgeLate: Timer {
        interval: 600
        onTriggered: root.refresh()
    }

    Connections {
        target: root.active

        // A resume: the first reading is wanted at once, not a second later.
        function onIsPlayingChanged(): void {
            if (root.available && root.active.isPlaying)
                root.refresh()
        }

        // A new track starts its position from the beginning, and its own
        // length: a stream after a timed track must not inherit the old
        // duration. The new length arrives with the track's metadata.
        function onTrackTitleChanged(): void {
            root.lastPosition = 0
            root.length = 0
            root.refresh()
        }
    }

    function subscribe(): void {
        root.watchers += 1
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function toggle(): void {
        if (root.canToggle)
            root.active.togglePlaying()
    }

    function next(): void {
        if (root.canNext)
            root.active.next()
    }

    // `fraction` of the track's length.
    function seek(fraction: real): void {
        if (!root.canSeek)
            return
        const target = Math.max(0, Math.min(1, fraction)) * root.length
        root.lastPosition = target
        root.active.position = target
        root.nudge.restart()
        root.nudgeLate.restart()
    }

    function previous(): void {
        if (root.canPrevious)
            root.active.previous()
    }
}
