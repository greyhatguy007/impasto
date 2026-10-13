// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W I D G E T   S E R V I C E                                            │
// │   widgets defined in YAML · the catalogue, their readings, their buttons │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../engine/Engine.js" as Engine

// The shell's side of the widget engine. `widgetd.py` runs every definition's
// sources and prints a line whenever something is answered:
//
//   {"kind": "catalog", "widgets": […]}          definitions, at start and on change
//   {"kind": "data", "widget": "cpu", …}         readings and their history
//   {"kind": "error", "widget": "cpu", …}        a source that could not answer
//
// A definition appears here as `custom:<name>`, which is the id the desktop
// grid, the bar and the settings place — so a widget written in a file is
// dragged exactly like one the shell ships. Nothing about it is special-cased
// downstream except the face that draws it (`engine/WidgetFace.qml`).
//
// A button does not make its own request: `widgets.py action` does, out of
// sight of the shell, which is why a token in a definition never enters this
// process.
Singleton {
    id: root

    readonly property string hostPath: Quickshell.shellPath("scripts/widgetd.py")
    readonly property string toolPath: Quickshell.shellPath("scripts/widgets.py")

    // the definitions, in the shape `ModuleService.catalogue` uses
    property var entries: []
    // widget name → the readings its sources answered
    property var readings: ({})
    // widget name → value name → the samples a chart draws
    property var history: ({})
    // widget name → why its last ask failed
    property var failures: ({})
    // definitions the engine could not read, as messages
    property var problems: []
    property bool loaded: false

    // The action running right now, as `<moduleId>/<action>`, so its button
    // can show that it is waiting.
    property string running: ""

    // ── LOOKING THINGS UP ───────────────────────────────────────────────────
    //
    // Everything the rest of the shell asks about a custom widget, by module
    // id (`custom:cpu`). An id that is not a custom widget answers empty, so
    // every caller can ask first and branch on the answer.

    function widgetOf(moduleId: string): string {
        return typeof moduleId === "string" && moduleId.startsWith("custom:")
            ? moduleId.slice(7) : ""
    }

    function entryOf(moduleId: string): var {
        return root.entries.find(entry => entry.id === moduleId) ?? null
    }

    function has(moduleId: string): bool {
        return root.entryOf(moduleId) !== null
    }

    function familiesOf(moduleId: string): var {
        const entry = root.entryOf(moduleId)
        return entry ? entry.families : []
    }

    function viewOf(moduleId: string, family: string): var {
        const entry = root.entryOf(moduleId)
        return entry ? (entry.views ? (entry.views[family] ?? []) : []) : []
    }

    function islandOf(moduleId: string): var {
        const entry = root.entryOf(moduleId)
        return entry ? entry.island : null
    }

    // The island's chip: its symbol, and its figure filled in from the
    // readings — `{load:.0f}%` out of `{ load: 12.4 }`.
    function symbolOf(moduleId: string): string {
        const island = root.islandOf(moduleId)
        return island && island.symbol ? island.symbol : ""
    }

    function figureOf(moduleId: string): string {
        const island = root.islandOf(moduleId)
        if (!island || !island.figure)
            return ""
        return Engine.fill(island.figure, root.readings[root.widgetOf(moduleId)] ?? ({}))
    }

    function failureOf(moduleId: string): string {
        return root.failures[root.widgetOf(moduleId)] ?? ""
    }

    // ── ACTIONS ─────────────────────────────────────────────────────────────

    // One at a time: a press that arrives while another is out is dropped
    // rather than queued, since a button's second press is its own undo.
    function run(moduleId: string, action: string): void {
        const widget = root.widgetOf(moduleId)
        if (widget === "" || action === "" || root.running !== "")
            return
        root.running = `${moduleId}/${action}`
        runner.command = [root.toolPath, "action", widget, action,
                          JSON.stringify(root.readings[widget] ?? ({}))]
        runner.running = true
    }

    readonly property Process runner: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.running = ""
                if (!text)
                    return
                let result
                try {
                    result = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the action's answer:", error)
                    return
                }
                if (result.ok) {
                    OsdService.requested("", `${result.action}`, 2000)
                    return
                }
                console.warn("The action failed:", result.error)
                OsdService.requested("", result.error ?? "The action failed", 4000)
            }
        }
    }

    // ── THE HOST ────────────────────────────────────────────────────────────
    //
    // Running is the point: it holds every schedule and every reading. A host
    // that stops — a kernel of a definition, a python that was removed — is
    // brought back, so a widget does not quietly go stale for a session.

    property bool alive: true

    readonly property Process host: Process {
        command: [root.hostPath, "run"]
        running: root.alive

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.absorb(line)
        }

        onExited: {
            root.alive = false
            revive.restart()
        }
    }

    readonly property Timer revive: Timer {
        interval: 3000
        onTriggered: root.alive = true
    }

    function absorb(line: string): void {
        if (!line)
            return
        let message
        try {
            message = JSON.parse(line)
        } catch (error) {
            console.warn("Cannot parse a line from widgetd:", error)
            return
        }
        switch (message.kind) {
        case "catalog":
            root.entries = message.widgets ?? []
            root.problems = message.problems ?? []
            root.loaded = true
            break
        case "data": {
            const readings = Object.assign({}, root.readings)
            readings[message.widget] = message.values ?? ({})
            root.readings = readings
            const history = Object.assign({}, root.history)
            history[message.widget] = message.history ?? ({})
            root.history = history
            if (root.failures[message.widget] !== undefined) {
                const failures = Object.assign({}, root.failures)
                delete failures[message.widget]
                root.failures = failures
            }
            break
        }
        case "error": {
            const failures = Object.assign({}, root.failures)
            failures[message.widget] = message.error ?? "The source did not answer"
            root.failures = failures
            break
        }
        }
    }
}
