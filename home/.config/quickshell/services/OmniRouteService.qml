// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   O M N I   R O U T E   S E R V I C E                                    │
// │   the gateway's own numbers · what it served, and how it is            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// A remote OmniRoute gateway, as it describes itself.
//
// OmniRoute routes model requests across many providers and keeps a
// dashboard's worth of numbers about the traffic: what was spent, which
// provider carried it, which model it lived in, how healthy each connection
// is, and how much room the server has left. This reads those management
// routes — never a model request — so the widget is a window on the gateway
// rather than on this machine's own history.
//
// The endpoint and the key come from Settings → Integrations. They are passed
// to the script on its command line and nowhere else; nothing here logs them.
// Runs only while subscribed, and one process serves every widget on screen.
Singleton {
    id: root

    // Cost and usage move slowly; a minute is plenty, and the script is a
    // handful of requests.
    readonly property int pollInterval: 60000

    property int watchers: 0
    property bool available: false
    property bool connected: false
    property string reason: ""
    property string endpoint: ""

    // True once an address is set: the widget may be placed before the first
    // answer, and the detail says it is asking rather than that it failed.
    readonly property bool configured: SettingsService.omniEndpoint.trim() !== ""

    // "day", "week" or "month" — what the analytics figures span.
    property string range: "day"

    property var summary: null
    property var trend: []
    property var models: []
    property var byProvider: []
    property var accounts: []
    property var tiers: []
    property var weekly: []
    property var connections: []
    property var callLogs: []
    property var history: null
    property var keys: []
    property var budget: null
    property var health: null
    property var storage: null
    property var cache: null
    property var rateLimits: []
    property var tokenHealth: null
    property var telemetry: null
    property var resilience: null
    property var activity: []
    property var combos: []
    property var errors: ({})

    property real fetchedAt: 0
    property bool loading: false

    // The settings pane's one-off ask, separate from the poll.
    property bool testing: false
    property var answer: null

    Component.onCompleted: root.refresh()

    function subscribe(): void {
        root.watchers += 1
        if (root.watchers === 1)
            root.refresh()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    // ── ASKING ──────────────────────────────────────────────────────────────

    function arguments(): var {
        const args = []
        const endpoint = SettingsService.omniEndpoint.trim()
        if (endpoint !== "")
            args.push("--endpoint", endpoint)
        if (SettingsService.omniApiKey !== "")
            args.push("--key", SettingsService.omniApiKey.trim())
        return args
    }

    // No guard on `configured`: the settings file may not be read yet when
    // the shell builds the widget, and the script reads the endpoint and key
    // itself anyway, falling back to pi's provider entry. A gateway that is
    // genuinely unset is the script's own `"setup"` answer.
    function refresh(): void {
        root.loading = true
        root.query.command = [Quickshell.shellPath("scripts/omniroute.py"),
            "report", `--${root.range}`].concat(root.arguments())
        root.query.running = true
    }

    // Pointed at a different gateway (or given a key) in Settings, the next
    // report should come from there rather than wait out the poll.
    readonly property Connections settings: Connections {
        target: SettingsService
        function onOmniEndpointChanged(): void { root.refresh() }
        function onOmniApiKeyChanged(): void { root.refresh() }
    }

    function setRange(value: string): void {
        if (root.range === value)
            return
        root.range = value
        root.refresh()
    }

    // The settings pane's button: the same ask, cut to whether it answered.
    function test(): void {
        root.answer = null
        root.testing = true
        root.probe.command = [Quickshell.shellPath("scripts/omniroute.py"),
            "test"].concat(root.arguments())
        root.probe.running = true
    }

    // ── PROCESSES ───────────────────────────────────────────────────────────

    readonly property Process query: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the gateway report:", error)
                    return
                }
                root.adopt(report)
            }
        }
    }

    readonly property Process probe: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.testing = false
                try {
                    root.answer = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the gateway answer:", error)
                    root.answer = { available: false, reason: "server" }
                }
            }
        }
    }

    readonly property Timer poller: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }

    function adopt(report): void {
        if (!report || report.available !== true) {
            root.available = false
            root.connected = report?.connected === true
            root.reason = report?.reason ?? "network"
            root.summary = null
            root.trend = []
            root.models = []
            root.byProvider = []
            root.accounts = []
            root.tiers = []
            root.weekly = []
            root.connections = []
            root.callLogs = []
            root.history = null
            root.keys = []
            root.budget = null
            root.health = null
            root.storage = null
            root.cache = null
            root.rateLimits = []
            root.tokenHealth = null
            root.telemetry = null
            root.resilience = null
            root.activity = []
            root.combos = []
            return
        }
        root.available = true
        root.connected = true
        root.reason = ""
        root.endpoint = report.endpoint ?? ""
        root.summary = report.summary ?? null
        root.trend = report.trend ?? []
        root.models = report.models ?? []
        root.byProvider = report.byProvider ?? []
        root.accounts = report.accounts ?? []
        root.tiers = report.tiers ?? []
        root.weekly = report.weekly ?? []
        root.connections = report.connections ?? []
        root.callLogs = report.callLogs ?? []
        root.history = report.history ?? null
        root.keys = report.keys ?? []
        root.budget = report.budget ?? null
        root.health = report.health ?? null
        root.storage = report.storage ?? null
        root.cache = report.cache ?? null
        root.rateLimits = report.rateLimits ?? []
        root.tokenHealth = report.tokenHealth ?? null
        root.telemetry = report.telemetry ?? null
        root.resilience = report.resilience ?? null
        root.activity = report.activity ?? []
        root.combos = report.combos ?? []
        root.errors = report.errors ?? ({})
        root.fetchedAt = Number(report.fetchedAt ?? 0)
    }

    // ── READINGS ────────────────────────────────────────────────────────────

    readonly property int requests: root.summary?.requests ?? 0
    readonly property int tokens: root.summary?.tokens ?? 0
    readonly property real cost: root.summary?.cost ?? 0
    readonly property real success: root.summary?.successRate ?? 0
    readonly property int latency: root.summary?.latency ?? 0
    readonly property int modelCount: root.summary?.models ?? 0
    readonly property int streak: root.summary?.streak ?? 0
    readonly property real coverage: root.summary?.coverage ?? 0

    // The success ring, clamped; nothing is drawn as more than full.
    readonly property real quality: root.available
        ? Math.max(0, Math.min(1, root.success / 100)) : 0

    // The tokens per bucket of the trend, for the sparkline.
    readonly property var trendTokens: (root.trend ?? []).map(entry => entry.tokens ?? 0)
    readonly property var trendRequests: (root.trend ?? []).map(entry => entry.requests ?? 0)

    readonly property string toneState: {
        if (!root.available)
            return "idle"
        if (root.success >= 95)
            return "good"
        if (root.success >= 85)
            return "warn"
        return "bad"
    }

    readonly property color tone: {
        if (!root.available)
            return Theme.indicator
        if (root.success >= 95)
            return Theme.indicatorGood
        if (root.success >= 85)
            return Theme.indicatorWarn
        return Theme.indicatorBad
    }

    readonly property string statusNote: {
        if (!root.configured)
            return Tr.t("no endpoint set")
        if (root.available)
            return root.health?.status ?? Tr.t("connected")
        switch (root.reason) {
        case "auth":
            return Tr.t("the key was refused")
        case "unrouted":
            return Tr.t("this server speaks only the model API")
        case "network":
            return Tr.t("the endpoint did not answer")
        case "server":
            return Tr.t("the server answered badly")
        case "setup":
            return Tr.t("no gateway configured")
        default:
            return Tr.t("waiting for the gateway")
        }
    }

    // The endpoint without its scheme, for a compact caption.
    readonly property string host: root.endpoint
        .replace(/^https?:\/\//, "").replace(/\/+$/, "")

    // The share of the traffic the busiest provider carries, for the list.
    readonly property int busiestTokens: {
        let best = 0
        for (const entry of root.byProvider)
            best = Math.max(best, entry.tokens ?? 0)
        return best
    }

    // The busiest day of the week pattern, for the seven little bars.
    readonly property real weekMaxTokens: {
        let best = 1
        for (const day of root.weekly)
            best = Math.max(best, day.tokens ?? 0)
        return best
    }

    // The busiest day of the whole window, for the 4×4 face's day bars.
    readonly property real activityMaxTokens: {
        let best = 1
        for (const day of root.activity)
            best = Math.max(best, day.tokens ?? 0)
        return best
    }

    // The spend against the gateway's budget, as a fraction. A gateway with
    // no limit set has no fraction: the face draws the sum and says so.
    readonly property var budgetInfo: root.budget ?? null
    readonly property bool budgeted: (root.budgetInfo?.hasLimit ?? false)
    readonly property real budgetFraction: root.budgeted
        ? Math.max(0, Math.min(1, root.budgetInfo.fraction ?? 0)) : 0
    readonly property color budgetTone: root.budgetFraction >= 0.9
        ? Theme.indicatorBad : (root.budgetFraction >= 0.75
            ? Theme.indicatorWarn : Theme.accent)

    // ── FORMATTING ──────────────────────────────────────────────────────────

    // 1.2k, 34k, 8.7M, 1.4B.
    function compact(value): string {
        const number = Number(value ?? 0)
        if (number >= 1e9)
            return `${(number / 1e9).toFixed(1)}B`
        if (number >= 1e6)
            return `${(number / 1e6).toFixed(1)}M`
        if (number >= 1000)
            return `${Math.round(number / 1000)}k`
        return `${Math.round(number)}`
    }

    // "$130.30", "$0.0103" — small sums keep a sign of life.
    function money(value): string {
        const number = Number(value ?? 0)
        if (number >= 1)
            return `$${number.toFixed(2)}`
        if (number > 0)
            return `$${number.toFixed(4)}`
        return "$0"
    }

    function percent(value): string {
        return `${Math.round(Number(value ?? 0) * 100)}%`
    }

    // Milliseconds as "5.6 s" or "820 ms".
    function seconds(ms): string {
        const number = Number(ms ?? 0)
        if (number >= 1000)
            return `${(number / 1000).toFixed(1)} s`
        return `${Math.round(number)} ms`
    }

    // A byte count as "1.0 GB", "32.0 MB".
    function bytes(value): string {
        const number = Number(value ?? 0)
        if (number >= 1e9)
            return `${(number / 1e9).toFixed(1)} GB`
        if (number >= 1e6)
            return `${(number / 1e6).toFixed(1)} MB`
        if (number >= 1e3)
            return `${(number / 1e3).toFixed(1)} kB`
        return `${Math.round(number)} B`
    }

    // Seconds as "3 d 4 h", "5 h 12 min", "8 min".
    function duration(seconds): string {
        const total = Math.max(0, Math.floor(Number(seconds ?? 0)))
        const days = Math.floor(total / 86400)
        const hours = Math.floor((total % 86400) / 3600)
        const minutes = Math.floor((total % 3600) / 60)
        if (days > 0)
            return `${days} ${Tr.t("d")} ${hours} ${Tr.t("h")}`
        if (hours > 0)
            return `${hours} ${Tr.t("h")} ${minutes} ${Tr.t("min")}`
        return `${minutes} ${Tr.t("min")}`
    }

    // When the figures were last read, as "just now", "3 min ago".
    function ago(when): string {
        if (!when || when <= 0)
            return ""
        const seconds = Math.max(0, Math.floor(Date.now() / 1000 - when))
        if (seconds < 45)
            return Tr.t("just now")
        if (seconds < 3600)
            return Tr.t("%1 min ago").arg(Math.floor(seconds / 60))
        if (seconds < 86400)
            return Tr.t("%1 h ago").arg(Math.floor(seconds / 3600))
        return Tr.t("%1 d ago").arg(Math.floor(seconds / 86400))
    }

    // A gateway timestamp (ISO 8601) as "just now"/"3 min ago".
    function isoAgo(when): string {
        if (!when)
            return ""
        const ms = Date.parse(when)
        if (!isFinite(ms))
            return ""
        return root.ago(Math.floor(ms / 1000))
    }

    // An HTTP status as the tone it deserves: a success green, a rate limit
    // or a bad request amber, a server error red.
    function statusColor(status): color {
        const code = Number(status ?? 0)
        if (code >= 200 && code < 300)
            return Theme.indicatorGood
        if (code >= 500)
            return Theme.indicatorBad
        if (code >= 400)
            return Theme.indicatorWarn
        return Theme.textMuted
    }

    // A connection's status as the state it is in.
    function connectionState(entry): string {
        if (!entry)
            return "unknown"
        if (entry.active !== true)
            return "off"
        if (entry.status === "active")
            return "good"
        if (entry.status === "expired" || entry.status === "error")
            return "bad"
        return "warn"
    }

    function connectionColor(entry): color {
        const state = root.connectionState(entry)
        if (state === "good")
            return Theme.indicatorGood
        if (state === "bad")
            return Theme.indicatorBad
        if (state === "warn")
            return Theme.indicatorWarn
        return Theme.textMuted
    }
}
