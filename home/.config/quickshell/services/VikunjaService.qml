// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   V I K U N J A   S E R V I C E                                          │
// │   tasks from a self-hosted server · read and write                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// The Vikunja side of the board: reads the server's tasks on a timer and
// sends local changes back, both through `scripts/vikunja.py`, which holds the
// URL and token from Settings → Integrations.
//
// It holds no tasks of its own: `TasksService` folds what comes back into the
// one list the board already draws, and calls here to push a change. Nothing
// runs without a URL and a token, so an unconfigured machine stays local and
// still reads nothing on the network.
Singleton {
    id: root

    // ── CONFIGURATION ───────────────────────────────────────────────────────

    readonly property string url: SettingsService.vikunjaUrl.trim().replace(/\/+$/, "")
    readonly property string token: SettingsService.vikunjaToken.trim()

    // Both halves are needed; half a credential would only fail on every poll.
    readonly property bool configured: root.url !== "" && root.token !== ""

    // The switch in Settings, and whether there is anything to switch on.
    readonly property bool syncing: root.configured && SettingsService.vikunjaSync

    // ── STATE ───────────────────────────────────────────────────────────────

    // A read has come back whole; `complete` says whether it was the whole
    // list, so `TasksService` only prunes a task the server no longer has on
    // a full read.
    property bool available: false
    property bool complete: false

    // "" when all is well, otherwise the reason the settings page shows.
    property string reason: ""

    property var tasks: []
    property var projects: []
    property date readAt: new Date(0)

    readonly property int pollInterval: 300000

    readonly property bool busy: root.running !== null || root.queue.length > 0

    // Set when a script is started, cleared when its answer comes back. A
    // start that neither answers nor runs at all — the script could not be
    // spawned, which sends no exit and no output — is said by the guards
    // below, rather than waited on forever.
    property bool awaitingRead: false
    property bool awaitingSend: false

    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.syncing
    }

    // "just now", "12 min ago", "3 h ago".
    readonly property string age: {
        if (!root.available)
            return ""
        const minutes = Math.floor((root.clock.date.getTime() - root.readAt.getTime()) / 60000)
        if (minutes < 2)
            return Tr.t("just now")
        if (minutes < 60)
            return `${minutes} ${Tr.t("min ago")}`
        return `${Math.round(minutes / 60)} ${Tr.t("h ago")}`
    }

    // One clause per reason, for the settings and the board's footer.
    readonly property string reasonLabel: {
        switch (root.reason) {
        case "setup":   return Tr.t("Add a server and an API token")
        case "auth":    return Tr.t("The token was refused")
        case "url":     return Tr.t("The server did not answer")
        case "network": return Tr.t("No connection to the server")
        case "project": return Tr.t("No project to put a task in")
        case "input":   return Tr.t("The change could not be sent")
        case "spawn":   return Tr.t("The script could not be run")
        }
        return ""
    }

    function projectName(id: int): string {
        const found = root.projects.find(project => project.id === id)
        return found ? found.title : ""
    }

    // ── READING ─────────────────────────────────────────────────────────────

    Component.onCompleted: root.refresh()

    // A change to any of the credentials is a different server or a different
    // account; read again at once rather than waiting for the poll.
    readonly property Connections settings: Connections {
        target: SettingsService

        function onVikunjaUrlChanged(): void { root.reread() }
        function onVikunjaTokenChanged(): void { root.reread() }
        function onVikunjaProjectChanged(): void { root.reread() }
        function onVikunjaSyncChanged(): void { root.reread() }
    }

    function reread(): void {
        if (root.syncing) {
            root.refresh()
            return
        }
        // Switched off, or a credential was removed: forget the server's side
        // so nothing stale stays on the board.
        root.available = false
        root.complete = false
        root.tasks = []
        root.projects = []
        root.reason = ""
    }

    function refresh(): void {
        if (!root.syncing || root.query.running)
            return
        root.awaitingRead = true
        root.query.running = true
        root.readGuard.restart()
    }

    // A live read holds `running` for as long as it works, so a guard that
    // finds it unset while the answer is still awaited has found a start
    // that never happened.
    readonly property Timer readGuard: Timer {
        interval: 4000
        onTriggered: {
            if (!root.awaitingRead || root.query.running)
                return
            root.awaitingRead = false
            root.reason = "spawn"
        }
    }

    readonly property Timer poller: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.syncing
        onTriggered: root.refresh()
    }

    readonly property Process query: Process {
        command: [Quickshell.shellPath("scripts/vikunja.py"), "tasks"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.awaitingRead = false
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the Vikunja tasks:", error)
                    root.reason = "network"
                    return
                }
                if (report.available !== true) {
                    root.available = false
                    root.reason = report.reason ?? "network"
                    return
                }
                // Before `tasks`: its change is what folds the read into the
                // board, and that fold reads `complete`.
                root.complete = report.complete === true
                root.tasks = report.tasks ?? []
                root.projects = report.projects ?? []
                root.reason = ""
                root.readAt = new Date()
                root.available = true
            }
        }
    }

    // ── WRITING ─────────────────────────────────────────────────────────────
    //
    // Operations run one at a time, in a small queue: the worker is a single
    // `Process`, and a burst of edits (the board's per-keystroke marks, sent
    // once the debounce settles) must not overlap.

    signal saved(string key, var task)
    signal deleted(string key)
    signal rejected(string key, string reason)

    property var queue: []
    property var running: null

    function enqueue(job: var): void {
        root.queue = root.queue.concat([job])
        root.pump()
    }

    function fields(task: var): string {
        return JSON.stringify({
            title: task.text ?? "",
            description: task.body ?? "",
            due: task.due ?? "",
            done: task.state === "done"
        })
    }

    // A new task on the board, or one the server has never seen.
    function create(task: var): void {
        if (!root.syncing)
            return
        root.enqueue({
            kind: "create",
            key: task.key,
            command: [Quickshell.shellPath("scripts/vikunja.py"), "create", root.fields(task)]
        })
    }

    function update(task: var): void {
        if (!root.syncing)
            return
        if (!task.remoteId)
            return root.create(task)
        root.enqueue({
            kind: "update",
            key: task.key,
            command: [Quickshell.shellPath("scripts/vikunja.py"), "update",
                      `${task.remoteId}`, root.fields(task)]
        })
    }

    function remove(task: var): void {
        if (!root.syncing || !task.remoteId)
            return
        root.enqueue({
            kind: "remove",
            key: task.key,
            command: [Quickshell.shellPath("scripts/vikunja.py"), "delete",
                      `${task.remoteId}`]
        })
    }

    // A task that was created here and then removed before the create came
    // back: the board no longer has it, so the server should not either.
    function discard(id: int): void {
        if (!root.syncing || !id)
            return
        root.enqueue({
            kind: "discard",
            key: "",
            command: [Quickshell.shellPath("scripts/vikunja.py"), "delete", `${id}`]
        })
    }

    // The result of one operation, once. Called from the stream finishing and
    // from the process exiting; `reported` keeps the second from repeating it.
    function finish(raw: string): void {
        const job = root.worker.job
        if (job === null || root.worker.reported)
            return
        root.worker.reported = true
        root.worker.job = null
        root.running = null
        root.awaitingSend = false
        root.sendGuard.stop()

        let report = null
        try {
            report = JSON.parse(raw)
        } catch (error) {
            report = null
        }
        if (!report || report.available !== true) {
            root.reason = report && report.reason ? report.reason : "network"
            root.rejected(job.key, root.reason)
            return
        }
        root.reason = ""
        root.readAt = new Date()
        if (job.kind === "remove")
            root.deleted(job.key)
        else if (job.kind !== "discard")
            root.saved(job.key, report.task ?? null)
    }

    // A script that never started has no exit event, so the queue would wait
    // forever; this is the failure half of `finish`.
    function abort(reason: string): void {
        const job = root.worker.job
        if (job === null)
            return
        root.awaitingSend = false
        root.sendGuard.stop()
        root.worker.job = null
        root.running = null
        root.reason = reason
        root.rejected(job.key, reason)
        root.pump()
    }

    function pump(): void {
        if (root.worker.job !== null || root.queue.length === 0)
            return
        const job = root.queue[0]
        root.queue = root.queue.slice(1)
        root.running = job
        root.worker.reported = false
        root.worker.job = job
        root.worker.command = job.command
        root.awaitingSend = true
        root.worker.running = true
        root.sendGuard.restart()
    }

    readonly property Timer sendGuard: Timer {
        interval: 4000
        onTriggered: {
            if (!root.awaitingSend || root.worker.running)
                return
            root.abort("spawn")
        }
    }

    readonly property Process worker: Process {
        property var job: null
        property bool reported: false
        property string out: ""

        stdout: StdioCollector {
            onStreamFinished: {
                root.worker.out = text
                root.finish(text)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("vikunja:", text.trim())
            }
        }
        onExited: {
            root.finish(root.worker.out)
            root.pump()
        }
    }
}
