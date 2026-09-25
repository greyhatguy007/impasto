// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   K D E   C O N N E C T   S E R V I C E                                  │
// │   the paired phone · via scripts/kdeconnect.py                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// A paired phone, as KDE Connect's daemon already knows it: its charge, what
// it is playing, how many notifications it is holding, and which of the
// daemon's plugins this machine may use.
//
// The daemon owns the pairing, and this only reads what it publishes on the
// session bus, so a machine without KDE Connect is a quiet "not connected"
// rather than an error. The phone's notifications need nothing here: the
// daemon forwards them as ordinary desktop notifications, so the shell's
// own centre shows them already. The shared clipboard is off unless the
// settings ask for it, since a phone shared with someone else has a
// clipboard that is not this desk's to take.
//
// Nothing polls while nobody is watching: `subscribe` and `release` decide
// whether the script is asked at all, and the script answers only when
// something has actually changed.
Singleton {
    id: root

    // How often the phone is asked, in milliseconds. The script is what
    // decides between the busy and idle rates; this is only the backstop for
    // a phone that has stopped answering.
    readonly property int pollInterval: 20000

    // A phone is the speaker of the desk only if the settings say so: a
    // machine with a phone on it may or may not want the desk muted when it
    // walks away.
    readonly property bool allowsMedia: SettingsService.phoneMedia !== false

    property int watchers: 0

    function subscribe(): void {
        root.watchers += 1
        if (root.watchers === 1)
            root.poll()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    // ── THE PHONE ───────────────────────────────────────────────────────────

    // "daemon", "pairing", "input" or "network" — why there is no phone.
    property string reason: ""
    // The daemon is on the bus, whatever the phone is doing.
    property bool connected: false
    // The phone is paired, in reach, and answering.
    property bool available: false
    property bool busy: false

    property string id: ""
    property string name: ""
    property string type: "phone"
    property string address: ""

    property int battery: -1
    property bool charging: false
    property bool hasBattery: false

    property var media: null
    property var network: null
    property var devices: []
    property var plugins: []

    // What the daemon says this machine may do with this phone.
    readonly property var can: ({
        ring: false, ping: false, clipboard: false, media: false,
        share: false, lock: false, notifications: false
    })

    // A phone that is out of reach is still a phone; `reachable` is what
    // decides whether a bar module may act on it.
    readonly property bool reachable: root.available && root.connected

    // ── THE PERCENT ─────────────────────────────────────────────────────────

    readonly property real charge: root.hasBattery && root.battery >= 0
        ? Math.max(0, Math.min(1, root.battery / 100)) : 0

    readonly property bool low: root.hasBattery && root.battery >= 0
        && root.battery <= 20 && !root.charging

    readonly property color tone: {
        if (!root.hasBattery)
            return Theme.indicator
        if (root.charging)
            return Theme.indicatorGood
        if (root.battery <= 20)
            return Theme.indicatorBad
        if (root.battery <= 40)
            return Theme.indicatorWarn
        return Theme.indicator
    }

    // "34% · charging", "charging", "no battery" — one line about the charge.
    readonly property string chargeNote: {
        if (!root.available)
            return ""
        if (!root.hasBattery)
            return Tr.t("No battery report")
        const percent = `${root.battery}%`
        if (root.charging)
            return root.battery >= 0 ? `${percent} · ${Tr.t("charging")}` : Tr.t("charging")
        return root.battery >= 0 ? percent : ""
    }

    // "Redmi Note 10 Pro", or the reason there is no phone. A phone that has
    // gone to sleep is still this desk's phone, so it keeps its name and says
    // what is wrong with it rather than reading as a pairing that was undone.
    readonly property string statusNote: {
        if (root.available)
            return root.connected ? root.name
                : `${root.name} · ${Tr.t("out of reach")}`
        if (root.reason === "daemon")
            return Tr.t("KDE Connect is not running")
        if (root.reason === "pairing")
            return Tr.t("No paired phone")
        if (root.reason === "input")
            return Tr.t("That phone is not paired")
        return Tr.t("The phone is out of reach")
    }

    // ── WHAT THE PHONE IS PLAYING ───────────────────────────────────────────
    //
    // The media service takes the phone as a source when the settings allow
    // it, so the desk's own player hands over to the phone's music the way
    // it would hand over between a record and a file.

    function handOver(): void {
        if (!root.allowsMedia || !root.media || !root.media.title)
            return
        MediaService.adopt("phone", {
            title: root.media.title,
            artist: root.media.artist,
            album: root.media.album,
            art: root.media.art,
            length: root.media.length,
            position: root.media.position,
            volume: root.media.volume,
            playing: root.media.playing,
            source: "phone",
        })
    }

    // ── ASKING THE PHONE ────────────────────────────────────────────────────

    // One action, and whether the phone took it. Nothing is queued: an action
    // a desk can press twice does not need a second press explained.
    //
    // `value` is the one argument an action may need — the text of a ping, a
    // volume, a file to send. It is a second required string rather than a
    // defaulted one, because QML has no default for a typed parameter, so the
    // buttons below say which action they mean in full and `act` stays the one
    // door the script is opened through.
    function act(action: string, value: string): void {
        if (root.watchers === 0)
            return
        root.busy = true
        root.send.command = [Quickshell.shellPath("scripts/kdeconnect.py"),
            "send", SettingsService.kdeconnectDevice ?? "", action]
        if (value !== "")
            root.send.command.push(value)
        root.send.running = true
    }

    readonly property Process send: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the phone's answer:", error)
                    return
                }
                // A refused action is not a failure of the script: the phone
                // said no, and the shell has nothing to draw about it.
                root.connected = report.connected === true
                if (report.reason === "pairing" || report.reason === "input")
                    root.reason = report.reason
                // Anything the phone did is worth reading back: a volume
                // moved from the phone itself, a pause from the desk.
                root.poll()
            }
        }
    }

    // ── THE BUTTONS ─────────────────────────────────────────────────────────
    //
    // What the shell asks the phone for, each as a whole. Every one of them is
    // a press somewhere — a tile, a chip, a row of buttons — and none of them
    // has to know how a KDE Connect action is spelled on the wire.

    function ring(): void {
        root.act("ring", "")
    }

    function ping(message: string): void {
        root.act("ping", message)
    }

    function fetchClipboard(): void {
        root.act("clipboard", "")
    }

    function lock(): void {
        root.act("lock", "")
    }

    // One action for both: the phone is asked to toggle, and which way it went
    // is the next poll's answer, not this call's guess.
    function playPause(): void {
        root.act("playpause", "")
    }

    function nextTrack(): void {
        root.act("next", "")
    }

    function previousTrack(): void {
        root.act("previous", "")
    }

    // ── THE POLL ────────────────────────────────────────────────────────────

    // The script answers one line only when something moved, so this is one
    // quiet process per desk rather than a timer per widget.
    function poll(): void {
        if (root.watchers === 0)
            return
        root.wanted = SettingsService.kdeconnectDevice ?? ""
        root.pollCommand.command = [Quickshell.shellPath("scripts/kdeconnect.py"),
            "poll"]
        if (root.wanted !== "")
            root.pollCommand.command.push(root.wanted)
        // The script hands the phone's clipboard to the desk's own, so the
        // copy lands in the clipboard history like any other.
        if (root.allowsClipboard)
            root.pollCommand.command.push("--clipboard")
        root.pollCommand.running = true
    }

    readonly property bool allowsClipboard: SettingsService.phoneClipboard === true

    // The desk's clipboard, offered to the phone, for the module's button.
    function pushClipboard(): void {
        root.act("push", "")
    }

    // ── THE PHONE'S OWN VOLUME ──────────────────────────────────────────────
    //
    // The player the phone reports carries its volume, and the daemon accepts
    // a new one as a property write rather than a call, so the same
    // `act` covers it with the number as the value.

    readonly property bool hasVolume: root.media !== null
        && typeof root.media.volume === "number"

    readonly property real volume: root.hasVolume
        ? Math.max(0, Math.min(1, root.media.volume)) : 0

    function setVolume(fraction: real): void {
        if (!root.hasVolume)
            return
        root.act("volume", `${Math.round(Math.max(0, Math.min(1, fraction)) * 100)}`)
    }

    property string wanted: ""
    property int generation: 0

    // SplitParser, not StdioCollector: this stream never ends, and a collector
    // would wait for an end that does not come. The script writes a whole
    // report per line, only when something moved.
    readonly property Process pollCommand: Process {
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const trimmed = line.trim()
                if (trimmed === "")
                    return
                root.busy = false
                root.adopt(trimmed)
            }
        }

        // A script that fails on its first line — no daemon, a phone that went
        // away — is asked again, but never in a tight loop.
        onExited: pollRevive.start()
    }

    readonly property Timer pollRevive: Timer {
        interval: 6000
        onTriggered: {
            if (root.watchers > 0)
                root.poll()
        }
    }

    // The script decides between a busy and an idle rate of its own; this is
    // only the backstop for a phone that has stopped answering altogether.
    readonly property Timer pollPoller: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: {
            if (!root.pollCommand.running)
                root.poll()
        }
    }

    function adopt(line: string): void {
        let report = null
        try {
            report = JSON.parse(line)
        } catch (error) {
            console.warn("Cannot parse the phone report:", error)
            return
        }
        if (!report || report.available !== true) {
            root.available = false
            root.connected = report?.connected === true
            root.reason = report?.reason ?? "daemon"
            root.media = null
            return
        }
        root.available = true
        root.reason = ""
        root.connected = report.connected === true
        root.id = report.id ?? ""
        root.name = report.name ?? ""
        root.type = report.type ?? "phone"
        root.address = report.address ?? ""
        root.battery = report.battery ?? -1
        root.charging = report.charging === true
        root.hasBattery = report.hasBattery === true
        root.media = report.media ?? null
        root.network = report.network ?? null
        root.devices = report.devices ?? []
        root.plugins = report.plugins ?? []
        const offered = report.can ?? {}
        for (const key in root.can)
            root.can[key] = offered[key] === true
        if (root.allowsMedia)
            root.handOver()
    }

    // A one-shot reading, for a desk that has just paired or pressed Find it.
    // The poll would get there on its own within a minute; this is the same
    // question asked now, through the same parser, so both paths agree.
    function refresh(): void {
        if (root.watchers === 0)
            return
        root.busy = true
        root.probe.command = [Quickshell.shellPath("scripts/kdeconnect.py"),
            "status"]
        const wanted = SettingsService.kdeconnectDevice ?? ""
        if (wanted !== "")
            root.probe.command.push(wanted)
        root.probe.running = true
    }

    readonly property Process probe: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim()
                if (line === "")
                    root.busy = false
                else
                    root.adopt(line)
            }
        }
    }
}
