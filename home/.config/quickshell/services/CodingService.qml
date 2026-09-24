// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O D I N G   S E R V I C E                                            │
// │   a year of practice · leetcode or codeforces, via scripts/coding.py     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// A rolling year of practice from LeetCode or Codeforces, in the same
// week-column shape the GitHub graph uses, so the same grid draws it.
//
// Which platform is shown is `SettingsService.codingPlatform`: `auto` prefers
// LeetCode when a handle is set there, Codeforces otherwise. The service polls
// only while something is subscribed and keeps the last good grid when a
// request fails; a reading is cached per platform, so switching back is
// instant.
Singleton {
    id: root

    readonly property int pollInterval: 1800000

    property int watchers: 0
    property bool available: false

    // Reports kept for the session, keyed by platform id: `{ report, at }`.
    property var cache: ({})

    // First read happens when anything touches the singleton. With no handle
    // configured it returns immediately.
    Component.onCompleted: root.refresh()

    // ── WHICH PLATFORM ──────────────────────────────────────────────────────
    //
    // Both handles are machine settings; `codingPlatform` is the choice.
    readonly property string leetcodeHandle: SettingsService.leetcodeUser.trim()
    readonly property string codeforcesHandle: SettingsService.codeforcesUser.trim()

    readonly property var platforms: [
        { id: "leetcode", label: "LeetCode", handle: root.leetcodeHandle },
        { id: "codeforces", label: "Codeforces", handle: root.codeforcesHandle }
    ]

    readonly property var configured: root.platforms.filter(entry => entry.handle !== "")

    readonly property string platform: {
        const chosen = SettingsService.codingPlatform
        if (chosen === "leetcode" && root.leetcodeHandle !== "")
            return "leetcode"
        if (chosen === "codeforces" && root.codeforcesHandle !== "")
            return "codeforces"
        return root.leetcodeHandle !== "" ? "leetcode" : "codeforces"
    }

    readonly property var platformEntry: root.platforms.find(entry => entry.id === root.platform)
        ?? root.platforms[0]
    readonly property string platformName: root.platformEntry.label
    readonly property string handle: root.platformEntry.handle

    function setPlatform(id: string): void {
        SettingsService.set("codingPlatform", id)
    }

    // ── THE READING ─────────────────────────────────────────────────────────

    property string user: ""
    property int total: 0
    property int streak: 0
    property int today: 0
    property int busiest: 0
    property string source: ""

    // One array per week, seven entries each (Sunday first): a level 0-4, or
    // null for days outside the range in the partial first and last weeks.
    property var weeks: []
    property date readAt: new Date(0)

    // True when the active platform's configured handle has no profile.
    property bool userUnknown: false

    // The platform the in-flight query was started for, so a toggle mid-query
    // does not file the answer under the wrong one.
    property string queried: ""

    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.watchers > 0
    }

    readonly property string age: {
        if (!root.available)
            return ""
        const minutes = Math.floor((root.clock.date.getTime() - root.readAt.getTime()) / 60000)
        if (minutes < 2)
            return "just now"
        if (minutes < 60)
            return `${minutes} min ago`
        const hours = Math.round(minutes / 60)
        return `${hours} h ago`
    }

    // "3689" -> "3,689", as GitHub writes it. Shared by every face.
    function grouped(count: int): string {
        return `${count}`.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    }

    readonly property string totalLabel: root.grouped(root.total)

    function subscribe(): void {
        root.watchers += 1
        const minutes = (new Date().getTime() - root.readAt.getTime()) / 60000
        if (!root.available || minutes > 15)
            root.refresh()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function adopt(report, at): void {
        root.user = report.user ?? ""
        root.source = report.source ?? ""
        root.total = report.total ?? 0
        root.streak = report.streak ?? 0
        root.today = report.today ?? 0
        root.busiest = report.busiest ?? 0
        root.weeks = report.weeks ?? []
        root.readAt = new Date(at)
        root.available = true
    }

    function refresh(): void {
        if (root.handle === "") {
            root.available = false
            root.weeks = []
            root.userUnknown = false
            return
        }
        // A reading already held for this platform shows at once; the poller
        // still refreshes it in the background.
        const kept = root.cache[root.platform]
        if (kept !== undefined)
            root.adopt(kept.report, kept.at)
        root.queried = root.platform
        root.query.running = true
    }

    readonly property Timer poller: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }

    // A new handle or platform is a different reading; fetch it now.
    Connections {
        target: SettingsService

        function onLeetcodeUserChanged(): void { root.refresh() }
        function onCodeforcesUserChanged(): void { root.refresh() }
        function onCodingPlatformChanged(): void { root.refresh() }
    }

    readonly property Process query: Process {
        command: [Quickshell.shellPath("scripts/coding.py"), root.platform, root.handle]

        stdout: StdioCollector {
            onStreamFinished: {
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the coding report:", error)
                    return
                }
                const platform = root.queried
                root.userUnknown = report.reason === "user"
                    && root.platforms.find(entry => entry.id === platform)?.handle !== ""
                if (report.available !== true) {
                    // Keep the last good grid on failure; clear it only when
                    // the handle has been removed.
                    if (root.handle === "")
                        root.available = false
                    return
                }
                const at = Date.now()
                root.cache[platform] = { report: report, at: at }
                if (platform === root.platform)
                    root.adopt(report, at)
            }
        }
    }
}
