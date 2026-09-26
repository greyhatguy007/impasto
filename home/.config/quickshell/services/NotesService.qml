// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T E S   S E R V I C E                                              │
// │   notes storage and the open note                                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// Sticky notes: a title, a body and a tint. No state or date; those are tasks
// (`TasksService`), and the two are independent.
//
// Shown by the bar chip, its detail, the notes panel, desktop widgets and edge
// decks. Placement belongs to `DesktopService`. Notes are only edited in the
// island, since the desktop never takes the keyboard.
//
// Stored as one Markdown file per note in the configured Obsidian vault, or
// in the local JSON store when no vault has been selected.
Singleton {
    id: root

    readonly property bool ready: !root.initialScan

    // ── PAPER ───────────────────────────────────────────────────────────────
    //
    // A palette token (never a hex) washed towards white, so the paper follows
    // the wallpaper. The ink is fixed.
    readonly property var tints: ["yellow", "accent", "green", "blue", "red"]

    function tintColor(name: string): color {
        switch (name) {
        case "green":  return Theme.green
        case "yellow": return Theme.yellow
        case "red":    return Theme.red
        case "blue":   return Theme.blue
        }
        return Theme.accent
    }

    function paperOf(name: string): color {
        return Qt.tint(root.tintColor(name), Theme.paperWash)
    }

    // ── COLLECTION ──────────────────────────────────────────────────────────
    //
    //   key       unique id, e.g. "note-m2k9x1"
    //   title
    //   text      body
    //   tint      one of `tints`
    //   created   ms since epoch
    //   edited    ms since epoch; the deck sorts by it
    //   archived  hidden from the deck and the desktop
    property var notes: []
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
    readonly property bool markdownMode: root.vaultDirectory !== ""
    readonly property string notesDirectory: root.markdownMode
        ? `${root.vaultDirectory === "/" ? "" : root.vaultDirectory}/notes` : ""

    function normalise(list: var): var {
        const rows = []
        const length = list && typeof list.length === "number" ? list.length : 0
        for (let index = 0; index < length; index++) {
            const kept = list[index]
            if (!kept || !kept.key)
                continue
            rows.push(Object.assign({
                title: "", text: "", tint: "yellow", created: 0, edited: 0,
                archived: false
            }, kept))
        }
        return rows
    }

    readonly property var live: root.notes
        .filter(note => !note.archived)
        .sort((left, right) => right.edited - left.edited)

    readonly property var archived: root.notes
        .filter(note => note.archived)
        .sort((left, right) => right.edited - left.edited)

    readonly property int count: root.live.length

    readonly property var newest: root.live[0] ?? null

    function entry(key: string): var {
        return root.notes.find(note => note.key === key) ?? null
    }

    // The note a desktop row names, if still live; otherwise the newest.
    function noteFor(row: var): var {
        const key = row && row.note ? row.note : ""
        const named = key !== "" ? root.entry(key) : null
        return named && !named.archived ? named : root.newest
    }

    // Title, else first line, else "Untitled".
    function titleOf(note: var): string {
        if (!note)
            return ""
        if (note.title && note.title.trim() !== "")
            return note.title.trim()
        const line = root.firstLine(note.text)
        return line !== "" ? line : "Untitled"
    }

    function isEmpty(note: var): bool {
        return !note || ((note.title ?? "").trim() === "" && (note.text ?? "").trim() === "")
    }

    // ── WRITING ─────────────────────────────────────────────────────────────

    signal added(string key)

    function newKey(): string {
        const stamp = Date.now().toString(36)
        let key = `note-${stamp}`
        for (let n = 2; root.entry(key); n++)
            key = `note-${stamp}-${n}`
        return key
    }

    function write(next: var): void {
        const previous = root.notes
        root.notes = next
        if (!root.markdownMode) {
            root.jsonSaver.restart()
            return
        }
        // Persist only additions and changed records. Polling may have loaded
        // notes from Obsidian, and those must not cause unrelated rewrites.
        for (const note of next) {
            const old = previous.find(row => row.key === note.key)
            if (!old || root.serialise(old) !== root.serialise(note))
                root.queueSave(note)
        }
    }

    function add(title: string, text = "", tint = "yellow"): string {
        const now = Date.now()
        const key = root.newKey()
        root.write(root.notes.concat([{
            key: key,
            title: title ?? "",
            text: text ?? "",
            tint: root.tints.indexOf(tint) >= 0 ? tint : "yellow",
            created: now,
            edited: now,
            archived: false
        }]))
        DesktopService.noteAdded(key)
        root.added(key)
        return key
    }

    // A blank note opened for writing; discarded if left empty (`leave`).
    function create(tint = "yellow", fromDeck = false): string {
        const key = root.add("", "", tint)
        root.opened = key
        root.direct = !fromDeck
        return key
    }

    // Only text changes bump `edited` and bring the note to the front.
    function update(key: string, changes: var): void {
        root.write(root.notes.map(note => {
            if (note.key !== key)
                return note
            const next = Object.assign({}, note, changes)
            const written = (changes.text !== undefined && changes.text !== note.text)
                || (changes.title !== undefined && changes.title !== note.title)
            if (written)
                next.edited = Date.now()
            return next
        }))
    }

    function setTint(key: string, tint: string): void {
        if (root.tints.indexOf(tint) >= 0)
            root.update(key, { tint: tint })
    }

    // An archived note also leaves the desktop and the edge decks.
    function archive(key: string, on = true): void {
        if (!root.entry(key))
            return
        root.update(key, { archived: on })
        if (on)
            DesktopService.removeNote(key)
    }

    function remove(key: string): void {
        if (!root.entry(key))
            return
        DesktopService.removeNote(key)
        root.write(root.notes.filter(note => note.key !== key))
        if (root.markdownMode)
            root.deleteFile(key)
        if (root.opened === key)
            root.opened = ""
    }

    // ── READING ─────────────────────────────────────────────────────────────

    function firstLine(text: string): string {
        for (const line of (text ?? "").split("\n")) {
            const trimmed = line.trim()
            if (trimmed !== "")
                return trimmed
        }
        return ""
    }

    // Lines starting `[ ]` or `[x]` render as checkboxes. Display only; the
    // stored text is unchanged.
    function display(text: string): string {
        return (text ?? "")
            .replace(/^\[x\] ?/gim, "󰄲 ")
            .replace(/^\[ \] ?/gm, "󰄱 ")
    }

    function ageOf(when: real): string {
        const seconds = Math.max(0, (Date.now() - when) / 1000)
        if (seconds < 60)
            return "just now"
        if (seconds < 3600)
            return `${Math.floor(seconds / 60)} min`
        if (seconds < 86400)
            return `${Math.floor(seconds / 3600)} h`
        if (seconds < 7 * 86400)
            return `${Math.floor(seconds / 86400)} d`
        return Qt.formatDate(new Date(when), "d MMM")
    }

    // ── PANEL ───────────────────────────────────────────────────────────────
    //
    // Declared here so the island and the panel lay the deck out at its
    // final size from the first frame of the morph.
    readonly property int panelWidth: 560
    readonly property int panelHeight: 520

    // The open note, or "" for the deck. Kept here because the panel is
    // destroyed on close, and widgets and edge decks open straight onto a
    // note.
    property string opened: ""

    // Opened from outside the deck (widget, edge tab, detail, menu). Going
    // back then closes the island instead of returning to the deck.
    property bool direct: false

    function open(key: string, fromDeck = false): void {
        root.opened = root.entry(key) ? key : ""
        root.direct = !fromDeck
    }

    // Back to the deck, discarding the note if it was never written on.
    function leave(): void {
        const note = root.entry(root.opened)
        root.opened = ""
        root.direct = false
        if (note && root.isEmpty(note))
            root.remove(note.key)
    }

    // ── STORAGE ─────────────────────────────────────────────────────────────

    // The file format is intentionally small and regular:
    // ---\nid: note-...\ncreated: 123\nedited: 123\ntint: yellow\narchived: false\n---\n# Title\n\nBody\n\n[[QuickNotes]]
    // The frontmatter parser below only accepts these six exact scalar fields.
    property var knownFiles: ({})
    property var scanNames: []
    property int scanIndex: 0
    property var scanNotes: []
    property string scanFileName: ""
    property bool initialScan: true

    function switchStorage(): void {
        if (!root.markdownMode && root.jsonSaver.running) {
            jsonState.notes = root.notes
            root.jsonFile.writeAdapter()
        }
        root.jsonSaver.stop()
        root.pendingWrites = []
        root.pendingDeletes = []
        root.initialScan = true
        root.scanRunning = false
        root.scanNotes = []
        root.scanNames = []
        root.scanIndex = 0
        root.knownFiles = ({})
        root.notes = []
        if (root.markdownMode)
            root.beginScan()
        else
            root.jsonFile.reload()
    }

    function fileName(key: string): string {
        return `${root.notesDirectory}/${key}.md`
    }

    function parseMarkdown(source, fallbackKey) {
        const match = /^(?:\uFEFF)?---\r?\n([\s\S]*?)\r?\n---\r?\n([\s\S]*)$/.exec(String(source || ""))
        if (!match)
            return null
        const fields = ({})
        for (const line of match[1].split(/\r?\n/)) {
            const field = /^(id|created|edited|tint|archived): (.*)$/.exec(line)
            if (!field)
                return null
            fields[field[1]] = field[2]
        }
        const key = fields.id
        if (key !== fallbackKey || !/^note-[A-Za-z0-9_-]+$/.test(key)
                || !/^\d+$/.test(fields.created === undefined ? "" : fields.created)
                || !/^\d+$/.test(fields.edited === undefined ? "" : fields.edited)
                || !["true", "false"].includes(fields.archived)
                || root.tints.indexOf(fields.tint) < 0)
            return null
        const lines = match[2].replace(/\r\n/g, "\n").split("\n")
        let title = ""
        if (lines.length && lines[0].startsWith("# "))
            title = lines.shift().slice(2)
        if (lines[0] === "")
            lines.shift()
        let text = lines.join("\n")
        text = text.replace(/\n*\[\[QuickNotes\]\]\s*$/, "")
        text = text.replace(/\n+$/, "")
        return {
            key: key, title: title, text: text, tint: fields.tint,
            created: Number(fields.created), edited: Number(fields.edited),
            archived: fields.archived === "true"
        }
    }

    function serialise(note: var): string {
        const title = (note.title ?? "").replace(/[\r\n]+/g, " ")
        const body = (note.text ?? "").replace(/\r\n/g, "\n").replace(/\n+$/, "")
        return `---\nid: ${note.key}\ncreated: ${Math.max(0, Math.floor(note.created))}\nedited: ${Math.max(0, Math.floor(note.edited))}\ntint: ${note.tint}\narchived: ${note.archived ? "true" : "false"}\n---\n# ${title}\n\n${body}\n\n[[QuickNotes]]\n`
    }

    function beginScan(): void {
        if (!root.markdownMode || root.lister.running || root.scanRunning)
            return
        root.scanRunning = true
        root.lister.command = ["sh", "-c", "if [ -d \"$1\" ]; then mkdir -p -- \"$1/notes\" && find \"$1/notes\" -maxdepth 1 -type f -name 'note-*.md' -printf '%f\\n'; fi", "notes-list", root.vaultDirectory]
        root.lister.running = true
    }

    function scanNext(): void {
        if (!root.markdownMode) {
            root.scanRunning = false
            return
        }
        if (root.scanIndex >= root.scanNames.length) {
            const found = ({})
            const present = ({})
            for (const name of root.scanNames)
                if (/^note-[A-Za-z0-9_-]+\.md$/.test(name))
                    present[`${root.notesDirectory}/${name}`] = true
            for (const note of root.scanNotes)
                found[root.fileName(note.key)] = true
            const before = root.notes
            const next = root.scanNotes.slice()
            // Keep the last good version of a file that exists but cannot be parsed.
            for (const note of before) {
                const path = root.fileName(note.key)
                if (present[path] && !found[path])
                    next.push(note)
            }
            for (const note of before) {
                if (root.writingKey === note.key
                        || root.pendingWrites.some(row => row.key === note.key)) {
                    const index = next.findIndex(row => row.key === note.key)
                    if (index >= 0)
                        next[index] = note
                    else
                        next.push(note)
                }
            }
            // Removed external files also lose any desktop/edge placement.
            for (const note of before) {
                if (root.knownFiles[root.fileName(note.key)] && !present[root.fileName(note.key)])
                    DesktopService.removeNote(note.key)
            }
            for (const note of next) {
                const previous = before.find(row => row.key === note.key)
                if (previous && !previous.archived && note.archived)
                    DesktopService.removeNote(note.key)
            }
            root.notes = next
            root.knownFiles = present
            root.initialScan = false
            root.scanRunning = false
            return
        }
        const name = root.scanNames[root.scanIndex++]
        if (!/^note-[A-Za-z0-9_-]+\.md$/.test(name)) {
            root.scanNext()
            return
        }
        root.scanFileName = name
        root.reader.command = ["cat", `${root.notesDirectory}/${name}`]
        root.reader.running = true
    }

    function acceptRead(contents): void {
        if (!root.markdownMode)
            return
        const base = root.scanFileName.replace(/\.md$/, "")
        const note = root.parseMarkdown(contents, base)
        if (note && !root.scanNotes.some(row => row.key === note.key))
            root.scanNotes.push(note)
        root.scanNext()
    }

    function queueSave(note: var): void {
        const pending = root.pendingWrites.slice()
        const index = pending.findIndex(row => row.key === note.key)
        if (index >= 0)
            pending[index] = note
        else
            pending.push(note)
        root.pendingWrites = pending
        root.saveNext()
    }

    property var pendingWrites: []
    property string writingKey: ""
    property bool scanRunning: false

    function saveNext(): void {
        if (root.writerBusy || root.deleting || root.pendingDeletes.length > 0)
            return
        if (root.pendingWrites.length === 0)
            return
        const note = root.pendingWrites[0]
        root.pendingWrites = root.pendingWrites.slice(1)
        root.writingKey = note.key
        root.writer.path = root.fileName(note.key)
        root.writer.setText(root.serialise(note))
        root.writerBusy = true
    }

    property bool writerBusy: false
    property bool deleting: false
    property var pendingDeletes: []

    function deleteFile(key: string): void {
        root.pendingWrites = root.pendingWrites.filter(note => note.key !== key)
        root.pendingDeletes = root.pendingDeletes.concat([key])
        root.deleteNext()
    }

    function deleteNext(): void {
        if (root.deleting || root.writerBusy || root.pendingDeletes.length === 0)
            return
        const key = root.pendingDeletes[0]
        root.pendingDeletes = root.pendingDeletes.slice(1)
        root.deleter.command = ["rm", "-f", "--", root.fileName(key)]
        root.deleting = true
        root.deleter.running = true
    }

    readonly property Process lister: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.scanNames = text.split(/\r?\n/).filter(name => name !== "")
                root.scanIndex = 0
                root.scanNotes = []
                root.scanNext()
            }
        }
    }

    readonly property Timer jsonSaver: Timer {
        interval: 120
        onTriggered: {
            jsonState.notes = root.notes
            root.jsonFile.writeAdapter()
        }
    }

    readonly property FileView jsonFile: FileView {
        path: `${SettingsService.stateDirectory}/notes.json`
        printErrors: false
        onLoaded: {
            if (!root.markdownMode) {
                root.notes = root.normalise(jsonState.notes)
                root.initialScan = false
            }
        }
        onLoadFailed: error => {
            if (root.markdownMode)
                return
            root.notes = []
            root.initialScan = false
            if (error === FileViewError.FileNotFound)
                root.jsonFile.writeAdapter()
        }

        JsonAdapter {
            id: jsonState
            property var notes: []
        }
    }

    readonly property Process reader: Process {
        stdout: StdioCollector {
            id: readerOutput
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text !== "")
                    console.warn(`Cannot read note ${root.scanFileName}: ${text.trim()}`)
            }
        }
        onExited: (exitCode, exitStatus) => root.acceptRead(readerOutput.text)
    }

    readonly property FileView writer: FileView {
        path: ""
        atomicWrites: true
        printErrors: false
        onSaved: {
            root.writerBusy = false
            root.writingKey = ""
            root.deleteNext()
            root.saveNext()
        }
        onSaveFailed: error => {
            console.warn(`Cannot save note ${root.writingKey}: ${error}`)
            root.writerBusy = false
            root.writingKey = ""
            root.deleteNext()
            root.saveNext()
        }
    }

    readonly property Process deleter: Process {
        onExited: (exitCode, exitStatus) => {
            root.deleting = false
            root.deleteNext()
            root.saveNext()
            root.beginScan()
        }
    }

    readonly property Timer poller: Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.beginScan()
    }

    onVaultDirectoryChanged: root.switchStorage()
    Component.onCompleted: root.switchStorage()
}
