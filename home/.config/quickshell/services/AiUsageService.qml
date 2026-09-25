// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A I   U S A G E   S E R V I C E                                         │
// │   how much the assistant has been used · read from the transcripts      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// Token and message counts for the coding assistants this machine runs,
// whichever one the settings name.
//
// The counts come from the transcripts on disk, where every assistant turn
// records what it cost in tokens; nothing is sent anywhere to learn them.
// A ring is a spent *quota* rather than a spent block: the numbers are
// measured against whatever limit the settings set, and when there is no
// limit the ring shows the block's own elapsed time and is drawn as a
// guess, never as a measurement.
//
// Runs only while subscribed; the first pass over the transcripts is a scan.
Singleton {
    id: root

    // The block is five hours; two-minute resolution is plenty.
    readonly property int pollInterval: 120000

    property int watchers: 0
    property bool available: false

    // What this machine can be measured against: the script that counts the
    // tokens is also what knows which transcripts exist, so the settings page
    // asks it rather than keeping a list of its own.
    property var sources: []

    // Query once on construction: the bar only builds the module once
    // `available` is true, so nothing would subscribe otherwise.
    Component.onCompleted: {
        root.askSources()
        root.refresh()
    }

    // The sources are asked for once and then left alone: a transcript folder
    // appearing mid-session is a reason to reload the shell, not to keep a
    // scan running for a settings list.
    function askSources(): void {
        root.sourceQuery.command = [Quickshell.shellPath("scripts/ai_usage.py"),
            "providers"]
        root.sourceQuery.running = true
    }

    readonly property Process sourceQuery: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                let list = null
                try {
                    list = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the assistant list:", error)
                    return
                }
                if (!list || list.available !== true)
                    return
                root.sources = (list.providers ?? []).map(entry => ({
                    id: entry.id ?? "",
                    label: entry.label ?? "",
                    note: entry.note ?? "",
                    ready: entry.available === true
                }))
            }
        }
    }

    property string provider: ""
    property string label: ""
    property real blockStart: 0
    property real blockEnd: 0
    property int blockTokens: 0
    property int blockMessages: 0
    property int weekTokens: 0
    property int weekMessages: 0
    property int peakBlockTokens: 0
    property int peakWeekTokens: 0
    property int inputTokens: 0
    property int outputTokens: 0
    property int cacheWriteTokens: 0
    property int cacheReadTokens: 0
    property int weekInputTokens: 0
    property int weekOutputTokens: 0
    property int weekCacheWriteTokens: 0
    property int weekCacheReadTokens: 0
    property real cost: 0
    property var models: []
    property bool connected: false
    property string reason: ""

    // ── THE RING ────────────────────────────────────────────────────────────
    //
    // Filled against the limit in the settings. Without a limit the ring
    // shows the block's elapsed time instead, and `measured` says so, so
    // nothing draws a spent quota it never measured.

    // Five hours is the shape of a session's block, whatever filled it.
    readonly property real blockSpan: 5 * 3600 * 1000

    readonly property real blockLimit:
        SettingsService.aiBlockQuota > 0 ? SettingsService.aiBlockQuota : 0
    readonly property real weekLimit:
        SettingsService.aiWeekQuota > 0 ? SettingsService.aiWeekQuota : 0

    readonly property bool sessionMeasured: root.available && root.blockLimit > 0
    readonly property bool weeklyMeasured: root.available && root.weekLimit > 0
    readonly property bool measured: root.sessionMeasured || root.weeklyMeasured

    // What the settings set as a fraction of the limit, 0–1.
    readonly property real sessionFraction: root.sessionMeasured
        ? Math.max(0, Math.min(1, root.blockTokens / root.blockLimit))
        : 0
    readonly property real weeklyFraction: root.weeklyMeasured
        ? Math.max(0, Math.min(1, root.weekTokens / root.weekLimit))
        : 0

    // Without a limit the block still has a shape, and the time spent in it
    // is the honest stand-in for a spent one.
    readonly property real elapsed: {
        if (!root.available || root.blockStart <= 0)
            return 0
        const now = root.clock.date.getTime()
        const end = root.blockEnd * 1000
        const start = root.blockStart * 1000
        if (end <= start)
            return 0
        return Math.max(0, Math.min(1, (now - start) / (end - start)))
    }

    // Wall clock, so the countdown advances between polls.
    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.watchers > 0
    }

    readonly property real blockEnds: root.blockEnd
    readonly property real remaining: {
        if (!root.available || root.blockEnds <= 0)
            return 0
        return Math.max(0, root.blockEnds * 1000 - root.clock.date.getTime())
    }

    // "resets in 3 h 53 min"
    readonly property string resetsIn: {
        if (!root.available || root.remaining <= 0)
            return ""
        const total = Math.floor(root.remaining / 1000)
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor((total % 3600) / 60)
        if (hours > 0)
            return `resets in ${hours} h ${minutes} min`
        if (minutes > 0)
            return `resets in ${minutes} min`
        return "resets now"
    }

    // The ring to draw: the fuller of the block and the week, and the worst
    // state across them, which is what the bar tints by.
    readonly property real gauge: root.measured
        ? Math.max(root.sessionFraction, root.weeklyFraction)
        : root.elapsed

    readonly property real worst: Math.max(
        root.sessionMeasured ? root.sessionFraction : 0,
        root.weeklyMeasured ? root.weeklyFraction : 0)

    // A limit of zero means the settings did not set one, and the ring falls
    // back to the block's own time rather than pretending to be measured.
    readonly property real blockFraction: root.sessionMeasured
        ? root.sessionFraction
        : root.elapsed

    // The week's bar with no quota set is drawn against the best week the
    // transcripts still hold, so it is a reading of this desk's own history
    // rather than of a limit nobody wrote down.
    readonly property real weekBarFraction: root.weeklyMeasured
        ? root.weeklyFraction
        : (root.peakWeekTokens > 0
            ? Math.max(0, Math.min(1, root.weekTokens / root.peakWeekTokens)) : 0)

    readonly property string state: {
        if (!root.available)
            return "idle"
        if (root.measured && root.worst >= 0.9)
            return "bad"
        if (root.measured && root.worst >= 0.6)
            return "warn"
        return "good"
    }

    readonly property color tone: {
        if (!root.measured)
            return Theme.indicator
        if (root.worst >= 0.9)
            return Theme.indicatorBad
        if (root.worst >= 0.6)
            return Theme.indicatorWarn
        return Theme.indicator
    }

    // "84 messages", "1.2k messages".
    function messages(count: int): string {
        return `${root.compact(count)} message${count === 1 ? "" : "s"}`
    }

    // 1.2k, 34k, 8.7M.
    function compact(tokens: int): string {
        if (tokens >= 1000000)
            return `${(tokens / 1000000).toFixed(1)}M`
        if (tokens >= 1000)
            return `${Math.round(tokens / 1000)}k`
        return `${tokens}`
    }

    function percent(fraction: real): string {
        return `${Math.round(fraction * 100)}%`
    }

    // The models of the week, largest first, already windowed by the script.
    function modelShare(): real {
        if (!root.models || root.weekTokens <= 0)
            return 0
        const counted = root.models.reduce(
            (sum, entry) => sum + (entry.tokens ?? 0), 0)
        if (counted <= 0)
            return 0
        const top = root.models.reduce(
            (best, entry) => Math.max(best, entry.tokens ?? 0), 0)
        return top / counted
    }

    function subscribe(): void {
        root.watchers += 1
        root.refresh()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function refresh(): void {
        root.query.command = [
            Quickshell.shellPath("scripts/ai_usage.py"), "usage",
            SettingsService.aiProvider || "all",
        ]
        root.query.running = true
    }

    readonly property Timer poller: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }

    readonly property Process query: Process {
        stdout: StdioCollector {
            // Per stream, not per chunk: partial JSON doesn't parse.
            onStreamFinished: {
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the AI usage report:", error)
                    return
                }
                if (report.available !== true) {
                    // Nothing to draw: the reason says whether this machine
                    // has no transcripts, or has not used anything yet.
                    root.available = false
                    root.connected = report.connected === true
                    root.reason = report.reason ?? ""
                    root.models = []
                    return
                }
                root.available = true
                root.connected = true
                root.reason = ""
                root.provider = report.provider ?? ""
                root.label = report.label ?? ""
                root.blockStart = report.blockStart
                root.blockEnd = report.blockEnd
                root.blockTokens = report.blockTokens
                root.blockMessages = report.blockMessages
                root.weekTokens = report.weekTokens
                root.weekMessages = report.weekMessages
                root.peakBlockTokens = report.peakBlockTokens
                root.peakWeekTokens = report.peakWeekTokens
                root.inputTokens = report.inputTokens
                root.outputTokens = report.outputTokens
                root.cacheWriteTokens = report.cacheWriteTokens
                root.cacheReadTokens = report.cacheReadTokens
                root.weekInputTokens = report.weekInputTokens
                root.weekOutputTokens = report.weekOutputTokens
                root.weekCacheReadTokens = report.weekCacheReadTokens
                root.weekCacheWriteTokens = report.weekCacheWriteTokens
                root.cost = report.cost
                root.models = report.models ?? []
            }
        }
    }
}
