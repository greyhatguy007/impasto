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

    // ── THE SERVER'S OWN FIGURES ───────────────────────────────────────────
    //
    // Only a gateway can know what plan its traffic is on and when that
    // plan's window rolls. OmniRoute will say at
    // `/api/usage/om-usage?format=json` with the same key a model request
    // uses. What comes back is the plan and the time its window resets — the
    // provider's own clock, where ours is a guess.
    //
    // When it is there it is what the countdown says, and the tokens stay as
    // the spend. When it is not, `gatewayNote` says which of the ways it was
    // not, because "the server does not know" and "this key may not ask" are
    // different things to go and fix.
    property var gateway: null

    // The server said something worth showing: a plan, a reset, or both.
    readonly property bool gatewayKnows: {
        const answer = root.gateway
        if (!answer || answer.available !== true)
            return false
        return (answer.plan !== null && answer.plan !== undefined)
            || !!answer.resetsAt
    }

    readonly property string plan: {
        const name = root.gateway?.plan
        if (name === null || name === undefined)
            return ""
        return String(name)
    }

    // "3 d 4 h", from the server's own reset time rather than from the block's
    // clock, which is a guess about when a subscription's window rolls.
    readonly property string gatewayResets: root.gatewayKnows
        ? root.resetsFrom(root.gateway.resetsAt)
        : ""

    // A short line for the face, and the whole reason in one sentence. One
    // function, so the face, the module and the settings pane all describe
    // the same answer the same way.
    readonly property string gatewayNote: root.gatewaySummary(root.gateway)

    function gatewaySummary(report: var): string {
        if (!report)
            return ""
        if (report.available === true) {
            if (report.plan === null || report.plan === undefined)
                return Tr.t("the server does not know your plan's window yet")
            return `${Tr.t("on")} ${report.plan}`
        }
        switch (report.reason) {
        case "forbidden":
            return Tr.t("this key may not ask for usage")
        case "unrouted":
            return Tr.t("this server speaks only the model API")
        case "auth":
            return Tr.t("this server refused the key")
        case "setup":
            return Tr.t("no gateway configured")
        case "server":
            return Tr.t("the server answered badly")
        default:
            return Tr.t("the server could not be asked")
        }
    }

    // What to do about it, for the settings pane: the reason alone is a
    // dead end, and each of these has a different fix.
    function gatewayAdvice(report: var): string {
        switch (report?.reason) {
        case "forbidden":
            return Tr.t("in the gateway's API manager, allow the local usage command for this key")
        case "unrouted":
            return Tr.t("it answers models but not usage — nothing to change here")
        case "auth":
            return Tr.t("check the key and the endpoint, then ask again")
        case "setup":
            return Tr.t("set an endpoint and a key, or let pi's own provider entry name the gateway")
        case "network":
            return Tr.t("the endpoint did not answer — check the address and the network")
        case "server":
            return Tr.t("the endpoint answered badly — try again in a moment")
        default:
            return ""
        }
    }

    // A reset time, in the shell's words, from whatever a server sent.
    function resetsFrom(when): string {
        if (!when)
            return ""
        const ms = Date.parse(when)
        if (!isFinite(ms))
            return ""
        const left = ms - root.clock.date.getTime()
        if (left <= 0)
            return Tr.t("resets now")
        const minutes = Math.max(1, Math.ceil(left / 60000))
        const days = Math.floor(minutes / 1440)
        const hours = Math.floor((minutes % 1440) / 60)
        if (days > 0)
            return `${Tr.t("resets in")} ${days} ${Tr.t("d")} ${hours} ${Tr.t("h")}`
        if (hours > 0)
            return `${Tr.t("resets in")} ${hours} ${Tr.t("h")} ${minutes % 60} ${Tr.t("min")}`
        return `${Tr.t("resets in")} ${minutes} ${Tr.t("min")}`
    }

    // ── ASKING IT ON PURPOSE ───────────────────────────────────────────────
    //
    // The settings pane's button, so an endpoint or a key can be tried
    // without waiting for a poll to notice. The answer lands in one line,
    // and the same wording the face uses, so a fix found here is a fix
    // there too.
    property bool testing: false
    readonly property bool gatewayFault: root.answer?.available !== true

    property var answer: null
    readonly property string answerNote: {
        const report = root.answer
        if (!report)
            return ""
        if (report.available === true) {
            const plan = root.gatewaySummary(report)
            const reset = root.resetsFrom(report.resetsAt)
            const models = typeof report.models === "number" && report.models > 0
                ? Tr.t("%1 models").arg(report.models) : ""
            return [plan, reset, models].filter(part => part !== "").join(" · ")
        }
        const advice = root.gatewayAdvice(report)
        return root.gatewaySummary(report) + (advice !== "" ? ` — ${advice}` : "")
    }

    // ── THE RING ────────────────────────────────────────────────────────────
    //
    // Tokens, against the biggest this desk has itself seen: a block against
    // the busiest block, a week against the busiest week. Nothing here is a
    // limit — no number to type, nothing to fall out of step with a plan, and
    // the ring means the same thing on every machine. With no history to
    // measure against, the block's own elapsed time stands in, and `measured`
    // says so, so nothing draws a comparison it never made.

    // Five hours is the shape of a session's block, whatever filled it.
    readonly property real blockSpan: 5 * 3600 * 1000

    // This block against the busiest block the transcripts still hold.
    readonly property real blockShare: root.peakBlockTokens > 0
        ? Math.max(0, Math.min(1, root.blockTokens / root.peakBlockTokens))
        : 0

    // This week against the busiest week on record.
    readonly property real weekShare: root.peakWeekTokens > 0
        ? Math.max(0, Math.min(1, root.weekTokens / root.peakWeekTokens))
        : 0

    readonly property bool measured: root.available
        && (root.peakBlockTokens > 0 || root.peakWeekTokens > 0)

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

    // The ring to draw: the bigger of the two against this desk's own record.
    // A block with nothing to compare it to is drawn as the time it has been
    // running, which is the one honest thing left to draw.
    readonly property real gauge: root.measured
        ? Math.max(root.blockShare, root.weekShare)
        : root.elapsed

    readonly property real worst: Math.max(root.blockShare, root.weekShare)

    // A block with history behind it is drawn against it; a first block falls
    // back to its own clock.
    readonly property real blockFraction: root.peakBlockTokens > 0
        ? root.blockShare
        : root.elapsed

    // The week's bar against the busiest week on record: a reading of this
    // desk's own history rather than of a limit nobody wrote down.
    readonly property real weekBarFraction: root.weekShare

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

    // The gateway to ask, when the settings name one. Nothing is passed when
    // they do not, and the script falls back to pi's own provider entry rather
    // than to a guess at one. The key rides on the command line and nowhere
    // else: it is read, never stored here and never logged.
    function gatewayArgs(): var {
        if (SettingsService.omniEndpoint === "")
            return []
        const args = ["--endpoint", SettingsService.omniEndpoint.trim()]
        if (SettingsService.omniApiKey !== "")
            args.push("--key", SettingsService.omniApiKey.trim())
        return args
    }

    function refresh(): void {
        const command = [
            Quickshell.shellPath("scripts/ai_usage.py"), "usage",
            SettingsService.aiProvider || "all",
        ].concat(root.gatewayArgs())
        root.query.command = command
        root.query.running = true
    }

    // The settings pane's button: the same ask the poll makes, on demand.
    function testGateway(): void {
        root.answer = null
        root.testing = true
        const command = [
            Quickshell.shellPath("scripts/ai_usage.py"), "gateway",
        ].concat(root.gatewayArgs())
        root.probe.command = command
        root.probe.running = true
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
                    root.gateway = report.gateway ?? null
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
                root.gateway = report.gateway ?? null
            }
        }
    }
}
