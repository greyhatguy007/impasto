// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G C A L E N D A R   S E R V I C E                                      │
// │   events from Google Calendar · read-only                                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// The Google Calendar side of the calendar: reads the next few weeks of
// events through `scripts/gcalendar.py`, which holds the client keys from
// Settings → Integrations and keeps the refresh token in its own state file
// on this machine.
//
// It holds no events of its own for the board — the calendar card folds what
// comes back beside the tasks it already draws, and nothing runs without a
// client id and secret, so an unconfigured machine reads nothing on the
// network. Connecting once needs a browser; the script does that on demand.
Singleton {
    id: root

    // ── CONFIGURATION ───────────────────────────────────────────────────────

    readonly property string clientId: SettingsService.gcalClientId.trim()
    readonly property string clientSecret: SettingsService.gcalClientSecret.trim()

    // Both halves are needed; half a client would only fail on every poll.
    readonly property bool configured: root.clientId !== "" && root.clientSecret !== ""

    // The switch in Settings, and whether there is anything to switch on.
    readonly property bool syncing: root.configured && SettingsService.gcalSync

    // ── STATE ───────────────────────────────────────────────────────────────

    // A read has come back whole. `connected` says a refresh token exists,
    // which only `connect` can make true.
    property bool available: false
    property bool connected: false

    // "" when all is well, otherwise the reason the settings page shows.
    property string reason: ""

    property var events: []
    property date readAt: new Date(0)

    readonly property int pollInterval: 900000

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

    // One clause per reason, for the settings page and the calendar card.
    readonly property string reasonLabel: {
        switch (root.reason) {
        case "setup":   return Tr.t("Add the client id and secret")
        case "connect": return Tr.t("Connect once in the browser")
        case "auth":    return Tr.t("Google refused the key")
        case "url":     return Tr.t("Google did not answer")
        case "network": return Tr.t("No connection to Google")
        case "spawn":   return Tr.t("The script could not be run")
        }
        return ""
    }

    // The day's events, soonest first, for a day key like the board's.
    function on(day: string): var {
        return root.events.filter(event => event.day === day || (event.allDay
            && event.day <= day && day < (event.endDay > event.day ? event.endDay : "")))
    }

    // The next few, from now on, however far they sit.
    readonly property var upcoming: {
        const today = root.dayOf(root.clock.date)
        const list = root.events.filter(event =>
            (event.endDay || event.day) >= today)
        return list.slice(0, 5)
    }

    function dayOf(date: var): string {
        return Qt.formatDate(date, "yyyy-MM-dd")
    }

    // ── READING ─────────────────────────────────────────────────────────────

    Component.onCompleted: root.refresh()

    // A change to any of the credentials is a different client; read again
    // at once rather than waiting for the poll.
    readonly property Connections settings: Connections {
        target: SettingsService

        function onGcalClientIdChanged(): void { root.reread() }
        function onGcalClientSecretChanged(): void { root.reread() }
        function onGcalCalendarChanged(): void { root.reread() }
        function onGcalSyncChanged(): void { root.reread() }
    }

    function reread(): void {
        if (root.syncing) {
            root.refresh()
            return
        }
        // Switched off, or a credential was removed: forget Google's side so
        // no stale events stay on the calendar.
        root.available = false
        root.events = []
        root.reason = ""
    }

    // Set when a read is started, cleared when its answer comes back. A
    // start that neither answers nor runs at all — the script could not be
    // spawned, which sends no exit and no output — is said by the guard,
    // rather than waited on forever.
    property bool awaitingRead: false

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
        command: [Quickshell.shellPath("scripts/gcalendar.py"), "events"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.awaitingRead = false
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the calendar events:", error)
                    root.reason = "network"
                    return
                }
                root.connected = report.connected === true
                if (report.available !== true) {
                    root.available = false
                    root.reason = report.reason ?? "network"
                    return
                }
                root.events = report.events ?? []
                root.reason = ""
                root.readAt = new Date()
                root.available = true
            }
        }
    }

    // ── CONNECTING ──────────────────────────────────────────────────────────
    //
    // The one-time browser flow, run by the script on demand. It takes as
    // long as the person behind the browser takes, so this process gets no
    // guard; the settings page says what is happening instead.

    property bool connecting: false

    function connect(): void {
        if (root.connecting || !root.configured)
            return
        root.connecting = true
        root.link.running = true
    }

    readonly property Process link: Process {
        command: [Quickshell.shellPath("scripts/gcalendar.py"), "connect"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.connecting = false
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    root.reason = "network"
                    return
                }
                root.connected = report.connected === true
                if (report.available !== true) {
                    root.reason = report.reason ?? "connect"
                    return
                }
                root.reason = ""
                root.refresh()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                // The authorize URL, for a machine without a browser to open.
                if (text.trim() !== "")
                    console.info("gcalendar:", text.trim())
            }
        }
    }

    function disconnect(): void {
        root.disconnecting = true
        root.unlink.running = true
    }

    property bool disconnecting: false

    readonly property Process unlink: Process {
        command: [Quickshell.shellPath("scripts/gcalendar.py"), "disconnect"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.disconnecting = false
                root.connected = false
                root.available = false
                root.events = []
                root.reason = ""
            }
        }
    }
}
