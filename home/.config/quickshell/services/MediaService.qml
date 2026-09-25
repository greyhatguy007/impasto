// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M E D I A   S E R V I C E                                              │
// │   the player worth showing · mpris over d-bus, or the phone              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

import "."

// Picks what the island plays and exposes it flatly, so nothing downstream
// has to ask where it came from: the one local MPRIS player that is playing,
// otherwise the first controllable one, so a paused track stays on screen;
// and, when a paired phone is playing, the phone — a phone's music is a
// deliberate act, so it outranks whatever the desk left running.
//
// The phone's player is adopted rather than polled: KDE Connect publishes it
// on the session bus, and `KdeConnectService` hands it over here whenever it
// changes. Its position is interpolated between those updates, because the
// daemon only reports every few seconds while a track is running.
Singleton {
    id: root

    readonly property var players: Mpris.players.values

    readonly property MprisPlayer active: {
        const playing = root.players.find(player => player.isPlaying)
        if (playing)
            return playing
        return root.players.find(player => player.canControl) ?? null
    }

    readonly property bool localAvailable: root.active !== null

    // The one the shell asks: there is something to show, whether it is a
    // player on this machine or the phone. `localAvailable` is the narrower
    // question, and is what the keys act on.
    readonly property bool available: root.phoneAvailable || root.localAvailable
    readonly property bool playing: root.phonePlaying || (root.localAvailable && root.active.isPlaying)

    // "phone" while the phone is what is playing, "mpris" while a local
    // player is, and "" when there is nothing to show.
    readonly property string origin: root.phonePlaying
        ? "phone"
        : (root.localAvailable ? "mpris" : "")

    // ── THE PHONE ───────────────────────────────────────────────────────────

    // What the phone last reported, and when it reported it. Both are empty
    // until `adopt` is called, which is only while the KDE Connect service
    // is watching.
    property var phone: null
    property real phoneAt: 0

    function adopt(source: string, track): void {
        if (source !== "phone" || !track) {
            root.phone = null
            return
        }
        if (!track.title && !track.playing) {
            root.phone = null
            return
        }
        root.phone = track
        root.phoneAt = new Date().getTime()
    }

    readonly property bool phoneAvailable: root.phone !== null
    readonly property bool phonePlaying: root.phoneAvailable && root.phone.playing === true

    // ── WHAT IS SHOWED ──────────────────────────────────────────────────────

    readonly property string title: {
        if (root.phonePlaying)
            return root.phone.title ?? ""
        return root.localAvailable ? (root.active.trackTitle ?? "") : ""
    }

    readonly property string artist: {
        if (root.phonePlaying)
            return root.phone.artist ?? ""
        return root.localAvailable ? (root.active.trackArtist ?? "") : ""
    }

    readonly property string album: {
        if (root.phonePlaying)
            return root.phone.album ?? ""
        return root.localAvailable ? (root.active.trackAlbum ?? "") : ""
    }

    readonly property string artUrl: {
        if (root.phonePlaying)
            return root.phone.art ?? ""
        return root.localAvailable ? (root.active.trackArtUrl ?? "") : ""
    }

    // "phone:…" and "MPRIS identity" as one string, so a card can say where
    // the music is coming from without asking a second question.
    readonly property string identity: {
        if (root.phonePlaying)
            return "phone"
        return root.localAvailable ? (root.active.identity ?? "") : ""
    }

    readonly property bool canNext: root.phonePlaying || (root.localAvailable && root.active.canGoNext)
    readonly property bool canPrevious: root.phonePlaying || (root.localAvailable && root.active.canGoPrevious)
    readonly property bool canToggle: root.phonePlaying || (root.localAvailable && root.active.canControl)

    // The phone's player cannot be told where to go: KDE Connect's bus
    // offers no seek, so a strip on the phone's track is drawn without one
    // rather than pretending a drag would do something.
    readonly property bool canSeek: !root.phonePlaying
        && root.localAvailable && root.active.canSeek && root.length > 0

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

    readonly property real rawLength: root.phonePlaying
        ? (root.phone.length ?? 0)
        : (root.localAvailable ? (root.active.length ?? 0) : 0)

    // Seconds. Streams report no length, so `progress` stays at 0.
    property real length: 0

    onRawLengthChanged: {
        if (root.rawLength > 0)
            root.length = root.rawLength
        else if (!root.playing)
            root.length = 0
    }

    // The last position the player answered with, in seconds.
    property real lastPosition: 0

    readonly property real position: {
        if (root.phonePlaying) {
            // The phone is asked every few seconds; between answers the
            // position walks on its own, which is what a seek strip needs.
            const since = (new Date().getTime() - root.phoneAt) / 1000
            const read = (root.phone.position ?? 0) + since
            return root.length > 0 ? Math.max(0, Math.min(read, root.length)) : read
        }
        return root.localAvailable
            ? Math.max(0, Math.min(root.lastPosition,
                                   root.length > 0 ? root.length : root.lastPosition))
            : 0
    }

    readonly property bool seekable: root.length > 0
    readonly property real progress: root.seekable
        ? Math.max(0, Math.min(1, root.position / root.length))
        : 0

    // Asks the player where it is, and keeps the answer sane. A 0 right
    // after a good reading — a player mid-seek — is ignored, unless the
    // track has genuinely changed (the caller resets `lastPosition`).
    function refresh(): void {
        if (root.phonePlaying) {
            // The phone is read from the bus, not asked; the next update
            // arrives on its own, and the position walks until it does.
            return
        }
        if (!root.localAvailable) {
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
        running: root.watchers > 0 && (root.playing || root.seekable)
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
            if (root.localAvailable && root.active.isPlaying)
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

    // ── THE CONTROLS ────────────────────────────────────────────────────────
    //
    // Every key goes to whatever is playing, the phone or the desk, so a
    // control on the island never moves music that is not on screen.

    function toggle(): void {
        if (root.phonePlaying)
            KdeConnectService.playPause()
        else if (root.canToggle)
            root.active.togglePlaying()
    }

    function next(): void {
        if (root.phonePlaying)
            KdeConnectService.nextTrack()
        else if (root.canNext)
            root.active.next()
    }

    function previous(): void {
        if (root.phonePlaying)
            KdeConnectService.previousTrack()
        else if (root.canPrevious)
            root.active.previous()
    }

    // `fraction` of the track's length. A phone's track has no strip: its
    // player cannot be dragged to a place it would then refuse to report.
    function seek(fraction: real): void {
        if (!root.canSeek)
            return
        const target = Math.max(0, Math.min(1, fraction)) * root.length
        root.lastPosition = target
        root.active.position = target
        root.nudge.restart()
        root.nudgeLate.restart()
    }
}
