// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O D I N G   S E R V I C E                                            │
// │   a year of activity · github, leetcode, codeforces and gitlab           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// A rolling year of activity from every platform that has a handle set:
// GitHub, LeetCode, Codeforces and GitLab, all in the same week-column shape
// (seven levels each, Sunday first) so one grid draws any of them.
//
// The view is chosen with `SettingsService.codingPlatform`: one platform, or
// `all`, which adds their days together and caps the sum at the top of the
// ramp — a day reads as how much was done, by anyone. With a single handle
// set there is nothing to choose and that platform is drawn.
//
// GitHub is read by `GithubService`, which polls on its own; the two coding
// platforms are fetched here through `scripts/coding.py`, one at a time, and
// cached per platform so switching back is instant. The last good grid stays
// when a request fails.
Singleton {
    id: root

    readonly property int pollInterval: 1800000

    property int watchers: 0

    // ── SOURCES ─────────────────────────────────────────────────────────────
    //
    // Every platform the shell knows how to draw, with the handle this machine
    // has for it. Empty means the platform is not offered.

    readonly property string githubHandle: SettingsService.githubUser.trim()
    readonly property string leetcodeHandle: SettingsService.leetcodeUser.trim()
    readonly property string codeforcesHandle: SettingsService.codeforcesUser.trim()
    readonly property string gitlabHandle: SettingsService.gitlabUser.trim()

    readonly property var sources: [
        { id: "github",     label: "GitHub",     short: "GH", handle: root.githubHandle },
        { id: "leetcode",   label: "LeetCode",   short: "LC", handle: root.leetcodeHandle },
        { id: "codeforces", label: "Codeforces", short: "CF", handle: root.codeforcesHandle },
        { id: "gitlab",     label: "GitLab",     short: "GL", handle: root.gitlabHandle }
    ]

    // The ones with a handle. The settings page and the faces use it to know
    // whether to say anything at all.
    readonly property var configured: root.sources.filter(entry => entry.handle !== "")

    readonly property bool hasGithub: root.githubHandle !== ""

    // ── WHICH SOURCE ────────────────────────────────────────────────────────

    // The views the toggle offers: everything, then each platform, or the one
    // platform alone when it is the only one set.
    readonly property var platforms: {
        if (root.configured.length === 0)
            return []
        if (root.configured.length === 1)
            return root.configured
        return [{ id: "all", label: "All", short: "All", handle: "" }].concat(root.configured)
    }

    function offers(id: string): bool {
        return root.platforms.some(entry => entry.id === id)
    }

    // The saved choice if it is still offered, everything otherwise; a profile
    // written before `all` existed falls back rather than showing nothing.
    readonly property string platform: {
        const chosen = SettingsService.codingPlatform
        if (root.offers(chosen))
            return chosen
        return root.offers("all") ? "all" : (root.configured[0]?.id ?? "all")
    }

    function setPlatform(id: string): void {
        if (root.offers(id))
            SettingsService.set("codingPlatform", id)
    }

    readonly property var platformEntry:
        root.platforms.find(entry => entry.id === root.platform) ?? root.platforms[0] ?? null
    readonly property string platformName: root.platformEntry ? root.platformEntry.label : ""

    // ── LEETCODE AND CODEFORCES ─────────────────────────────────────────────
    //
    // Fetched here, one at a time, and kept per platform: `{ report, at }`.

    property var cache: ({})
    property var pending: []
    property string queried: ""

    // Handle ids whose profile does not exist, for the settings page.
    property var unknown: ({})

    function handleUnknown(id: string): bool {
        return root.unknown[id] === true
    }

    readonly property var codingSources: root.configured.filter(entry => entry.id !== "github")

    function reportOf(id: string): var {
        const kept = root.cache[id]
        return kept ? kept.report : null
    }

    function countOf(id: string): int {
        if (id === "github")
            return GithubService.total ?? 0
        const report = root.reportOf(id)
        return report ? (report.total ?? 0) : 0
    }

    function todayOf(id: string): int {
        if (id === "github")
            return GithubService.today ?? 0
        const report = root.reportOf(id)
        return report ? (report.today ?? 0) : 0
    }

    // ── WHAT IS DRAWN ───────────────────────────────────────────────────────

    // GitHub is its own reader; the coding platforms are only live once a
    // report has come back.
    readonly property bool githubReady: root.hasGithub && GithubService.available

    // The sources that have something to draw, as grids to be merged.
    readonly property var liveSources: {
        const out = []
        if (root.githubReady)
            out.push({ id: "github", weeks: GithubService.weeks ?? [] })
        for (const entry of root.codingSources) {
            const report = root.reportOf(entry.id)
            if (report && report.available === true)
                out.push({ id: entry.id, weeks: report.weeks ?? [] })
        }
        return out
    }

    // Every platform's day added up, capped at the top of the ramp, in one
    // grid. Aligned from the right: both shapes end on the week holding
    // today, so the last column of either is the same week and older columns
    // line up behind it.
    function combine(list: var): var {
        const sources = (list ?? []).filter(source => (source.weeks ?? []).length > 0)
        if (sources.length === 0)
            return []
        let length = 0
        for (const source of sources)
            length = Math.max(length, source.weeks.length)
        const weeks = []
        for (let col = 0; col < length; col++) {
            const column = []
            for (let row = 0; row < 7; row++) {
                let sum = 0
                let seen = false
                for (const source of sources) {
                    const week = source.weeks[source.weeks.length - length + col]
                    if (!week)
                        continue
                    const level = week[row]
                    if (level === null || level === undefined)
                        continue
                    seen = true
                    sum += level
                }
                column.push(seen ? Math.min(4, sum) : null)
            }
            weeks.push(column)
        }
        return weeks
    }

    readonly property var combinedWeeks: root.combine(root.liveSources)

    readonly property var weeks: {
        if (root.platform === "github")
            return GithubService.weeks ?? []
        if (root.platform === "all")
            return root.combinedWeeks
        const report = root.reportOf(root.platform)
        return report ? (report.weeks ?? []) : []
    }

    // The ramp the platform is drawn in; `All` gets one of its own.
    readonly property var levels: {
        switch (root.platform) {
        case "github":
            return Theme.githubLevels
        case "leetcode":
            return Theme.leetcodeLevels
        case "codeforces":
            return Theme.codeforcesLevels
        case "gitlab":
            return Theme.gitlabLevels
        }
        return Theme.combinedLevels
    }

    readonly property bool available: {
        if (root.platform === "github")
            return root.githubReady
        if (root.platform === "all")
            return root.liveSources.length > 0
        const report = root.reportOf(root.platform)
        return report !== null && report.available === true
    }

    readonly property int total: {
        if (root.platform === "all") {
            let sum = 0
            for (const source of root.liveSources)
                sum += root.countOf(source.id)
            return sum
        }
        return root.countOf(root.platform)
    }

    readonly property string totalLabel: root.grouped(root.total)

    readonly property int today: {
        if (root.platform === "all") {
            let sum = 0
            for (const source of root.liveSources)
                sum += root.todayOf(source.id)
            return sum
        }
        return root.todayOf(root.platform)
    }

    readonly property int streak: root.streakOf(root.weeks)

    readonly property string user: {
        if (root.platform === "github")
            return GithubService.user ?? ""
        if (root.platform === "all")
            return ""
        const report = root.reportOf(root.platform)
        return report ? (report.user ?? "") : ""
    }

    readonly property string source: {
        if (root.platform === "github")
            return GithubService.source ?? ""
        if (root.platform === "all")
            return ""
        const report = root.reportOf(root.platform)
        return report ? (report.source ?? "") : ""
    }

    // ── THE STREAK ──────────────────────────────────────────────────────────

    // The levels from today back, skipping the days a partial last column
    // leaves empty, so a streak is not cut by tomorrow.
    function flattened(weeks: var): var {
        const grid = weeks ?? []
        const out = []
        const startRow = new Date().getDay()
        for (let col = grid.length - 1; col >= 0; col--) {
            const week = grid[col]
            if (!week)
                continue
            const from = col === grid.length - 1 ? startRow : 6
            for (let row = from; row >= 0; row--) {
                const level = week[row]
                if (level === null || level === undefined)
                    continue
                out.push(level)
            }
        }
        return out
    }

    // Today still counts as a live streak before anything is done, as the
    // scripts do.
    function streakOf(weeks: var): int {
        const levels = root.flattened(weeks)
        let streak = 0
        for (let index = 0; index < levels.length; index++) {
            if (levels[index] > 0)
                streak += 1
            else if (index === 0)
                continue
            else
                break
        }
        return streak
    }

    // "3689" -> "3,689", as GitHub writes it. Shared by every face.
    function grouped(count: int): string {
        return `${count}`.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    }

    // ── AGE ─────────────────────────────────────────────────────────────────

    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.watchers > 0
    }

    // The oldest reading on screen, so "All" is as fresh as its stalest half.
    readonly property real oldestRead: {
        const stamps = []
        if (root.githubReady && GithubService.readAt.getTime() > 0)
            stamps.push(GithubService.readAt.getTime())
        for (const entry of root.codingSources) {
            const kept = root.cache[entry.id]
            if (kept)
                stamps.push(kept.at)
        }
        return stamps.length === 0 ? 0 : Math.min.apply(null, stamps)
    }

    readonly property string age: {
        if (root.oldestRead <= 0)
            return ""
        const minutes = Math.floor((root.clock.date.getTime() - root.oldestRead) / 60000)
        if (minutes < 2)
            return "just now"
        if (minutes < 60)
            return `${minutes} min ago`
        const hours = Math.round(minutes / 60)
        return `${hours} h ago`
    }

    // ── READING ─────────────────────────────────────────────────────────────

    // First read happens when anything touches the singleton; with no handle
    // configured there is nothing to ask for.
    Component.onCompleted: root.refresh()

    function subscribe(): void {
        root.watchers += 1
        if (root.hasGithub)
            GithubService.subscribe()
        root.refresh()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
        if (root.hasGithub)
            GithubService.release()
    }

    // The coding platforms read here; GitHub is polled by its own service.
    // A reading already held shows at once and is refreshed only once it is
    // older than the interval.
    function refresh(): void {
        const stale = root.codingSources.filter(entry => {
            const kept = root.cache[entry.id]
            return kept === undefined || (Date.now() - kept.at) > root.pollInterval
        })
        root.pending = stale
        root.pumpQuery()
    }

    function pumpQuery(): void {
        if (root.query.running || root.pending.length === 0)
            return
        const job = root.pending[0]
        root.pending = root.pending.slice(1)
        root.queried = job.id
        root.query.command = [Quickshell.shellPath("scripts/coding.py"), job.id, job.handle]
        root.query.running = true
    }

    function store(id: string, report: var): void {
        // A platform out of reach keeps its last good grid; one that never
        // came back is remembered as unavailable rather than asked again on
        // every refresh.
        const failed = report.available !== true
        if (failed && root.cache[id] !== undefined)
            return
        const next = Object.assign({}, root.cache)
        next[id] = { report: report, at: Date.now() }
        root.cache = next
    }

    readonly property Timer poller: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }

    // A new handle, or the platform chosen, is a different reading.
    readonly property Connections settings: Connections {
        target: SettingsService

        function onLeetcodeUserChanged(): void { root.refresh() }
        function onCodeforcesUserChanged(): void { root.refresh() }
        function onGitlabUserChanged(): void { root.refresh() }
        function onGithubUserChanged(): void { /* GithubService reads it itself */ }
    }

    readonly property Process query: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const id = root.queried
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the coding report:", error)
                    root.pumpQuery()
                    return
                }
                const unknown = Object.assign({}, root.unknown)
                unknown[id] = report.reason === "user"
                    && root.sources.find(entry => entry.id === id)?.handle !== ""
                root.unknown = unknown
                root.store(id, report)
                root.pumpQuery()
            }
        }
    }
}
