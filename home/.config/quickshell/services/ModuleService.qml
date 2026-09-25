// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M O D U L E   S E R V I C E                                            │
// │   module catalogue · activity and open panel state                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQml
import QtQuick
import Quickshell

import "../theme"

// The bar's catalogue: what each module is, its glyph and figure, whether this
// machine can show it, and which detail is open.
//
// A piece on the bar is a module or a button. A module tells you something:
// it always has a figure, and a click opens its detail in the island. A
// button does something: a symbol with no figure that opens a panel or runs
// an action. Detail sizes are declared here because the island has to reach
// that size before the detail exists.
//
// Adding a module: a file in bar/modules, a row in `catalogue` and a line in
// Module.qml. Adding a button: a door in ControlsService, or a row here.
Singleton {
    id: root

    //   bar      whether it can go on the bar (board, deck and arcade live on
    //            the desktop and behind their panels instead)
    //   desk     false for the one module with no desktop face
    //   width    detail size; none for the spectrum, which has no detail and
    //   height   lives only on the desktop, on the grid or along an edge
    //
    // The chip look is global (`SettingsService.chipShape`, `chipFigure`);
    // desktop faces are listed per theme in `DesktopService.faces`.
    readonly property var catalogue: [
        { id: "media",         name: "Media",         bar: true,  width: 380, height: 172 },
        { id: "timer",         name: "Timer",         bar: true,  width: 348, height: 116 },
        { id: "ai",           name: "Assistant",     bar: true,  width: 356, height: 150 },
        { id: "phone",        name: "Phone",         bar: true,  width: 356, height: 172 },
        { id: "battery",       name: "Battery",       bar: true,  width: 320, height: 132 },
        { id: "volume",        name: "Volume",        bar: true,  width: 340, height: 116 },
        { id: "brightness",    name: "Brightness",    bar: true,  width: 340, height: 100 },
        { id: "network",       name: "Network",       bar: true,  width: 356, height: 132 },
        { id: "bluetooth",     name: "Bluetooth",     bar: true,  width: 356, height: 132 },
        { id: "notifications", name: "Notifications", bar: true,  desk: false, width: 380, height: 340 },
        { id: "weather",       name: "Weather",       bar: true,  width: 380, height: 150 },
        { id: "coding",        name: "Activity",      bar: true,  width: 380, height: 158 },
        { id: "stats",         name: "System",        bar: true,  width: 380, height: 148 },
        { id: "updates",       name: "Updates",       bar: true,  width: 356, height: 132 },
        { id: "pet",           name: "Pet",           bar: true,  width: 380, height: 172 },
        { id: "games",         name: "Games",         bar: false, width: 380, height: 150 },
        { id: "calendar",      name: "Calendar",      bar: true,  width: 340, height: 330 },
        { id: "notes",         name: "Notes",         bar: false, width: 356, height: 150 },
        { id: "tasks",         name: "Tasks",         bar: false, width: 356, height: 150 },
        { id: "photo",         name: "Photo",         bar: false, width: 356, height: 150 },
        { id: "spectrum",      name: "Spectrum",      bar: false, width: 0,   height: 0 },
        { id: "clock",         name: "Clock",         bar: false,
          width: SettingsService.clockShowsDate ? 240 : 150, height: Theme.capsuleHeight },
        { id: "lyrics",        name: "Lyrics",        bar: true,  width: 300, height: 80 }
    ]

    function entry(id: string): var {
        return root.catalogue.find(item => item.id === id) ?? root.catalogue[0]
    }

    // ── BUTTONS ─────────────────────────────────────────────────────────────
    //
    // Every door of the control centre can go on the bar, under its name and
    // glyph, and so can the control centre itself and the capture surface.
    // Not the statistics or the pet: on the bar those are modules, and a
    // button beside them would be the same piece without its figure. Alone in
    // a capsule, a button is drawn as a circle.
    //
    // On the bar an id is a button before it is a module; notes and games are
    // modules only on the desktop.
    //
    // Capture is what the capture key does: the photo is taken at once, so
    // whatever the island has open is in it.
    readonly property var buttonIds: ["launcher", "overview", "controls", "capture",
        "appearance", "notes", "board", "games", "keys", "packages", "settings", "session"]

    readonly property var buttons: {
        const out = {}
        for (const id of root.buttonIds) {
            if (id === "controls") {
                out[id] = { name: "Control centre", glyph: "󰨚", panel: "controls" }
                continue
            }
            if (id === "capture") {
                out[id] = { name: "Capture", glyph: "󰹑",
                            action: () => CaptureService.open("", "", "", 0) }
                continue
            }
            const door = ControlsService.door(id)
            if (door === null)
                continue
            // The one door with no panel is the settings window.
            out[id] = door.panel !== ""
                ? { name: door.label, glyph: door.icon, panel: door.panel }
                : { name: door.label, glyph: door.icon, action: () => root.settingsRequested() }
        }
        return out
    }

    function isButton(id: string): bool {
        return root.buttons[id] !== undefined
    }

    // Whether an id from a saved layout is still a piece: one taken out of
    // the catalogue is dropped rather than drawn as something else.
    function placeable(id: string): bool {
        return id === "workspaces" || id === "split" || root.isButton(id)
            || root.catalogue.some(item => item.id === id && item.bar)
    }

    // A reading that polls keeps polling while a piece on the bar shows it,
    // in either shape.
    function watch(id: string, on: bool): void {
        if (id === "weather") {
            if (on)
                WeatherService.subscribe()
            else
                WeatherService.release()
        } else if (id === "updates") {
            if (on)
                UpdatesService.subscribe()
            else
                UpdatesService.release()
        } else if (id === "ai") {
            // The transcript scan is a walk of every session file, so it must
            // not happen for a piece that is not on screen.
            if (on)
                AiUsageService.subscribe()
            else
                AiUsageService.release()
        } else if (id === "phone") {
            // One process per desk, and only while something shows the phone.
            if (on)
                KdeConnectService.subscribe()
            else
                KdeConnectService.release()
        } else if (id === "lyrics") {
            // The chip's figure is the live line, and the line is found by
            // MPRIS position, which only polls while something holds a
            // subscription.
            if (on) {
                MediaService.subscribe()
                LyricsService.subscribe()
            } else {
                MediaService.release()
                LyricsService.release()
            }
        }
    }

    // Buttons cannot see the island, so they ask here and the bar listens.
    // The bar writes the open panel back to `shownPanel` so a button can stay
    // lit.
    signal panelToggled(string panel)

    function togglePanel(panel: string): void {
        root.panelToggled(panel)
    }

    property string shownPanel: ""

    // The settings window is not an island panel; shell.qml opens it.
    signal settingsRequested()

    // ── CHIP SHAPE ──────────────────────────────────────────────────────────
    //
    // Modules with a ring face: those whose reading fills from empty to full.
    // A state or a count (the network, the bell, the date, the pending
    // updates) has nothing to fill, so it keeps its symbol in either shape.
    readonly property var ringed: ["media", "timer", "ai", "phone", "battery",
        "volume", "brightness", "stats", "pet", "bluetooth"]

    // A piece's own shape when it has one, the bar's when it does not.
    function shapeOf(id: string, own: var): string {
        const chosen = own ? own : SettingsService.chipShape
        return chosen === "ring" && root.ringed.indexOf(id) >= 0 ? "ring" : "icon"
    }

    function figureOf(own: var): string {
        return own ? own : SettingsService.chipFigure
    }

    // ── GLYPH AND FIGURE ────────────────────────────────────────────────────
    //
    // One table for every place a module's symbol and figure appear (bar,
    // glance, settings), in either chip shape. The assistant and the pet draw their
    // own mark instead of a glyph (`ChipFace`).
    function glyphOf(id: string): string {
        switch (id) {
        case "network":
            return NetworkService.icon
        case "bluetooth":
            return BluetoothService.icon
        case "volume":
            return AudioService.icon
        case "brightness":
            return BrightnessService.icon
        case "battery":
            return BatteryService.icon
        case "weather":
            return WeatherService.glyph || "󰖐"
        case "updates":
            return "󰏖"
        case "phone":
            // The phone's own glyph, not a battery: a desk with a laptop and a
            // phone on it must not show the same twice.
            return KdeConnectService.charging ? "󰚦" : "󰒐"
        case "notifications":
            return NotificationService.doNotDisturb ? "󰂛" : "󰂚"
        case "media":
            return "󰎇"
        case "lyrics":
            // The same mark its own detail draws.
            return "󰎇"
        case "timer":
            return "󰔛"
        case "stats":
            return "󰍛"
        case "calendar":
            return "󰃭"
        case "coding":
            // The activity wall: the same mark its own chip draws.
            return "󰅩"
        }
        return ""
    }

    // Never empty, so "always show the figure" applies to every module: a
    // connection shows its name, an empty bell "0", an idle countdown "0:00".
    function valueOf(id: string): string {
        switch (id) {
        case "volume":
            return AudioService.muted ? "Muted" : `${AudioService.volume}%`
        case "brightness":
            return `${BrightnessService.percent}%`
        case "battery":
            return `${BatteryService.percent}%`
        case "weather":
            return WeatherService.available ? `${WeatherService.temperature}°` : "--°"
        case "updates":
            return `${UpdatesService.count}`
        case "notifications":
            return `${NotificationService.history.length}`
        case "media":
            return MediaService.available
                ? (MediaService.title || MediaService.identity || "Playing") : "Nothing playing"
        case "lyrics":
            // The line being sung, falling back to the track so the figure is
            // never blank while a player is up. Narrower than a line is wide,
            // so `figureLimit` keeps it from taking the bar over.
            return LyricsService.display !== "" ? LyricsService.display
                : (MediaService.title || MediaService.identity || "")
        case "timer":
            return TimerService.running ? TimerService.display : "0:00"
        case "ai":
            if (AiUsageService.measured)
                return `${Math.round(AiUsageService.sessionFraction * 100)}%`
            return AiUsageService.blockTokens > 0
                ? AiUsageService.compact(AiUsageService.blockTokens) : "0%"
        case "phone":
            // A phone that reports no charge names itself, so the chip is
            // never a bare percentage that could belong to the laptop.
            if (!KdeConnectService.available)
                return KdeConnectService.statusNote
            if (KdeConnectService.hasBattery)
                return `${KdeConnectService.battery}%`
            return KdeConnectService.name
        case "stats":
            return `${StatsService.cpu.toFixed(0)}%`
        case "pet":
            return PetService.hatched ? `Lv ${PetService.level}` : "Egg"
        case "network":
            return NetworkService.connectionName
        case "bluetooth":
            return BluetoothService.summary
        case "calendar":
            return Qt.formatDate(root.today.date, "ddd d")
        case "coding":
            return CodingService.available ? CodingService.totalLabel : ""
        }
        return ""
    }

    // For the calendar's figure, which only changes at midnight.
    readonly property SystemClock today: SystemClock {
        precision: SystemClock.Minutes
    }

    // Maximum width for text figures (track title, network or device name)
    // before they are elided.
    function figureLimit(id: string): int {
        switch (id) {
        case "media":
            return 150
        case "coding":
            return 60
        case "lyrics":
            return 150
        case "network":
        case "bluetooth":
            return 110
        }
        return 0
    }

    // Warnings (low battery, hot CPU) use the fixed indicator
    // hues; everything else is plain text colour.
    function tintOf(id: string): color {
        switch (id) {
        case "battery":
            if (BatteryService.available && !BatteryService.charging && !BatteryService.full) {
                if (BatteryService.percent <= 10)
                    return Theme.indicatorBad
                if (BatteryService.percent <= 20)
                    return Theme.indicatorWarn
            }
            break
        case "stats":
            if (StatsService.cpu >= 90)
                return Theme.indicatorBad
            if (StatsService.cpu >= 70)
                return Theme.indicatorWarn
            break
        case "timer":
            return TimerService.running ? TimerService.tint : Theme.text
        case "ai":
            return AiUsageService.tone
        case "phone":
            return KdeConnectService.available && KdeConnectService.hasBattery
                ? KdeConnectService.tone : Theme.indicator
        }
        return Theme.text
    }

    // ── VISIBILITY ──────────────────────────────────────────────────────────
    //
    // A placed piece always shows; the player says "Nothing playing" rather
    // than disappearing. The timer and the player can instead be set to show
    // only while running (`when: "running"`).
    readonly property var runners: ["timer", "media"]

    function runs(id: string): bool {
        switch (id) {
        case "timer":
            return TimerService.running
        case "media":
            return MediaService.playing
        }
        return false
    }

    function shows(id: string, when: var): bool {
        if (when === "running" && root.runners.indexOf(id) >= 0)
            return root.runs(id)
        return id === "media" || root.has(id)
    }

    // ── ACTIVITIES ──────────────────────────────────────────────────────────
    //
    // Up to two running activities shown beside the time, most urgent first:
    // recording, countdown, music. A countdown or music can be kept off the
    // island (`SettingsService.beside`) without affecting its module; a
    // recording cannot, since it has no module and nothing else on screen.
    readonly property var activities: {
        const list = []
        if (RecorderService.recording)
            list.push("recorder")
        if (TimerService.running && SettingsService.beside("timer"))
            list.push("timer")
        if (MediaService.playing && SettingsService.beside("media"))
            list.push("media")
        return list.slice(0, 2)
    }

    // Resting width. Alone, the time keeps the catalogue width; with
    // activities it shrinks to fit and each side gets a slot. One activity
    // splits across both sides (mark left, figure right); two take one each.
    readonly property int clockCore: SettingsService.clockShowsDate
        ? 150 : (SettingsService.clockShowsSeconds ? 88 : 72)
    readonly property int activitySide: root.activities.length > 1 ? 92 : 64
    readonly property int restWidth: root.activities.length === 0
        ? root.entry("clock").width
        : root.clockCore + 2 * root.activitySide

    // The glance the island opens under a resting pointer.
    readonly property int summaryWidth: 384
    readonly property int summaryHeight: MediaService.available ? 168 : 116

    // ── OPEN DETAIL ─────────────────────────────────────────────────────────
    //
    // One detail at a time, always shown by the island (`Bar.qml` writes
    // "island" to `openHost`).
    property string openId: ""
    property string openHost: ""

    function close(): void {
        root.openId = ""
        root.openHost = ""
    }

    // The catalogue size, except network and Bluetooth, which open the
    // control centre's lists, an empty notification list, which is short,
    // and brightness, which grows a row for every other screen it can dim.
    function openSize(id: string): var {
        if (id === "network" || id === "bluetooth")
            return { width: 420, height: 500 }
        const item = root.entry(id)
        if (id === "notifications" && NotificationService.history.length === 0)
            return { width: item.width, height: 124 }
        if (id === "brightness")
            return { width: item.width,
                     height: item.height + Math.max(0, BrightnessService.dimmable.length - 1) * 62 }
        return { width: item.width, height: item.height }
    }

    // A module that becomes unavailable closes its open detail.
    readonly property bool openGone: root.openId !== "" && !root.has(root.openId)

    onOpenGoneChanged: {
        if (root.openGone)
            root.close()
    }

    // Chips cannot see their bar, so they ask here and every bar listens. The
    // live one answers, since the detail opens in its island.
    signal activationRequested(string id)

    function activate(id: string): void {
        root.activationRequested(id)
    }

    // A module asking for a panel, e.g. the games detail opening the arcade.
    signal panelRequested(string panel)

    function requestPanel(panel: string): void {
        root.panelRequested(panel)
    }

    // ── AVAILABILITY ────────────────────────────────────────────────────────
    //
    // Whether this machine can show the module at all (a backlight, a player
    // on the bus, pacman-contrib installed). Not a preference; placement is
    // the layout's job.
    function has(id: string): bool {
        if (id === "capture")
            return CaptureService.can("grim")
        if (root.isButton(id))
            return true
        switch (id) {
        case "clock":
        case "calendar":
        case "timer":
        case "workspaces":
        case "notifications":
            return true
        case "media":
            return MediaService.available
        case "lyrics":
            // A line needs a track to be syncing: title, artist and length
            // are all the query asks the player for.
            return MediaService.available
        case "ai":
            // Reading this constructs the lazy singleton, which runs its
            // first query; it turns true a moment later.
            return AiUsageService.available
        case "phone":
            // A phone module earns its place only while a phone is
            // answering; KDE Connect being installed is not that.
            return KdeConnectService.available
        case "battery":
            return BatteryService.available
        case "volume":
            return AudioService.ready
        case "brightness":
            // A desktop has no backlight, the way it has no battery.
            return BrightnessService.available
        case "network":
            // Disconnected is still a reading.
            return true
        case "bluetooth":
            return BluetoothService.available
        case "weather":
            // Builds the service, which runs its first fetch.
            return WeatherService.available
        case "coding":
            // False until a handle is set and a grid comes back for whatever
            // the toggle is showing, so nothing shows on an unconfigured
            // machine.
            return CodingService.available
        case "stats":
            // The sampler runs from boot (shell.qml touches it).
            return true
        case "updates":
            // False on a machine with neither checkupdates nor pacman.
            return UpdatesService.available
        case "pet":
            // `ready` is constant true; reading it builds the service, and
            // the service's trickle runs while the pet is on the bar.
            return PetService.ready
        case "games":
            return GamesService.ready
        case "notes":
            return NotesService.ready
        case "tasks":
            return TasksService.ready
        case "photo":
            // An empty one asks for a picture.
            return true
        }
        return false
    }
}
