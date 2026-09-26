// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   O B S I D I A N   S E R V I C E                                        │
// │   the task board as a Kanban markdown file in a vault · read and write   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// The Obsidian side of the board: reads the Kanban markdown file on a timer
// and sends local changes back, both through `scripts/obsidian_kanban.py`,
// which holds the vault folder and board file from Settings → Integrations.
//
// It holds no tasks of its own: `TasksService` folds what comes back into the
// board's own rows, and calls here to push a change. Nothing runs while the
// backend is not Obsidian, so a machine that never chose it reads nothing.
Singleton {
    id: root

    // ── CONFIGURATION ───────────────────────────────────────────────────────

    readonly property string vaultDirectory: {
        let path = (SettingsService.obsidianVaultPath ?? "").trim()
        const home = Quickshell.env("HOME") || ""
        if (path === "~")
            path = home
        else if (path.startsWith("~/"))
            path = `${home}${path.slice(1)}`
        while (path.length > 1 && path.endsWith("/"))
            path = path.slice(0, -1)
        return path
    }

    readonly property string boardFile:
        (SettingsService.obsidianBoardFile ?? "").trim() || "Tasks.md"

    // A vault folder is all it takes; the board file is created on first write.
    readonly property bool configured: root.vaultDirectory !== ""

    // The switch in Settings, and whether there is anything to switch on.
    readonly property bool syncing: root.configured && SettingsService.resolvedTaskBackend === "obsidian"

    // For the settings and the footer.
    readonly property string boardLabel: {
        const file = root.boardFile
        return file.startsWith("/") || file.startsWith("~") ? file
            : `${root.vaultDirectory}/${file}`
    }

    // ── STATE ───────────────────────────────────────────────────────────────

    property bool available: false
    property bool exists: false

    // "" when well, otherwise the reason the settings page shows.
    property string reason: ""

    property var tasks: []
    property date readAt: new Date(0)

    readonly property int pollInterval: 5000

    readonly property bool busy: root.running !== null || root.queue.length > 0

    property bool awaitingRead: false
    property bool awaitingSend: false

    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.syncing
    }

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

    readonly property string reasonLabel: {
        switch (root.reason) {
        case "setup":  return Tr.t("Add a vault folder in Settings")
        case "io":     return Tr.t("The board file could not be read or written")
        case "input":  return Tr.t("The change could not be written")
        case "missing": return Tr.t("The card is no longer on the board")
        case "spawn":  return Tr.t("The script could not be run")
        }
        return ""
    }

    // ── READING ─────────────────────────────────────────────────────────────

    Component.onCompleted: root.refresh()

    readonly property Connections settings: Connections {
        target: SettingsService

        function onObsidianVaultPathChanged(): void { root.reread() }
        function onObsidianBoardFileChanged(): void { root.reread() }
        function onTaskBackendChanged(): void { root.reread() }
    }

    function reread(): void {
        if (root.syncing) {
            root.refresh()
            return
        }
        root.available = false
        root.exists = false
        root.tasks = []
        root.reason = ""
    }

    function refresh(): void {
        if (!root.syncing || root.query.running)
            return
        root.awaitingRead = true
        root.query.running = true
        root.readGuard.restart()
    }

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
        command: [Quickshell.shellPath("scripts/obsidian_kanban.py"), "tasks"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.awaitingRead = false
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the Obsidian board:", error)
                    root.reason = "io"
                    return
                }
                if (report.available !== true) {
                    root.available = false
                    root.reason = report.reason ?? "io"
                    return
                }
                root.exists = report.exists === true
                root.tasks = report.tasks ?? []
                root.reason = ""
                root.readAt = new Date()
                root.available = true
            }
        }
    }

    // ── WRITING ─────────────────────────────────────────────────────────────
    //
    // Operations run one at a time, in a small queue: the worker is a single
    // `Process`, and a burst of edits must not overlap.

    signal saved(string key, var task)
    signal deleted(string key)
    signal rejected(string key, string reason)

    property var queue: []
    property var running: null

    function enqueue(job: var): void {
        root.queue = root.queue.concat([job])
        root.pump()
    }

    // The fields the board stores, with the card's place among its lane's
    // cards: an update carries them all, so a change of lane or order is a
    // move without a second command.
    function fields(task: var, index): string {
        return JSON.stringify({
            text: task.text ?? "",
            body: task.body ?? "",
            due: task.due ?? "",
            done: task.state === "done",
            lane: task.state,
            index: index ?? 0
        })
    }

    function create(task: var, index): void {
        if (!root.syncing)
            return
        const payload = JSON.parse(root.fields(task, index))
        payload.key = task.key
        root.enqueue({
            kind: "create",
            key: task.key,
            command: [Quickshell.shellPath("scripts/obsidian_kanban.py"), "create",
                      JSON.stringify(payload)]
        })
    }

    function update(task: var, index): void {
        if (!root.syncing)
            return
        root.enqueue({
            kind: "update",
            key: task.key,
            command: [Quickshell.shellPath("scripts/obsidian_kanban.py"), "update",
                      task.key, root.fields(task, index)]
        })
    }

    function remove(task: var): void {
        if (!root.syncing)
            return
        root.enqueue({
            kind: "remove",
            key: task.key,
            command: [Quickshell.shellPath("scripts/obsidian_kanban.py"), "delete",
                      task.key]
        })
    }

    // A card created here and removed before the create came back: the board
    // no longer has it, so the file should not either.
    function discard(key: string): void {
        if (!root.syncing || key === "")
            return
        root.enqueue({
            kind: "discard",
            key: "",
            command: [Quickshell.shellPath("scripts/obsidian_kanban.py"), "delete", key]
        })
    }

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
            // A delete of a card the file no longer has is already done.
            if (job.kind !== "discard" && report && report.reason === "missing") {
                root.reason = ""
                if (job.kind === "remove")
                    root.deleted(job.key)
                else
                    root.saved(job.key, null)
                return
            }
            root.reason = report && report.reason ? report.reason : "io"
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
                    console.warn("obsidian-kanban:", text.trim())
            }
        }
        onExited: {
            root.finish(root.worker.out)
            root.pump()
        }
    }
}
