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

    // One choice in a row of short names, for the two lists that are a list of
    // names rather than a value: which transcripts to count, and which paired
    // device to ask. Written once here because both want the same pill, and a
    // segment control would be for two or three options where this is a hand
    // of them.
    component SourcePill: Rectangle {
        id: pill

        property string text: ""
        property bool chosen: false
        // Dimmed rather than hidden: a source this machine has no transcripts
        // for is worth showing, so the list does not quietly change with what
        // happens to be installed.
        property bool dimmed: false

        signal picked()

        implicitWidth: caption.implicitWidth + 26
        implicitHeight: 30
        radius: Theme.radiusSmall
        color: pill.chosen ? Theme.accent
            : (mouse.containsMouse ? Theme.islandSurfaceHover : Theme.islandSurface)
        border.width: 1
        border.color: pill.chosen ? Theme.accent : Theme.islandBorder
        opacity: pill.dimmed ? 0.5 : 1

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

        Text {
            id: caption

            anchors.centerIn: parent
            text: pill.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: pill.chosen ? Theme.accentText : Theme.text
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.picked()
        }
    }

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

    // What the wallpaper gallery resolves to, so the source and the key are
    // not the only thing on screen.
    readonly property string wallpaperNote: {
        if (WallpaperFeed.busy)
            return Tr.t("Reaching the source…")
        if (WallpaperFeed.reason === "auth")
            return Tr.t("The key was refused — check it and browse again")
        if (WallpaperFeed.reason === "setup")
            return WallpaperFeed.sources.length > 0
                ? WallpaperFeed.sources.find(entry => entry.id === WallpaperFeed.provider)?.note
                    ?? Tr.t("This source needs a key")
                : Tr.t("No source yet")
        if (WallpaperFeed.reason === "provider")
            return Tr.t("Nothing that size for that topic")
        if (WallpaperFeed.reason !== "")
            return Tr.t("The source did not answer")
        if (WallpaperFeed.photos.length > 0)
            return `${Tr.t("Browse again for another set")}`
        return Tr.t("Browse to fill the gallery")
    }

    // Which photo is coming down, for the browse row's reading.
    readonly property string fetchNote: {
        if (WallpaperFeed.fetchingId === "")
            return ""
        const photo = WallpaperFeed.photos.find(
            entry => entry.id === WallpaperFeed.fetchingId)
        return photo ? `${Tr.t("Fetching")} — ${photo.artist}` : Tr.t("Fetching")
    }

    // Where the assistant figures come from, said the way a desk needs it: the
    // transcripts it is reading, and — when a gateway will answer — the plan
    // it is on.
    readonly property string usageNote: {
        if (!AiUsageService.available)
            return Tr.t("No transcripts found")
        const where = AiUsageService.label !== ""
            ? AiUsageService.label : Tr.t("every assistant found")
        const counted = `${AiUsageService.messages(AiUsageService.blockMessages)} ${Tr.t("in this block")}`
        if (AiUsageService.gatewayKnows)
            return `${where} · ${counted} · ${AiUsageService.gatewayNote}`
        return `${where} · ${counted}`
    }

    // The gateway group's own line: what the last ask came back with, or what
    // the shell expects to be able to say about it.
    property bool asked: false
    readonly property string gatewayNote: root.asked
        ? (AiUsageService.testing ? Tr.t("Asking…") : AiUsageService.answerNote)
        : SettingsService.omniEndpoint !== ""
            ? Tr.t("Set, and not yet asked")
            : Tr.t("Asking pi's own gateway")

    // The gateway widget's line: what the last full report said, or what the
    // one-off test came back with.
    readonly property string gatewayWidgetNote: {
        if (OmniRouteService.testing)
            return Tr.t("Asking…")
        if (OmniRouteService.available)
            return `${OmniRouteService.host} · ${Math.round(OmniRouteService.success)}% · ${OmniRouteService.money(OmniRouteService.cost)}`
        if (OmniRouteService.answer) {
            if (OmniRouteService.answer.available === true)
                return `${Tr.t("answered")}${OmniRouteService.answer.version !== ""
                    ? ` · ${OmniRouteService.answer.version}` : ""}`
            return OmniRouteService.answer.reason ?? ""
        }
        return OmniRouteService.statusNote
    }

    readonly property string phoneNote: {
        if (!KdeConnectService.available)
            return KdeConnectService.statusNote
        if (KdeConnectService.hasBattery)
            return `${KdeConnectService.name} · ${KdeConnectService.battery}%`
                + (KdeConnectService.charging ? ` · ${Tr.t("charging")}` : "")
        return `${KdeConnectService.name} · ${KdeConnectService.type === "tablet"
            ? Tr.t("tablet") : Tr.t("phone")}`
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

    // ── NOTES ────────────────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "notes"

        SettingGroup {
            title: "Obsidian"
            note: Tr.t("Keep your notes in an Obsidian vault.")
            hint: Tr.t("Enter the vault folder. Notes are stored in its notes/ subfolder as Markdown files. Leave this empty to use the local JSON notes store.")

            SettingField {
                label: Tr.t("Vault folder")
                placeholder: "~/Desktop/Tech Vault"
                commitOnEditingFinished: true
                value: SettingsService.obsidianVaultPath
                onEdited: value => SettingsService.set("obsidianVaultPath", value.trim())
            }
        }
    }

    // ── WALLPAPER ───────────────────────────────────────────────────────────
    //
    // A source the settings name, at the width they name. A search fills the
    // gallery; a picture is fetched into the wallpaper directory and applied
    // with one click. One row per control, in the section's card.
    ColumnLayout {
        id: wallpaperTab

        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "wallpaper"

        // The service works for whoever holds it, like the other
        // subscription services; the settings window holds it while open.
        Component.onCompleted: WallpaperFeed.subscribe()
        Component.onDestruction: WallpaperFeed.release()

        SettingGroup {
            title: Tr.t("Wallpaper gallery")
            note: Tr.t("Photographs from whichever source you name, at the width your screens are.")
            hint: Tr.t("Browse asks the source for pictures on the topic and fills the gallery below; pick one to fetch it into your wallpapers and apply it, and the palette follows the new picture. Two of the sources are free and need no account; Unsplash and Pexels search properly with a key from their developers' pages, which is kept on this machine. The width is what the panel is about to fill, so a source is never asked for a picture smaller than the screen.")

            // One tile per source, each saying what it costs. The key field
            // only appears for the two that want one, rather than sitting
            // there uselessly for the three that do not.
            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: WallpaperFeed.sources

                    delegate: Rectangle {
                        id: sourceTile

                        required property var modelData
                        readonly property bool chosen:
                            SettingsService.wallpaperProvider === modelData.id

                        width: 186
                        height: 62
                        radius: Theme.radiusSmall
                        color: sourceTile.chosen ? Theme.accent
                            : (sourceMouse.containsMouse ? Theme.islandSurfaceHover
                                : Theme.islandSurface)
                        border.width: 1
                        border.color: sourceTile.chosen ? Theme.accent : Theme.islandBorder

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 9
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: sourceTile.modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                    color: sourceTile.chosen ? Theme.accentText : Theme.text
                                }

                                Item { Layout.fillWidth: true }

                                // A source that was asked and had nothing to
                                // say is marked, so a wrong key is visible
                                // without opening a log.
                                Text {
                                    visible: sourceTile.modelData.searched
                                        && !sourceTile.modelData.available
                                    text: "󰅚"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.indicatorBad
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: sourceTile.modelData.note
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: sourceTile.chosen ? Theme.accentText
                                    : Theme.textMuted
                            }
                        }

                        MouseArea {
                            id: sourceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: SettingsService.set(
                                "wallpaperProvider", modelData.id)
                        }
                    }
                }
            }

            SettingField {
                label: Tr.t("Topic")
                placeholder: Tr.t("nature, fog, brutalism…")
                value: SettingsService.wallpaperQuery
                onEdited: value => SettingsService.set("wallpaperQuery", value.trim())
            }

            // The width a source is asked for. A picture smaller than the
            // screen is the one mistake the shell cannot fix afterwards, so
            // the presets are the desktop's own resolutions and the field
            // takes any of them.
            SettingRow {
                label: Tr.t("Width")
                reading: `${SettingsService.wallpaperWidth}px`

                Row {
                    spacing: 6

                    Repeater {
                        model: [1920, 2560, 3440, 3840]

                        delegate: PillButton {
                            required property int modelData

                            text: `${modelData}`
                            active: SettingsService.wallpaperWidth === modelData
                            onClicked: SettingsService.set("wallpaperWidth", modelData)
                        }
                    }
                }
            }

            SettingField {
                visible: WallpaperFeed.needsKey
                label: Tr.t("Access key")
                secret: true
                placeholder: Tr.t("From the source's developers' page")
                value: SettingsService.wallpaperKey
                onEdited: value => SettingsService.set("wallpaperKey", value.trim())
            }

            SettingRow {
                label: Tr.t("Gallery")
                reading: root.wallpaperNote
                alarm: WallpaperFeed.reason === "auth" || WallpaperFeed.reason === "provider"

                Row {
                    spacing: 8

                    PillButton {
                        text: WallpaperFeed.busy ? "…" : Tr.t("Browse")
                        icon: "󰸉"
                        enabled: !WallpaperFeed.busy
                        onClicked: {
                            root.skipFetching()
                            WallpaperFeed.refresh()
                        }
                    }

                    PillButton {
                        text: Tr.t("Shuffle")
                        icon: "󰒝"
                        enabled: !WallpaperFeed.busy && WallpaperFeed.photos.length > 0
                        onClicked: {
                            root.skipFetching()
                            root.shuffled = (root.shuffled + 1) % 100
                            WallpaperFeed.refreshWithVariation(root.shuffled)
                        }
                    }
                }
            }

            SettingRow {
                label: Tr.t("Fetch & apply")
                reading: root.fetchNote !== "" ? root.fetchNote
                    : (WallpaperFeed.photos.length === 0
                        ? Tr.t("Browse first, then pick")
                        : Tr.t("Pick a picture below"))

                PillButton {
                    text: Tr.t("Shuffle wallpaper")
                    icon: "󰒘"
                    enabled: WallpaperFeed.photos.length > 0
                        && WallpaperFeed.fetchingId === ""
                    onClicked: root.shuffleWallpaper()
                }
            }
        }

        // The gallery: thumbnails of the current search, one fetch per
        // picture, applied when it lands. Emptied by a topic change.
        Flow {
            Layout.fillWidth: true
            visible: WallpaperFeed.photos.length > 0
            spacing: 10

            Repeater {
                model: WallpaperFeed.photos

                delegate: Rectangle {
                    id: tile

                    required property var modelData
                    readonly property bool fetched: WallpaperFeed.isFetched(modelData.id)
                    readonly property bool fetching:
                        WallpaperFeed.fetchingId === modelData.id

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
                                WallpaperFeed.applyFetched(tile.modelData)
                            else
                                WallpaperFeed.fetch(tile.modelData)
                        }
                    }

                    // The cross, on a fetched tile only: it deletes the file
                    // that fetch wrote, and forgets the photograph with it,
                    // so the same one can be fetched again later. Armed once,
                    // the way the appearance panel's cross is, because a file
                    // deleted by a stray press is a file to fetch again.
                    Rectangle {
                        id: drop

                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 5
                        width: 16
                        height: 16
                        radius: width / 2
                        z: 2

                        readonly property bool mine: root.arming === tile.modelData.id
                        readonly property bool armed: root.arming !== "" && drop.mine
                        readonly property bool shown: tile.fetched
                            && !tile.fetching && (dropMouse.containsMouse || drop.armed)

                        visible: drop.shown
                        color: drop.armed ? Theme.indicatorBad
                            : (dropMouse.containsMouse ? "#B0000000" : "#73000000")

                        Behavior on color {
                            ColorAnimation { duration: Theme.durationFast }
                        }

                        MouseArea {
                            id: dropMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (drop.armed) {
                                    root.arming = ""
                                    WallpaperFeed.discard(tile.modelData)
                                } else {
                                    root.arming = tile.modelData.id
                                    root.disarmTimer.restart()
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            color: drop.armed ? "#FFFFFF" : Theme.text
                        }
                    }

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.margins: 4
                        width: parent.width - 8
                        visible: tileMouse.hovered
                        // Wallhaven names a photographer only when the answer
                        // is asked with a key; without one the id is the name
                        // the file gets on disk, so it is the name worth seeing.
                        text: tile.modelData.artist || tile.modelData.id
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
            visible: WallpaperFeed.fetchingId !== ""
            reading: root.fetchNote

            PillButton {
                text: Tr.t("Stop")
                icon: "󰇻"
                onClicked: root.skipFetching()
            }
        }
    }

    // ── ASSISTANT USAGE ────────────────────────────────────────────────────
    //
    // The usage module reads the transcripts the assistants already write on
    // this machine, so there is no account to connect and no key to paste.
    // What it cannot know is the ceiling those transcripts are measured
    // against: the plan's quota is a number only the user has, and without it
    // the ring shows the block's elapsed time and says so.
    ColumnLayout {
        id: usageTab

        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "usage"

        // Reading the service is cheap and lazy; the settings holding it open
        // is enough, and it only costs anything when something changes.
        Component.onCompleted: AiUsageService.subscribe()
        Component.onDestruction: AiUsageService.release()

        SettingGroup {
            title: Tr.t("Assistant usage")
            note: Tr.t("Tokens for the current block and the last seven days, read from the transcripts on this machine.")
            hint: Tr.t("Nothing is sent anywhere: the numbers are counted from the transcripts each assistant already writes on disk. A block runs five hours from its first message, so the countdown to the reset is exact. Without a quota the ring shows how long the block has been running and no percentage is claimed, since a percentage of what? Put your plan's limits below and the bar is measured against them, and the face turns red as the block runs out.")

            // Which assistant to measure. "Every one" sums the transcripts
            // of all of them, which is the honest answer for a desk that
            // uses more than one and no honest answer at all for a plan that
            // charges per account. The list is the script's: it is what knows
            // which transcripts exist, and a source whose folder is not there
            // is drawn dim rather than hidden, so a machine that has not used
            // one still says so.
            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: AiUsageService.sources

                    delegate: SourcePill {
                        required property var modelData

                        text: modelData.label
                        chosen: SettingsService.aiProvider === modelData.id
                        dimmed: !modelData.ready
                        onPicked: SettingsService.set("aiProvider", modelData.id)
                    }
                }
            }

            SettingRow {
                label: Tr.t("This block")
                reading: root.usageNote
                alarm: !AiUsageService.available

                Figure {
                    value: AiUsageService.available
                        ? AiUsageService.compact(AiUsageService.blockTokens) : "—"
                    note: {
                        if (!AiUsageService.available)
                            return Tr.t("no transcripts found")
                        return `${AiUsageService.messages(AiUsageService.blockMessages)} · ${AiUsageService.resetsIn}`
                    }
                }
            }

            SettingRow {
                label: Tr.t("This week")
                reading: {
                    if (!AiUsageService.available)
                        return ""
                    return `${AiUsageService.compact(AiUsageService.weekTokens)} ${Tr.t("tokens")} · ${AiUsageService.models.length} ${Tr.t("models")}`
                }

                Figure {
                    value: AiUsageService.available
                        ? AiUsageService.percent(AiUsageService.weeklyFraction) : "—"
                    note: {
                        if (!AiUsageService.available)
                            return ""
                        return AiUsageService.weeklyMeasured
                            ? Tr.t("of the week's quota")
                            : Tr.t("of the busiest week on record")
                    }
                }
            }
        }

        SettingGroup {
            title: Tr.t("OmniRoute")
            note: Tr.t("A gateway, read through its own management API.")
            hint: Tr.t("The endpoint and the key it issued. Leave both empty and pi's own provider entry names the gateway, which is the answer on a desk where the gateway is only ever pi's. With them set, the OmniRoute module draws the gateway's traffic, models, providers, recent requests and server health straight from the endpoint — nothing on this machine is counted. The key lives in the shell's settings file on this machine, is left out of profiles and exports, and is never echoed back.")

            SettingField {
                label: Tr.t("Endpoint")
                placeholder: "https://gateway.example.com/v1"
                value: SettingsService.omniEndpoint
                onEdited: value => {
                    SettingsService.set("omniEndpoint", value.trim())
                    root.asked = false
                }
            }

            SettingField {
                label: Tr.t("API key")
                secret: true
                placeholder: Tr.t("The key the gateway issued")
                value: SettingsService.omniApiKey
                onEdited: value => {
                    SettingsService.set("omniApiKey", value.trim())
                    root.asked = false
                }
            }

            SettingRow {
                label: Tr.t("Ask it")
                reading: root.gatewayNote
                alarm: root.asked && AiUsageService.gatewayFault === true

                PillButton {
                    text: AiUsageService.testing ? Tr.t("Asking…") : Tr.t("Ask it now")
                    icon: "󰓢"
                    enabled: !AiUsageService.testing
                    onClicked: {
                        root.asked = true
                        AiUsageService.testGateway()
                    }
                }
            }

            // The gateway as a widget: its own figures, and a button that
            // reads them on demand rather than waiting for the poll.
            SettingRow {
                label: Tr.t("Gateway widget")
                reading: root.gatewayWidgetNote
                alarm: !OmniRouteService.available && OmniRouteService.fetchedAt > 0

                PillButton {
                    text: OmniRouteService.testing ? Tr.t("Asking…") : Tr.t("Try the endpoint")
                    icon: "󰑐"
                    enabled: !OmniRouteService.testing
                    onClicked: OmniRouteService.test()
                }
            }
        }

        SettingGroup {
            title: Tr.t("Transcripts")
            note: Tr.t("Where to read them, for a home directory that is not where the shell looks.")
            hint: Tr.t("Each assistant keeps its history in its own place, and the shell reads all the ones it knows. If yours lives somewhere else — a second machine's disk, an encrypted mount, a container — write the extra directories here, one per line, and they are read alongside the usual ones.")

            SettingField {
                label: Tr.t("Extra directories")
                placeholder: Tr.t("/mnt/work/agents, /srv/logs/codex")
                value: SettingsService.aiLogs
                onEdited: value => SettingsService.set("aiLogs", value.trim())
            }

            SettingField {
                label: Tr.t("pi's logs")
                placeholder: Tr.t("~/.pi/agent/sessions")
                value: SettingsService.aiPiLogs
                onEdited: value => SettingsService.set("aiPiLogs", value.trim())
            }
        }
    }

    // ── PHONE ───────────────────────────────────────────────────────────────
    //
    // KDE Connect, which is a pair and a socket and nothing else: the phone
    // is found on the network, and everything below is one of the things that
    // pairing makes possible. Which of them are offered is the phone's to
    // refuse, so this shows what it answered rather than what KDE Connect can
    // do in general.
    ColumnLayout {
        id: phoneTab

        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "phone"

        Component.onCompleted: KdeConnectService.subscribe()
        Component.onDestruction: KdeConnectService.release()

        SettingGroup {
            title: Tr.t("Paired phone")
            note: Tr.t("The phone on this network, and what it will do when asked.")
            hint: Tr.t("KDE Connect pairs over the local network and does not need a server or an account. The phone's charge takes the ring on the bar beside the laptop's own battery, and the module's buttons are the things this particular pairing offers — a phone that refuses to be rung is not shown a bell. Music played on the phone can take over the desk's player, so the keys and the bar control it as if it were local.")

            // The paired devices the daemon knows, as tiles. One phone on a
            // desk is the common case and needs no choice at all, so the
            // automatic tile is first and the rest are the alternative.
            Flow {
                Layout.fillWidth: true
                visible: KdeConnectService.devices.length > 0
                spacing: 8

                Repeater {
                    model: [{ id: "", name: Tr.t("The one that answers"), type: "" }]
                            .concat(KdeConnectService.devices.map(
                                entry => ({ id: entry.id, name: entry.name,
                                    type: entry.type })))

                    delegate: SourcePill {
                        required property var modelData

                        text: modelData.name
                            + (modelData.type === "tablet" ? " (tablet)" : "")
                        chosen: SettingsService.kdeconnectDevice === modelData.id
                        onPicked: {
                            SettingsService.set("kdeconnectDevice", modelData.id)
                            KdeConnectService.poll()
                        }
                    }
                }
            }

            SettingRow {
                label: Tr.t("Phone")
                reading: root.phoneNote
                alarm: !KdeConnectService.available && KdeConnectService.reason === "pairing"

                Row {
                    spacing: 8

                    PillButton {
                        text: KdeConnectService.busy ? "…" : Tr.t("Find it")
                        icon: "󰋄"
                        enabled: !KdeConnectService.busy
                        onClicked: KdeConnectService.refresh()
                    }

                    PillButton {
                        text: Tr.t("Ring")
                        icon: "󰇰"
                        enabled: KdeConnectService.available && KdeConnectService.can.ring
                        onClicked: KdeConnectService.ring()
                    }

                    PillButton {
                        text: Tr.t("Ping")
                        icon: "󰍣"
                        enabled: KdeConnectService.available && KdeConnectService.can.ping
                        onClicked: KdeConnectService.ping(Tr.t("From the desk"))
                    }
                }
            }

            SettingRow {
                label: Tr.t("The phone's music")
                reading: {
                    if (MediaService.origin !== "phone")
                        return Tr.t("Not playing on the phone")
                    return MediaService.artist !== ""
                        ? `${MediaService.title} · ${MediaService.artist}`
                        : MediaService.title
                }

                ToggleSwitch {
                    checked: SettingsService.phoneMedia
                    onToggled: SettingsService.set("phoneMedia", !checked)
                }
            }

            SettingRow {
                label: Tr.t("Shared clipboard")
                reading: {
                    if (!SettingsService.phoneClipboard)
                        return Tr.t("Off — the two clipboards stay apart")
                    return Tr.t("A copy on the phone lands here, and the button sends this desk's back")
                }

                ToggleSwitch {
                    checked: SettingsService.phoneClipboard
                    onToggled: SettingsService.set("phoneClipboard", !checked)
                }
            }
        }
    }

    // ── GALLERY HELPERS ─────────────────────────────────────────────────────

    property int shuffled: 0

    // Which tile's cross is armed, and how long it stays that way. One at a
    // time, and dropped again by a fresh press on anything else: a gallery of
    // files that vanish on one click is a gallery nobody trusts.
    property string arming: ""

    Timer {
        id: disarmTimer
        interval: 4000
        onTriggered: root.arming = ""
    }

    function skipFetching(): void {
        WallpaperFeed.skip()
    }

    function shuffleWallpaper(): void {
        const waiting = WallpaperFeed.photos.filter(
            photo => !WallpaperFeed.isFetched(photo.id))
        const pool = waiting.length > 0 ? waiting : WallpaperFeed.photos
        if (pool.length === 0)
            return
        const photo = pool[Math.floor(Math.random() * pool.length)]
        if (WallpaperFeed.isFetched(photo.id))
            WallpaperFeed.applyFetched(photo)
        else
            WallpaperFeed.fetch(photo)
    }
}
