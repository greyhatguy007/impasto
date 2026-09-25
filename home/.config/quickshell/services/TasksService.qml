// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T A S K S   S E R V I C E                                              │
// │   tasks · due dates and board state                                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// Tasks: a line, a state (to do, doing, done) and an optional due day. The
// board lays them out by state and the calendar marks them by day; both read
// the same list. Unlike notes (`NotesService`), tasks have a state and a date.
//
// Stored in `tasks.json` in the state directory, written after a short
// debounce.
Singleton {
    id: root

    readonly property bool ready: true

    // ── STATES ──────────────────────────────────────────────────────────────
    //
    // In board order. A finished task stays on its calendar day, struck
    // through.
    readonly property var states: [
        { id: "todo",  label: "To do", icon: "󰄰" },
        { id: "doing", label: "Doing", icon: "󰪡" },
        { id: "done",  label: "Done",  icon: "󰄲" }
    ]

    function stateEntry(id: string): var {
        return root.states.find(item => item.id === id) ?? root.states[0]
    }

    function stateAfter(id: string): string {
        const at = root.states.findIndex(item => item.id === id)
        return root.states[Math.min(root.states.length - 1, at + 1)].id
    }

    // ── TODAY ───────────────────────────────────────────────────────────────
    //
    // Days are `yyyy-MM-dd` strings, so they compare as text.
    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
    }

    function dayKey(date: var): string {
        return Qt.formatDate(date, "yyyy-MM-dd")
    }

    function dateOf(key: string): var {
        const parts = (key ?? "").split("-")
        if (parts.length !== 3)
            return null
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
    }

    readonly property string todayKey: root.dayKey(root.clock.date)

    function shifted(days: int): string {
        const date = new Date(root.clock.date)
        date.setDate(date.getDate() + days)
        return root.dayKey(date)
    }

    // ── COLLECTION ──────────────────────────────────────────────────────────
    //
    //   key       unique id, e.g. "task-m2k9x1"
    //   text      the line
    //   body      optional details, or ""
    //   state     one of `states`
    //   due       a day key, or "" for none
    //   rank      order within its column, lowest first
    //   created   ms since epoch
    //   finished  when it reached `done`, or 0
    property var tasks: []

    function normalise(list: var): var {
        const rows = []
        const length = list && typeof list.length === "number" ? list.length : 0
        for (let index = 0; index < length; index++) {
            const kept = list[index]
            if (!kept || !kept.key)
                continue
            const row = Object.assign({
                text: "", body: "", state: "todo", due: "", rank: index, created: 0, finished: 0,
                // Set on the rows that came from a server (see “VIKUNJA” below).
                remote: "", remoteId: 0, project: 0, dirty: false, tries: 0
            }, kept)
            if (!root.states.some(item => item.id === row.state))
                row.state = "todo"
            row.remoteId = Number(row.remoteId) || 0
            row.tries = Number(row.tries) || 0
            rows.push(row)
        }
        return rows
    }

    function entry(key: string): var {
        return root.tasks.find(task => task.key === key) ?? null
    }

    function byRank(left: var, right: var): int {
        return left.rank !== right.rank ? left.rank - right.rank : left.created - right.created
    }

    // A column of the board, top to bottom.
    function inState(state: string): var {
        return root.tasks.filter(task => task.state === state).sort(root.byRank)
    }

    function countIn(state: string): int {
        return root.tasks.filter(task => task.state === state).length
    }

    readonly property int count: root.tasks.length
    readonly property int pending: root.tasks.filter(task => task.state !== "done").length

    // ── BY DAY ──────────────────────────────────────────────────────────────

    // Due on a day: unfinished first, then in board order.
    function on(day: string): var {
        return root.tasks
            .filter(task => task.due === day)
            .sort((left, right) => {
                const doneLeft = left.state === "done" ? 1 : 0
                const doneRight = right.state === "done" ? 1 : 0
                return doneLeft !== doneRight ? doneLeft - doneRight : root.byRank(left, right)
            })
    }

    function countOn(day: string): int {
        return root.tasks.filter(task => task.due === day).length
    }

    function pendingOn(day: string): int {
        return root.tasks.filter(task => task.due === day && task.state !== "done").length
    }

    function isOverdue(task: var): bool {
        return task && task.due !== "" && task.state !== "done" && task.due < root.todayKey
    }

    readonly property var dated: root.tasks
        .filter(task => task.due !== "")
        .sort((left, right) => left.due < right.due ? -1 : (left.due > right.due ? 1 : root.byRank(left, right)))

    readonly property var overdue: root.dated.filter(task => root.isOverdue(task))

    // Unfinished dated tasks from today on; `next` is shown beside the date
    // on the wide calendar face.
    readonly property var upcoming: root.dated
        .filter(task => task.state !== "done" && task.due >= root.todayKey)

    readonly property var next: root.upcoming[0] ?? null

    // Unfinished tasks: dated ones first by due day (so overdue lead), then
    // undated ones in board order.
    readonly property var queue: root.tasks
        .filter(task => task.state !== "done")
        .sort((left, right) => {
            if (left.due !== "" && right.due !== "")
                return left.due < right.due ? -1 : (left.due > right.due ? 1 : root.byRank(left, right))
            if (left.due !== "")
                return -1
            if (right.due !== "")
                return 1
            return root.byRank(left, right)
        })

    // Overdue, else due today, else the next task, else nothing.
    readonly property string summary: {
        const late = root.overdue.length
        if (late > 0)
            return `${late} overdue`
        const today = root.pendingOn(root.todayKey)
        if (today > 0)
            return `${today} due today`
        if (root.next)
            return `${root.next.text} · ${root.dueLabel(root.next.due)}`
        return root.pending > 0 ? "nothing dated" : "nothing to do"
    }

    // ── VIKUNJA ─────────────────────────────────────────────────────────────
    //
    // With a server configured the board is the meeting of two lists: the
    // tasks written here and the ones read from Vikunja, folded into this one
    // array so the calendar, the widgets and every face need to know nothing
    // about either. A row that came from the server carries `remoteId`; a row
    // with a change not yet sent carries `dirty` and is left alone by the next
    // read until it has gone.
    //
    // `VikunjaService` does the talking; this is only where the two meet.

    readonly property bool syncing: VikunjaService.syncing

    readonly property int remoteCount:
        root.tasks.filter(task => task.remote === "vikunja").length

    // A server task as a board row. Its rank sits past the local ones so a
    // freshly read task does not jump above what was arranged here.
    function rowFromRemote(task: var, rank: int): var {
        return {
            key: `vik-${task.id}`,
            text: task.title ?? "",
            body: task.description ?? "",
            state: task.done ? "done" : "todo",
            due: task.due ?? "",
            rank: rank,
            created: task.created ? Date.parse(task.created) : 0,
            finished: task.done
                ? (task.doneAt ? Date.parse(task.doneAt) : Date.now()) : 0,
            remote: "vikunja",
            remoteId: task.id,
            project: task.project ?? 0,
            dirty: false,
            tries: 0
        }
    }

    // The server's fields onto the row that carries them. The board's own
    // order is kept, and a task completed here and completed there agree; a
    // task only *this* side calls done is reopened when the server disagrees,
    // since the server is the one the other devices see.
    function mergeRemote(row: var, task: var): var {
        const done = task.done === true
        return Object.assign({}, row, {
            text: task.title ?? row.text,
            body: task.description ?? row.body,
            due: task.due ?? "",
            state: done ? "done" : (row.state === "done" ? "todo" : row.state),
            finished: done
                ? (row.finished || (task.doneAt ? Date.parse(task.doneAt) : Date.now())) : 0,
            project: task.project ?? row.project,
            dirty: false,
            tries: 0
        })
    }

    function same(list: var): bool {
        return JSON.stringify(list) === JSON.stringify(root.tasks)
    }

    // Folds one read of the server into the one list: tasks it still has are
    // updated in place, tasks it has gained are added, and — only on a read
    // that came back whole — tasks it has lost are dropped. A row with an
    // unsent change is left as it is, so a poll never clobbers what was typed
    // a moment ago.
    function reconcile(server: var): void {
        if (!root.syncing)
            return
        const list = server ?? []
        const complete = VikunjaService.complete
        const known = ({})
        for (const task of list)
            known[task.id] = true

        const next = []
        let retry = false
        for (const row of root.tasks) {
            if (row.remote !== "vikunja") {
                next.push(row)
                continue
            }
            // An unsent change outranks what the server says, whether it is
            // the same task underneath or one the read did not reach.
            if (row.dirty) {
                // The server is reachable again; give a failed send another
                // try rather than leaving the change stranded.
                if (row.tries > 0)
                    retry = true
                next.push(Object.assign({}, row, { tries: 0 }))
                continue
            }
            if (!known[row.remoteId]) {
                // Gone from the server — unless it was only just made here and
                // never sent, which the server has no reason to know, or the
                // read was partial and might simply not have reached it.
                if (complete && row.remoteId > 0)
                    continue
                next.push(row)
                continue
            }
            next.push(root.mergeRemote(row, list.find(item => item.id === row.remoteId)))
        }

        let index = 0
        for (const task of list) {
            index += 1
            if (root.tasks.some(row => row.remoteId === task.id))
                continue
            next.push(root.rowFromRemote(task, 1000 + index))
        }

        if (!root.same(next))
            root.write(next)
        if (retry)
            root.sender.restart()
    }

    // Sends a task the server accepted: a new one is linked to it, an edited
    // one is simply no longer dirty.
    function absorb(key: string, task: var): void {
        const row = root.entry(key)
        if (!row) {
            // Removed here while the create was in flight; do not leave it
            // behind on the server.
            if (task && task.id)
                VikunjaService.discard(task.id)
            return
        }
        if (task && task.id && !row.remoteId)
            root.update(key, { remote: "vikunja", remoteId: task.id,
                               project: task.project ?? 0 }, false)
        root.update(key, { dirty: false, tries: 0 }, false)
    }

    // Sync switched off, or the credentials removed: the rows that came from
    // the server go, since the server still has them. A task made here and not
    // yet sent stays, as an ordinary local one, rather than being lost.
    function orphan(): void {
        const next = []
        for (const row of root.tasks) {
            if (row.remote !== "vikunja") {
                next.push(row)
                continue
            }
            if (!row.remoteId)
                next.push(Object.assign({}, row,
                    { remote: "", dirty: false, tries: 0 }))
        }
        if (!root.same(next))
            root.write(next)
    }

    readonly property Connections server: Connections {
        target: VikunjaService

        function onTasksChanged(): void {
            root.reconcile(VikunjaService.tasks)
        }
        function onSyncingChanged(): void {
            if (!VikunjaService.syncing)
                root.orphan()
        }
        function onSaved(key, task): void { root.absorb(key, task) }
        function onDeleted(key): void { /* already gone here */ }
        function onRejected(key): void {
            // The row keeps `dirty`, so nothing typed is lost. `tries` counts
            // the refusals, so a task the server will not take is not sent
            // again and again; a later read or edit starts it over.
            if (!root.entry(key))
                return
            root.write(root.tasks.map(task => task.key === key
                ? Object.assign({}, task, { tries: (task.tries ?? 0) + 1 })
                : task))
        }
    }

    // Only what the settings describe as a self-hosted server reaches here.
    readonly property bool readyToSend: root.syncing && VikunjaService.configured

    readonly property Timer sender: Timer {
        interval: 1200
        onTriggered: root.push()
    }

    // Everything with an unsent change goes at once, a moment after the last
    // keystroke. A blank task is skipped: it is a card being written, and the
    // server would only refuse it.
    function push(): void {
        if (!root.readyToSend)
            return
        for (const row of root.tasks) {
            if (row.remote !== "vikunja" || !row.dirty || row.tries >= 3)
                continue
            if ((row.text ?? "").trim() === "")
                continue
            if (row.remoteId)
                VikunjaService.update(row)
            else
                VikunjaService.create(row)
        }
    }

    // today, tomorrow, yesterday, a weekday within a week, else the date.
    function dueLabel(day: string): string {
        if (!day)
            return ""
        if (day === root.todayKey)
            return "today"
        if (day === root.shifted(1))
            return "tomorrow"
        if (day === root.shifted(-1))
            return "yesterday"
        const date = root.dateOf(day)
        if (!date)
            return day
        const week = root.shifted(6)
        if (day > root.todayKey && day <= week)
            return Qt.formatDate(date, "dddd")
        return Qt.formatDate(date, date.getFullYear() === root.clock.date.getFullYear()
            ? "ddd d MMM" : "d MMM yyyy")
    }

    // ── PARSING DUE DAYS ────────────────────────────────────────────────────
    //
    // Accepted after `@`: today, tomorrow, a weekday (next occurrence, today
    // included), `+3`, `12/9`, `12 sep`, `sep 12` or a day key. Weekday and
    // month names are accepted in English and Spanish.
    readonly property var dayNames: [
        ["mon", "monday", "lun", "lunes"],
        ["tue", "tuesday", "mar", "martes"],
        ["wed", "wednesday", "mie", "mié", "miercoles", "miércoles"],
        ["thu", "thursday", "jue", "jueves"],
        ["fri", "friday", "vie", "viernes"],
        ["sat", "saturday", "sab", "sáb", "sabado", "sábado"],
        ["sun", "sunday", "dom", "domingo"]
    ]

    readonly property var monthNames: [
        ["jan", "january", "ene", "enero"],
        ["feb", "february", "febrero"],
        ["mar", "march", "marzo"],
        ["apr", "april", "abr", "abril"],
        ["may", "mayo"],
        ["jun", "june", "junio"],
        ["jul", "july", "julio"],
        ["aug", "august", "ago", "agosto"],
        ["sep", "sept", "september", "septiembre"],
        ["oct", "october", "octubre"],
        ["nov", "november", "noviembre"],
        ["dec", "december", "dic", "diciembre"]
    ]

    function monthIndex(word: string): int {
        return root.monthNames.findIndex(names => names.indexOf(word) >= 0)
    }

    // A day key for what was typed, or "" when it is not a day.
    function parseDue(text: string): string {
        const word = (text ?? "").trim().toLowerCase()
        if (word === "")
            return ""
        if (/^\d{4}-\d{2}-\d{2}$/.test(word))
            return root.dateOf(word) ? word : ""
        if (["today", "tod", "hoy"].indexOf(word) >= 0)
            return root.todayKey
        if (["tomorrow", "tom", "mañana", "manana"].indexOf(word) >= 0)
            return root.shifted(1)
        if (["next week", "nextweek"].indexOf(word) >= 0)
            return root.shifted(7)
        const plus = word.match(/^\+(\d{1,3})$/)
        if (plus)
            return root.shifted(Number(plus[1]))

        // A weekday: the next one, today included.
        const weekday = root.dayNames.findIndex(names => names.indexOf(word) >= 0)
        if (weekday >= 0) {
            const now = (root.clock.date.getDay() + 6) % 7
            return root.shifted((weekday - now + 7) % 7)
        }

        const year = root.clock.date.getFullYear()
        const build = (day, month, yearGiven) => {
            let y = yearGiven ?? year
            let date = new Date(y, month, day)
            if (date.getMonth() !== month || date.getDate() !== day)
                return ""
            // A day and a month with no year is the next one of those.
            if (yearGiven === undefined && root.dayKey(date) < root.todayKey)
                date = new Date(y + 1, month, day)
            return root.dayKey(date)
        }

        const slash = word.match(/^(\d{1,2})[\/.](\d{1,2})(?:[\/.](\d{2,4}))?$/)
        if (slash) {
            const y = slash[3] === undefined ? undefined
                : (slash[3].length === 2 ? 2000 + Number(slash[3]) : Number(slash[3]))
            return build(Number(slash[1]), Number(slash[2]) - 1, y)
        }

        const parts = word.split(/\s+/)
        if (parts.length === 2 || parts.length === 3) {
            const y = parts.length === 3 ? Number(parts[2]) : undefined
            if (parts.length === 3 && !Number.isFinite(y))
                return ""
            const a = Number(parts[0])
            const b = Number(parts[1])
            if (Number.isFinite(a) && root.monthIndex(parts[1]) >= 0)
                return build(a, root.monthIndex(parts[1]), y)
            if (Number.isFinite(b) && root.monthIndex(parts[0]) >= 0)
                return build(b, root.monthIndex(parts[0]), y)
        }
        return ""
    }

    // "Pay rent @fri" → text and due day. An `@` that does not parse as a
    // day stays in the text.
    function split(line: string): var {
        const text = (line ?? "").trim()
        const at = text.lastIndexOf("@")
        if (at > 0) {
            const due = root.parseDue(text.slice(at + 1))
            if (due !== "")
                return { text: text.slice(0, at).trim(), due: due }
        }
        return { text: text, due: "" }
    }

    // ── WRITING ─────────────────────────────────────────────────────────────

    signal added(string key)

    function newKey(): string {
        const stamp = Date.now().toString(36)
        let key = `task-${stamp}`
        for (let n = 2; root.entry(key); n++)
            key = `task-${stamp}-${n}`
        return key
    }

    function write(next: var): void {
        root.tasks = next
        root.saver.restart()
    }

    function lastRank(state: string): int {
        const column = root.inState(state)
        return column.length === 0 ? 0 : column[column.length - 1].rank + 1
    }

    function add(text: string, due = "", state = "todo", body = ""): string {
        const line = (text ?? "").trim()
        const key = root.newKey()
        // A task written while a server is configured belongs to it and goes
        // out as soon as it has a line; one written before that stays here.
        const linked = root.readyToSend
        root.write(root.tasks.concat([{
            key: key,
            text: line,
            body: body ?? "",
            state: root.states.some(item => item.id === state) ? state : "todo",
            due: due ?? "",
            rank: root.lastRank(state),
            created: Date.now(),
            finished: 0,
            remote: linked ? "vikunja" : "",
            remoteId: 0,
            project: 0,
            dirty: linked,
            tries: 0
        }]))
        if (linked)
            root.sender.restart()
        root.added(key)
        return key
    }

    // A blank task opened for editing; discarded if left empty (`leave`).
    function create(fromBoard = false): string {
        const key = root.add("", "", "todo", "")
        root.opened = key
        root.direct = !fromBoard
        return key
    }

    function isEmpty(task: var): bool {
        return !task || (task.text ?? "").trim() === ""
    }

    // `send` is false for a change that came *from* the server (`absorb`,
    // `reconcile`), which must not be marked to go straight back.
    function update(key: string, changes: var, send = true): void {
        const row = root.entry(key)
        const outward = send && row !== null && row.remote === "vikunja"
        root.write(root.tasks.map(task => task.key === key
            ? Object.assign({}, task, changes,
                outward ? { dirty: true, tries: 0 } : {})
            : task))
        if (outward)
            root.sender.restart()
    }

    // To the bottom of the column; `finished` is set only for done.
    function setState(key: string, state: string): void {
        const task = root.entry(key)
        if (!task || !root.states.some(item => item.id === state) || task.state === state)
            return
        root.update(key, {
            state: state,
            rank: root.lastRank(state),
            finished: state === "done" ? Date.now() : 0
        })
    }

    // Re-ranks the whole column around the dropped task.
    function place(key: string, state: string, index: int): void {
        const task = root.entry(key)
        if (!task || !root.states.some(item => item.id === state))
            return
        const column = root.inState(state).filter(other => other.key !== key)
        const at = Math.max(0, Math.min(column.length, index))
        column.splice(at, 0, task)
        const ranks = {}
        column.forEach((other, position) => { ranks[other.key] = position })
        const moved = task.state !== state
        root.write(root.tasks.map(other => {
            if (ranks[other.key] === undefined)
                return other
            const next = Object.assign({}, other, { rank: ranks[other.key] })
            if (other.key === key && moved) {
                next.state = state
                next.finished = state === "done" ? Date.now() : 0
            }
            // Only a change of lane is worth sending; the order within one is
            // the board's own and the server has nothing to store it in.
            if (other.key === key && moved && other.remote === "vikunja")
                Object.assign(next, { dirty: true, tries: 0 })
            return next
        }))
        if (moved && task.remote === "vikunja")
            root.sender.restart()
    }

    function setDue(key: string, due: string): void {
        root.update(key, { due: due ?? "" })
    }

    // Done, or back to the first column.
    function toggle(key: string): void {
        const task = root.entry(key)
        if (!task)
            return
        root.setState(key, task.state === "done" ? "todo" : "done")
    }

    function remove(key: string): void {
        const row = root.entry(key)
        if (!row)
            return
        // A task the server knows about is removed there too; one that was
        // never sent simply goes.
        if (row.remote === "vikunja" && row.remoteId)
            VikunjaService.remove(row)
        root.write(root.tasks.filter(task => task.key !== key))
        if (root.opened === key)
            root.opened = ""
    }

    // ── PANEL ───────────────────────────────────────────────────────────────
    //
    // Declared so the lanes lay out at the island's final size.
    readonly property int panelWidth: 760
    readonly property int panelHeight: 520

    property string opened: ""

    // Opened from outside the board (the calendar): Escape then closes the
    // island instead of showing the board.
    property bool direct: false

    function open(key: string, fromBoard = false): void {
        root.opened = root.entry(key) ? key : ""
        root.direct = !fromBoard
    }

    // Back to the board, discarding a task that never got a line.
    function leave(): void {
        const task = root.entry(root.opened)
        root.opened = ""
        root.direct = false
        if (task && root.isEmpty(task))
            root.remove(task.key)
    }

    // ── STORAGE ─────────────────────────────────────────────────────────────

    readonly property Timer saver: Timer {
        interval: 120
        onTriggered: {
            state.tasks = root.tasks
            root.file.writeAdapter()
        }
    }

    readonly property FileView file: FileView {
        path: `${SettingsService.stateDirectory}/tasks.json`

        onLoaded: root.tasks = root.normalise(state.tasks)
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter()
        }

        JsonAdapter {
            id: state

            property var tasks: []
        }
    }
}
