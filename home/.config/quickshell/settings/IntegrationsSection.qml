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

    // What the wallpaper gallery resolves to, so the key is not the only
    // thing on screen.
    readonly property string wallpaperNote: {
        if (UnsplashService.busy)
            return Tr.t("Reaching the provider…")
        if (UnsplashService.reason === "auth")
            return Tr.t("The key was refused — check it and browse again")
        if (UnsplashService.reason === "setup")
            return Tr.t("No provider yet")
        if (UnsplashService.reason !== "")
            return Tr.t("The provider did not answer")
        if (UnsplashService.provider === "picsum")
            return Tr.t("Picsum — free, no key; add an Unsplash key for topics")
        if (UnsplashService.provider === "unsplash")
            return Tr.t("Unsplash — your key, your topic")
        return Tr.t("Browse to fill the gallery")
    }

    // Which photo is coming down, for the browse row's reading.
    readonly property string fetchNote: {
        if (UnsplashService.fetchingId === "")
            return ""
        const photo = UnsplashService.photos.find(
            entry => entry.id === UnsplashService.fetchingId)
        return photo ? `${Tr.t("Fetching")} — ${photo.artist}` : Tr.t("Fetching")
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

    // ── WALLPAPER ───────────────────────────────────────────────────────────
    //
    // Unsplash with an access key, Picsum without one. A search fills the
    // gallery; a picture is fetched into the wallpaper directory and applied
    // with one click. One row per control, in the section's card.
    ColumnLayout {
        id: wallpaperTab

        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "wallpaper"

        // The service works for whoever holds it, like the other
        // subscription services; the settings window holds it while open.
        Component.onCompleted: UnsplashService.subscribe()
        Component.onDestruction: UnsplashService.release()

        SettingGroup {
            title: Tr.t("Wallpaper gallery")
            note: Tr.t("Photographs from Unsplash — or Picsum, free and keyless.")
            hint: Tr.t("Browse asks the provider for pictures on the topic and fills the gallery below; pick one to fetch it into your wallpapers and apply it, and the palette follows the new picture. An access key from unsplash.com/developers turns the topic into a real search; without one, Picsum serves a curated pick and the topic only seeds it. The key is kept on this machine.")

            SettingField {
                label: Tr.t("Topic")
                placeholder: Tr.t("nature, fog, brutalism…")
                value: SettingsService.unsplashQuery
                onEdited: value => SettingsService.set("unsplashQuery", value.trim())
            }

            SettingField {
                label: Tr.t("Access key")
                secret: true
                placeholder: Tr.t("Optional — from unsplash.com/developers")
                value: SettingsService.unsplashKey
                onEdited: value => SettingsService.set("unsplashKey", value.trim())
            }

            SettingRow {
                label: Tr.t("Gallery")
                reading: root.wallpaperNote
                alarm: UnsplashService.reason === "auth"

                Row {
                    spacing: 8

                    PillButton {
                        text: UnsplashService.busy ? "…" : Tr.t("Browse")
                        icon: "󰸉"
                        enabled: !UnsplashService.busy
                        onClicked: {
                            root.skipFetching()
                            UnsplashService.refresh()
                        }
                    }

                    PillButton {
                        text: Tr.t("Shuffle")
                        icon: "󰒝"
                        enabled: !UnsplashService.busy && UnsplashService.photos.length > 0
                        onClicked: {
                            root.skipFetching()
                            root.shuffled = (root.shuffled + 1) % 100
                            UnsplashService.refreshWithVariation(root.shuffled)
                        }
                    }
                }
            }

            SettingRow {
                label: Tr.t("Fetch & apply")
                reading: root.fetchNote !== "" ? root.fetchNote
                    : (UnsplashService.photos.length === 0
                        ? Tr.t("Browse first, then pick")
                        : Tr.t("Pick a picture below"))

                PillButton {
                    text: Tr.t("Shuffle wallpaper")
                    icon: "󰒘"
                    enabled: UnsplashService.photos.length > 0
                        && UnsplashService.fetchingId === ""
                    onClicked: root.shuffleWallpaper()
                }
            }
        }

        // The gallery: thumbnails of the current search, one fetch per
        // picture, applied when it lands. Emptied by a topic change.
        Flow {
            Layout.fillWidth: true
            visible: UnsplashService.photos.length > 0
            spacing: 10

            Repeater {
                model: UnsplashService.photos

                delegate: Rectangle {
                    id: tile

                    required property var modelData
                    readonly property bool fetched: UnsplashService.isFetched(modelData.id)
                    readonly property bool fetching:
                        UnsplashService.fetchingId === modelData.id

                    width: 108
                    height: 72
                    radius: Theme.radiusSmall
                    color: Theme.islandSurface
                    border.color: tile.fetching ? Theme.accent
                        : (tile.fetched ? Theme.accent : Theme.islandBorder)
                    border.width: tile.fetching || tile.fetched ? 2 : 1

                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        source: tile.modelData.thumb !== "" ? tile.modelData.thumb : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: tileMouse.hovered ? "#33000000" : "#00000000"

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: tile.fetched && !tile.fetching
                        text: "󰄬"
                        font.family: Theme.fontMono
                        font.pixelSize: 14
                        color: Theme.accentText
                    }

                    MouseArea {
                        id: tileMouse
                        property bool hovered: containsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (tile.fetching)
                                return
                            if (tile.fetched)
                                UnsplashService.applyFetched(tile.modelData)
                            else
                                UnsplashService.fetch(tile.modelData)
                        }
                    }

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.margins: 4
                        width: parent.width - 8
                        visible: tileMouse.hovered
                        text: tile.modelData.artist
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        color: Theme.scrimText
                    }
                }
            }
        }

        SettingRow {
            label: Tr.t("Stop fetching")
            visible: UnsplashService.fetchingId !== ""
            reading: root.fetchNote

            PillButton {
                text: Tr.t("Stop")
                icon: "󰇻"
                onClicked: root.skipFetching()
            }
        }
    }

    // ── GALLERY HELPERS ─────────────────────────────────────────────────────

    property int shuffled: 0

    function skipFetching(): void {
        UnsplashService.skip()
    }

    function shuffleWallpaper(): void {
        const waiting = UnsplashService.photos.filter(
            photo => !UnsplashService.isFetched(photo.id))
        const pool = waiting.length > 0 ? waiting : UnsplashService.photos
        if (pool.length === 0)
            return
        const photo = pool[Math.floor(Math.random() * pool.length)]
        if (UnsplashService.isFetched(photo.id))
            UnsplashService.applyFetched(photo)
        else
            UnsplashService.fetch(photo)
    }
}
