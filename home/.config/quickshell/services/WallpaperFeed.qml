// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W A L L P A P E R   F E E D   S E R V I C E                            │
// │   wallpapers from a source the settings name · via the shell's script    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The gallery behind Settings → Integrations → Wallpaper. One search asks
// `scripts/wallpaper_feed.py`, which answers with the photographs of
// whichever source the settings name — wallhaven, unsplash, pexels,
// openverse or picsum — at the width they were asked for, so nothing lands
// smaller than the panel it is about to fill. The shell can't tell the
// sources apart, and only two of them need a key.
//
// Photos are downloaded with curl into the wallpaper directory under a
// `<source> – <artist>` name, so they join the ordinary gallery and are
// applied, themed from and restored like any local picture. The queue is
// serial, so a click-happy desk cannot open thirty curls; skipping drops
// everything not yet started.
//
// Nothing runs while the gallery is closed: `subscribe`/`release` decides
// whether the service exists to the script at all.
Singleton {
    id: root

    property int watchers: 0

    // Holding the service keeps its processes answerable but asks for
    // nothing: a search is the user's call (Browse or Shuffle), so merely
    // opening the settings never spends a source's patience.
    function subscribe(): void {
        root.watchers += 1
        if (root.watchers === 1)
            root.describe()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    // ── STATE ───────────────────────────────────────────────────────────────

    // True once the script has answered a search.
    property bool known: false
    // The source the last search used, and the sources the machine can
    // reach, as the script's `providers` answers.
    property string provider: ""
    property var sources: []
    // "setup", "auth", "provider", "network", "input" or "" — from the script.
    property string reason: ""
    property bool busy: false

    // Every photo of the current search, as the script reported them.
    property var photos: []
    // The ids whose full picture is already on disk.
    property var fetched: []
    // The id of the photo downloading right now, for the progress row.
    property string fetchingId: ""
    property int generation: 0

    // What the source would need before it could be searched: the key, for
    // the two that take one.
    readonly property var current: {
        const wanted = root.sources.find(
            entry => entry.id === root.provider) ?? null
        if (wanted)
            return wanted
        return root.sources.find(entry => entry.id === "wallhaven") ?? null
    }

    readonly property bool needsKey: root.current?.needsKey === true
    readonly property bool keyPresent: (SettingsService.wallpaperKey ?? "").length > 0
    readonly property bool ready: !root.needsKey || root.keyPresent

    // ── SOURCES ─────────────────────────────────────────────────────────────

    readonly property Process describeQuery: Process {
        command: [Quickshell.shellPath("scripts/wallpaper_feed.py"), "providers"]
        stdout: StdioCollector {
            onStreamFinished: {
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the wallpaper sources:", error)
                    return
                }
                if (report.available !== true)
                    return
                root.sources = report.providers ?? []
            }
        }
    }

    function describe(): void {
        if (root.watchers === 0)
            return
        root.describeQuery.running = true
    }

    // ── SEARCH ──────────────────────────────────────────────────────────────

    property bool fetchOnArrival: false
    property var queue: []
    property int runningId: 0

    function consider(variation = 0): void {
        if (root.watchers === 0)
            return
        root.busy = true
        root.generation += 1
        root.query.command = [Quickshell.shellPath("scripts/wallpaper_feed.py"),
            "search", "24", `${variation}`]
        root.query.running = true
    }

    // A new batch. `after` is optional: a callback run once the search has
    // come back and the first fetch has been queued, so the browse flow is
    // one click. `variation` pages the source, so Shuffle hands back a
    // different set of the same topic.
    function refresh(after = null, variation = 0): void {
        if (after)
            root.fetchOnArrival = true
        root.consider(variation)
    }

    function refreshWithVariation(variation: int): void {
        root.consider(variation)
    }

    // ── DOWNLOAD ────────────────────────────────────────────────────────────

    readonly property string wallpaperDirectory: {
        const data = Quickshell.env("XDG_DATA_HOME")
            || `${Quickshell.env("HOME")}/.local/share`
        return `${data}/wallpapers`
    }

    // Names on disk: `<source> – <artist>.jpg`, or the photo's id when the
    // source names nobody. A same-artist pair is disambiguated by the id, so
    // nothing is overwritten.
    function nameOf(photo): string {
        const extension = photo.extension ?? "jpg"
        const who = (photo.artist ?? "").trim()
        const tag = who !== ""
            ? who.replace(/[\/\\:*?"<>|]/g, "-").slice(0, 48)
            : `${photo.id ?? "photo"}`
        const label = root.provider !== "" ? root.provider : "wallpaper"
        return `${label} – ${tag}.${extension}`
    }

    // ── QUEUE ───────────────────────────────────────────────────────────────

    readonly property Process download: Process {
        // Which download this process belongs to, and of what: a skip that
        // lands after a new begin() must not clear the new one's state.
        property int processId: 0
        property string photoId: ""
        property string path: ""

        stdout: StdioCollector {
            onStreamFinished: {}
        }

        onExited: exitCode => {
            const stale = root.download.processId !== root.runningId
            if (exitCode !== 0) {
                // No half-downloaded picture is left to be applied or read
                // into a palette.
                if (!stale && root.download.path !== "")
                    Quickshell.execDetached(["rm", "-f", root.download.path])
            } else if (!stale && root.download.photoId !== "") {
                root.remember(root.download.photoId)
            }
            if (!stale)
                root.advance()
        }
    }

    function fetch(photo): void {
        if (root.fetched.indexOf(photo.id) >= 0)
            return
        if (root.fetchingId !== "")
            root.queue.push(photo)
        else
            root.begin(photo)
    }

    function begin(photo): void {
        const directory = root.wallpaperDirectory
        root.fetchingId = photo.id
        root.runningId += 1
        root.download.processId = root.runningId
        root.download.photoId = photo.id
        root.download.path = `${directory}/${root.nameOf(photo)}`
        // `-f`: an HTTP error must fail the job rather than save the error
        // page as a wallpaper.
        root.download.command = ["curl", "-sS", "-f", "-L", "--retry", "2",
            "--max-time", "120", "-o", root.download.path, photo.url]
        root.download.running = true
    }

    function advance(): void {
        root.fetchingId = ""
        if (root.queue.length > 0)
            root.begin(root.queue.shift())
    }

    function skip(): void {
        root.queue = []
        if (root.fetchingId !== "")
            root.download.running = false
    }

    function applyFetched(photo): void {
        WallpaperService.apply(`${root.wallpaperDirectory}/${root.nameOf(photo)}`)
    }

    function remember(id: string): void {
        if (root.fetched.indexOf(id) < 0) {
            root.fetched = root.fetched.concat([id])
        }
    }

    // ── THE SCRIPT ──────────────────────────────────────────────────────────

    function parse(text: string): var {
        if (!text || text.trim() === "")
            return null
        try {
            return JSON.parse(text)
        } catch (error) {
            console.warn("Cannot parse the wallpaper report:", error)
            return null
        }
    }

    readonly property Process query: Process {
        stdout: StdioCollector {
            // Per stream, not per chunk: partial JSON doesn't parse.
            onStreamFinished: {
                root.busy = false
                const report = root.parse(text)
                if (!report || report.available !== true) {
                    root.known = false
                    root.photos = []
                    root.provider = ""
                    root.reason = report?.reason ?? "network"
                    return
                }
                root.known = true
                root.reason = ""
                root.provider = report.provider ?? ""
                root.photos = report.photos ?? []
                if (root.fetchOnArrival) {
                    root.fetchOnArrival = false
                    const photo = root.photos.find(entry => !root.isFetched(entry.id))
                    if (photo)
                        root.fetch(photo)
                }
            }
        }
    }

    function isFetched(id: string): bool {
        return root.fetched.indexOf(id) >= 0
    }

    // ── THROWING ONE AWAY ────────────────────────────────────────────────
    //
    // A fetch is a file on the disk, and a gallery of files that cannot be
    // removed is a gallery that only grows. The cross on a fetched tile
    // deletes that one file, and forgets the id with it, so the same
    // photograph can be fetched again on another Browse rather than being
    // remembered as already on the disk when it is not.
    function discard(photo): void {
        if (!photo || !root.isFetched(photo.id))
            return
        // A download still running would write the file back after the
        // unlink, so the queue is dropped first.
        if (root.fetchingId === photo.id)
            root.skip()
        root.forget(photo.id)
        WallpaperService.removeWallpaper(
            `${root.wallpaperDirectory}/${root.nameOf(photo)}`)
    }

    function forget(id: string): void {
        root.fetched = root.fetched.filter(entry => entry !== id)
    }
}
