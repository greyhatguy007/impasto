// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   U N S P L A S H   S E R V I C E                                        │
// │   wallpapers from unsplash and picsum · via scripts/unsplash.py          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The gallery behind Settings → Integrations → Wallpaper. One search asks
// `scripts/unsplash.py`, which answers with Unsplash's own photos when an
// access key is set and Picsum's curated ones when there is none — the
// shell can't tell the difference, and neither has to sign in.
//
// Photos are downloaded with curl into the wallpaper directory under a
// `Unsplash – <artist>` name, so they join the ordinary gallery and are
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
    // opening the settings never spends the provider's patience.
    function subscribe(): void {
        root.watchers += 1
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    // ── STATE ───────────────────────────────────────────────────────────────

    // True once the script has answered at all; its absence is the settings
    // row's reading when nothing works.
    property bool available: false
    // "unsplash", "picsum" or "" — what the last search actually used.
    property string provider: ""
    // "setup", "auth", "provider", "network" or "" — from the script.
    property string reason: ""
    property bool busy: false

    // Every photo of the current search, as the script reported them.
    property var photos: []
    // The ids whose full picture is already on disk.
    property var fetched: []
    // The id of the photo downloading right now, for the progress row.
    property string fetchingId: ""
    property int generation: 0

    // ── SEARCH ──────────────────────────────────────────────────────────────

    property bool fetchOnArrival: false
    property var queue: []
    property int runningId: 0

    function consider(variation = 0): void {
        if (root.watchers === 0)
            return
        root.busy = true
        root.generation += 1
        root.query.command = [Quickshell.shellPath("scripts/unsplash.py"),
            "search", "24", `${variation}`]
        root.query.running = true
    }

    // A new batch. `after` is optional: a callback run once the search has
    // come back and the first fetch has been queued, so the browse flow is
    // one click. `variation` pages the provider, so Shuffle hands back a
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

    // Names on disk: `Unsplash – <artist>.jpg`. A same-artist pair is
    // disambiguated by the photo id, so nothing is overwritten.
    function nameOf(photo): string {
        const artist = (photo.artist ?? "").replace(/[\\/:*?"<>|]/g, "").trim()
        const base = artist !== "" ? `Unsplash – ${artist}` : "Unsplash"
        return `${base} (${photo.id}).jpg`
    }

    function isFetched(id: string): bool {
        return root.fetched.indexOf(id) >= 0
    }

    function fetch(photo): void {
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

    function parse(text: string): var {
        if (!text || text.trim() === "")
            return null
        try {
            return JSON.parse(text)
        } catch (error) {
            console.warn("Cannot parse the unsplash report:", error)
            return null
        }
    }

    readonly property Process query: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false
                const report = root.parse(text)
                if (!report || report.available !== true) {
                    root.available = false
                    root.provider = ""
                    root.reason = report?.reason ?? "network"
                    return
                }
                root.available = true
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

        onExited: exitCode => {
            root.busy = false
        }
    }

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
}
