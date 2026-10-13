// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W L E D   S E R V I C E                                                │
// │   screen-aware lighting · a strip over DDP, fed by the focused screen     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// What the shell needs to point lights at the screen: find the controllers on
// the network, ask one how many LEDs it has, and own the stream to it.
//
// `wled.py` does the work. This service holds the process (`on` is "running",
// the way SunsetService holds hyprsunset), keeps the last report the stream
// printed — pixels per second, packets, how much of the picture actually
// changed — and rewinds the discovery probe on demand.
//
// Settings live on the machine like every other integration: the host, the
// LED count once a controller has answered for itself, and the tick rate.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/wled.py")

    // The settings. `wledHost` empty means the integration is off.
    readonly property string host: SettingsService.wledHost.trim()
    readonly property string hostName: SettingsService.wledName
    readonly property string displayName: root.hostName !== "" ? root.hostName : root.host
    readonly property bool configured: root.host !== ""

    // 0 asks the controller; a value that has been answered is trusted until
    // the host changes.
    readonly property int savedLeds: SettingsService.wledLeds
    property int probedLeds: 0
    readonly property int leds: root.savedLeds > 0 ? root.savedLeds : root.probedLeds
    readonly property int speed: SettingsService.wledSpeed

    // Emits on every report the stream prints.
    signal refreshed()

    property bool probing: false
    property var lights: []
    property bool discovering: false

    // Whether the stream is running, i.e. on. The process carries the toggle
    // the way `SunsetService` carries hyprsunset: running means on, and the
    // compositor of one kind or another returns the lights when it stops.
    readonly property bool on: root.feeder.running

    // Falsified while the controller cannot be reached or the process is
    // being asked to rewind.
    property string reason: ""

    // ── REPLIES ─────────────────────────────────────────────────────────────

    // Helpers, all handled through flags the stream step answers.
    function toggle(value: var): void {
        if (!root.configured) {
            OsdService.requested(root.icon, "No WLED host set", -1)
            return
        }
        const wanted = value === undefined ? !SettingsService.wledOn : value
        SettingsService.set("wledOn", wanted)
    }

    readonly property string icon: root.on ? "󰚥" : "󰚦"
    readonly property color tint: root.on ? Theme.indicatorGood : Theme.text

    // A fresh start clears the last report's figures.
    onOnChanged: {
        if (!root.on)
            return
        root.fps = 0
        root.packets = 0
        if (root.leds === 0)
            root.probeTimer.restart()
    }

    // ── DISCOVERY ───────────────────────────────────────────────────────────

    function discover(): void {
        root.discoverer.running = true
        root.discovering = true
    }

    readonly property Process discoverer: Process {
        command: [root.script, "discover"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.discovering = false
                let found
                try {
                    found = JSON.parse(text)
                } catch (error) {
                    return
                }
                root.lights = found.lights ?? []
            }
        }
        onExited: root.discovering = false
    }

    // ── THE CONTROLLER'S COUNT ──────────────────────────────────────────────

    function probe(): void {
        if (root.host === "" || root.probing)
            return
        root.probing = true
        root.prober.command = [root.script, "status", root.host]
        root.prober.running = true
    }

    readonly property Process prober: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.probing = false
                let found
                try {
                    found = JSON.parse(text)
                } catch (error) {
                    return
                }
                if (!found.reachable) {
                    root.reason = "The controller is not answering"
                    return
                }
                root.reason = ""
                if (found.name !== "" && SettingsService.wledName !== found.name)
                    SettingsService.set("wledName", found.name)
                // The count is the truth once it has been asked for.
                root.probedLeds = found.leds > 0 ? found.leds : root.probedLeds
            }
        }
        onExited: root.probing = false
    }

    // Ask a little after a stream starts, so a first-time host with a count
    // saved as zero is measured once without delaying the first frame.
    readonly property Timer probeTimer: Timer {
        interval: 800
        onTriggered: root.probe()
    }

    // One glance at the network at startup. Finding nothing is the ordinary
    // answer, so the result is only read when someone asks for it again.
    Component.onCompleted: root.discover()

    // ── THE STREAM ──────────────────────────────────────────────────────────

    // Per report, the stream's own latest figures.
    property real fps: 0
    property int packets: 0

    // The stream, owned by this service: running means `wledOn` on a
    // configured host. The command is declared, so a new host, count or rate
    // reaches it on the next start; a change while running restarts it so the
    // change is heard at once.
    // The stream. Command is literal so a changed host/leds/speed reaches it on
    // the next start; while running, a changed streamKey restarts it so the
    // change is heard at once.
    readonly property Process feeder: Process {
        command: [root.script, "stream", root.host, `${Math.max(1, root.leds)}`,
                  "--fps", `${root.speed}`]
        running: SettingsService.wledOn && root.configured && root.leds > 0

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.ingest(line)
        }

        onExited: {
            if (SettingsService.wledOn && root.configured)
                root.reason = "The stream stopped"
        }
    }

    readonly property string streamKey: `${root.host}/${root.leds}/${root.speed}`

    onStreamKeyChanged: {
        if (root.feeder.running) {
            root.feeder.running = false
            restartDelay.restart()
        }
    }

    readonly property Timer restartDelay: Timer {
        interval: 120
        onTriggered: {
            if (SettingsService.wledOn && root.configured && root.leds > 0)
                root.feeder.running = true
        }
    }

    function ingest(line: string): void {
        if (line === "")
            return
        let report
        try {
            report = JSON.parse(line)
        } catch (error) {
            return
        }
        if (report.error) {
            root.reason = report.error
            return
        }
        root.reason = ""
        root.fps = report.fps ?? root.fps
        root.packets = report.packets ?? root.packets
        if (report.leds > 0 && report.leds !== root.savedLeds
                && root.savedLeds === 0)
            root.probedLeds = report.leds
        root.refreshed()
    }
    // ── WIDGET READOUTS ─────────────────────────────────────────────────────
    function note(): string {
        if (root.reason !== "")
            return root.reason
        if (!root.configured)
            return "No WLED host yet"
        if (!root.on)
            return "Off"
        return `${Math.round(root.fps)} fps · ${root.packets} packets`
    }
}
