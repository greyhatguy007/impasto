// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L Y R I C S   S E R V I C E                                            │
// │   time-synced lyrics for the playing track · via scripts/lyrics.py       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The playing track's time-synced lyrics, from LRCLIB via `scripts/lyrics.py`.
//
// It follows whatever is on the MPRIS bus — YouTube Music in a browser,
// Spotify, a local player — because all it needs is title, artist, album and
// length. A fetched set is kept for the session, so returning to a track shows
// its lines again at once; nothing is fetched while no widget is subscribed.
//
// The active line is found by binary search over the track's position, which
// `MediaService` polls while the widget is on screen. The service itself never
// touches the clock, so a paused player simply keeps the line it was on.
Singleton {
    id: root

    // Widgets showing lyrics, across the shell.
    property int watchers: 0

    property bool available: false
    property bool loading: false
    property string source: ""

    // `[{ t: milliseconds, text: "…" }]`, oldest first.
    property var lines: []

    // Title/artist already fetched (or being fetched), so the same track is
    // never asked for twice.
    property string fetchedKey: ""

    // The track the in-flight query was started for, so a skip mid-query does
    // not file one track's lyrics under another.
    property string requested: ""

    // Reports kept for the session, keyed the same way.
    property var cache: ({})

    readonly property string track: MediaService.available ? MediaService.title : ""
    readonly property string artist: MediaService.available ? MediaService.artist : ""
    readonly property string album: MediaService.available ? MediaService.album : ""
    readonly property int duration: Math.round(MediaService.length)

    // What identifies a track, for the cache and for spotting a change.
    readonly property string key: `${root.track} — ${root.artist}`

    // ── FOLLOWING THE PLAYER ────────────────────────────────────────────────
    //
    // A track announcement arrives in pieces (title, then artist, then length),
    // so the fetch waits a moment for it to settle. The same key never refetches.

    Connections {
        target: MediaService

        function onTitleChanged(): void { root.consider() }
        function onArtistChanged(): void { root.consider() }
    }

    function subscribe(): void {
        root.watchers += 1
        root.consider()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
        if (root.watchers === 0)
            root.settle.stop()
    }

    function consider(): void {
        if (root.watchers === 0)
            return
        if (root.track === "" && root.artist === "")
            return
        if (root.key === root.fetchedKey)
            return
        // A track already fetched this session shows at once.
        if (root.cache[root.key] !== undefined) {
            root.adopt(root.cache[root.key])
            root.fetchedKey = root.key
            return
        }
        root.settle.restart()
    }

    // Long enough for the player to finish announcing the track, short enough
    // to feel immediate.
    readonly property Timer settle: Timer {
        interval: 750
        repeat: false
        onTriggered: root.fetch()
    }

    function refresh(): void {
        root.fetchedKey = ""
        root.consider()
    }

    property var args: []

    function fetch(): void {
        if (root.watchers === 0 || root.key === "")
            return
        root.requested = root.key
        root.fetchedKey = root.key
        root.loading = true
        root.available = false
        root.lines = []
        // A query still in flight for the track just left is abandoned.
        root.query.running = false
        root.args = [Quickshell.shellPath("scripts/lyrics.py"),
            root.track, root.artist, root.album, `${root.duration}`]
        root.query.running = true
    }

    function adopt(report): void {
        root.source = report.source ?? ""
        const synced = report.available === true ? (report.synced ?? []) : []
        root.lines = synced
        root.available = synced.length > 0
    }

    readonly property Process query: Process {
        command: root.args

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the lyrics report:", error)
                    return
                }
                // Kept even when unavailable, so a miss is not retried all
                // evening; `refresh()` clears it. Filed under the track it was
                // asked for, which a skip may have moved on from.
                const key = root.requested
                root.cache[key] = report
                if (key === root.key)
                    root.adopt(report)
            }
        }
    }

    // ── THE LINE ON SCREEN ──────────────────────────────────────────────────

    readonly property int positionMs: Math.round(MediaService.position * 1000)

    // The last line at or before the position, or -1 before the first one.
    readonly property int activeIndex: {
        const list = root.lines
        if (!root.available || list.length === 0)
            return -1
        let low = 0
        let high = list.length - 1
        let found = -1
        while (low <= high) {
            const mid = (low + high) >> 1
            if (list[mid].t <= root.positionMs) {
                found = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return found
    }

    readonly property string current: root.activeIndex >= 0
        ? root.lines[root.activeIndex].text : ""

    // The line after the active one, or the first before the track starts.
    readonly property string upcoming: {
        const index = root.activeIndex
        if (index < 0)
            return root.lines.length > 0 ? root.lines[0].text : ""
        return index + 1 < root.lines.length ? root.lines[index + 1].text : ""
    }

    // What the single line shows: the line being sung, or the next one while
    // the intro plays.
    readonly property string display: root.current !== "" ? root.current : root.upcoming

    // True while a line is actually being sung, so it can be lit; the intro
    // line stays muted.
    readonly property bool singing: root.current !== ""
}
