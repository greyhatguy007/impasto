// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I N T E G R A T I O N S   S E C T I O N                                │
// │   the accounts the shell speaks to · one tab per service                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"
import "../components"

// Where the shell is pointed at a service and handed the key to it: the
// self-hosted Vikunja the task board syncs with, and Google Calendar beside
// it. The Vikunja token lives with the machine (`machineKeys`) so a profile
// switch never hands it to another desk; Google's refresh token goes further
// and never enters the settings at all — the connect script keeps it in its
// own state file.
SettingsSection {
    id: root

    // The visible part; set by `SettingsPanel`.
    property string tab: ""

    // What the project setting resolves to, so the id is not the only thing
    // on screen.
    readonly property string projectNote: {
        if (!VikunjaService.configured)
            return ""
        if (SettingsService.vikunjaProject > 0) {
            const named = VikunjaService.projectName(SettingsService.vikunjaProject)
            return named !== "" ? named : `${Tr.t("Project")} #${SettingsService.vikunjaProject}`
        }
        const first = VikunjaService.projects.find(project => !project.archived)
        return first ? `${first.title} · ${Tr.t("the first project")}`
                     : Tr.t("The first project the token owns")
    }

    readonly property string syncNote: {
        if (!VikunjaService.configured)
            return Tr.t("Local only — no server yet")
        if (VikunjaService.reason !== "")
            return `${Tr.t("Not syncing")} — ${VikunjaService.reasonLabel}`
        if (!VikunjaService.available)
            return Tr.t("Reaching the server…")
        const count = TasksService.remoteCount
        return `${Tr.t("Synced")} ${VikunjaService.age} · ${count} ${count === 1
            ? Tr.t("task on the server") : Tr.t("tasks on the server")}`
    }

    // What the calendar connection resolves to, so the key is not the only
    // thing on screen.
    readonly property string calendarNote: {
        if (!GCalendarService.configured)
            return Tr.t("Set a client id and secret first")
        if (GCalendarService.connected)
            return `${Tr.t("Connected")} · ${Tr.t("the token is on this machine")}`
        return Tr.t("Not connected yet")
    }

    readonly property string calendarSyncNote: {
        if (!GCalendarService.configured)
            return Tr.t("Local only — no client yet")
        if (!SettingsService.gcalSync)
            return Tr.t("Off — the calendar stays local")
        if (GCalendarService.reason !== "")
            return `${Tr.t("Not reading")} — ${GCalendarService.reasonLabel}`
        if (!GCalendarService.available)
            return Tr.t("Reaching Google…")
        const count = GCalendarService.events.length
        return `${Tr.t("Synced")} ${GCalendarService.age} · ${count} ${count === 1
            ? Tr.t("event in view") : Tr.t("events in view")}`
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "tasks"

        SettingGroup {
            title: "Vikunja"
            note: Tr.t("A self-hosted task board, folded into the board here.")
            hint: Tr.t("Enter the address of your Vikunja server and an API token from Vikunja's Settings → API tokens. Tasks are read from the server and your own changes are sent back; with no server set, the board stays local. The token is kept in the shell's settings file on this machine.")

            SettingField {
                label: Tr.t("Server")
                placeholder: "https://tasks.example.com"
                value: SettingsService.vikunjaUrl
                onEdited: value => SettingsService.set("vikunjaUrl", value.trim())
            }

            SettingField {
                label: Tr.t("API token")
                secret: true
                placeholder: Tr.t("Paste the token from Vikunja")
                value: SettingsService.vikunjaToken
                onEdited: value => SettingsService.set("vikunjaToken", value.trim())
            }

            SettingField {
                label: Tr.t("Project")
                reading: root.projectNote
                placeholder: Tr.t("The first project")
                value: SettingsService.vikunjaProject > 0
                    ? `${SettingsService.vikunjaProject}` : ""
                onEdited: value => SettingsService.set(
                    "vikunjaProject", Math.max(0, parseInt(value.trim(), 10) || 0))
            }

            SettingRow {
                label: Tr.t("Sync")
                reading: !VikunjaService.configured
                    ? Tr.t("Set a server and a token first")
                    : (SettingsService.vikunjaSync
                        ? Tr.t("On — the board follows the server")
                        : Tr.t("Off — the board stays local"))

                ToggleSwitch {
                    checked: SettingsService.vikunjaSync
                    onToggled: checked => SettingsService.set("vikunjaSync", checked)
                }
            }

            SettingRow {
                label: Tr.t("Sync now")
                reading: root.syncNote
                alarm: VikunjaService.reason !== ""

                PillButton {
                    text: Tr.t("Refresh")
                    icon: "󰑐"
                    enabled: VikunjaService.syncing
                    onClicked: VikunjaService.refresh()
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "calendar"

        SettingGroup {
            title: "Google Calendar"
            note: Tr.t("Your days, folded in beside the tasks.")
            hint: Tr.t("Make an OAuth client of the desktop kind in Google Cloud Console (APIs & Services → Credentials), with the Calendar API enabled, and paste its id and secret here. Connecting opens the browser once to agree; the refresh token is kept in the shell's state on this machine and never in the settings file. Read-only: the shell writes nothing to your calendar.")

            SettingField {
                label: Tr.t("Client id")
                placeholder: "1234567890-abc.apps.googleusercontent.com"
                value: SettingsService.gcalClientId
                onEdited: value => SettingsService.set("gcalClientId", value.trim())
            }

            SettingField {
                label: Tr.t("Client secret")
                secret: true
                placeholder: Tr.t("Paste the client secret")
                value: SettingsService.gcalClientSecret
                onEdited: value => SettingsService.set("gcalClientSecret", value.trim())
            }

            SettingField {
                label: Tr.t("Calendar")
                placeholder: "primary"
                value: SettingsService.gcalCalendar
                onEdited: value => SettingsService.set("gcalCalendar", value.trim())
            }

            SettingRow {
                label: Tr.t("Connection")
                reading: root.calendarNote

                PillButton {
                    text: GCalendarService.connected ? Tr.t("Disconnect")
                        : (GCalendarService.connecting ? "…" : Tr.t("Connect"))
                    icon: GCalendarService.connected ? "󰌾" : "󰂽"
                    enabled: GCalendarService.configured && !GCalendarService.connecting
                              && !GCalendarService.disconnecting
                    onClicked: GCalendarService.connected
                        ? GCalendarService.disconnect() : GCalendarService.connect()
                }
            }

            SettingRow {
                label: Tr.t("Sync")
                reading: !GCalendarService.configured
                    ? Tr.t("Set a client id and secret first")
                    : (SettingsService.gcalSync
                        ? Tr.t("On — events come down and are read")
                        : Tr.t("Off — the calendar stays local"))

                ToggleSwitch {
                    checked: SettingsService.gcalSync
                    onToggled: checked => SettingsService.set("gcalSync", checked)
                }
            }

            SettingRow {
                label: Tr.t("Sync now")
                reading: root.calendarSyncNote
                alarm: GCalendarService.reason !== ""

                PillButton {
                    text: Tr.t("Refresh")
                    icon: "󰑐"
                    enabled: GCalendarService.syncing
                    onClicked: GCalendarService.refresh()
                }
            }
        }
    }
}
