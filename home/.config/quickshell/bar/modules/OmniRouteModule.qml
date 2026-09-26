// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   O M N I   R O U T E   M O D U L E                                      │
// │   the gateway · traffic, models, providers, activity, health             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

// The OmniRoute gateway as a window on the gateway itself, drawn from the
// management API rather than from anything local. The chip is the share of
// requests that succeeded — the one number that says "is the routing working"
// — and the detail is five views:
//
//     Traffic    what ran, what it cost, and the shape of the last weeks
//     Models     which model carried the load
//     Providers  which connection answered, and which is unwell
//     Activity   the last requests, one line each, live
//     Server     the process, its cache, its storage, its keys
//
// Everything here comes off the endpoint: nothing is counted on this machine,
// so the widget says the same thing wherever the shell is running.
Item {
    id: root

    property bool compact: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Component.onCompleted: OmniRouteService.subscribe()
    Component.onDestruction: OmniRouteService.release()

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    readonly property var views: [
        { id: "traffic", label: Tr.t("Traffic") },
        { id: "models", label: Tr.t("Models") },
        { id: "providers", label: Tr.t("Providers") },
        { id: "activity", label: Tr.t("Activity") },
        { id: "server", label: Tr.t("Server") }
    ]

    // ── CHIP ────────────────────────────────────────────────────────────────

    Component {
        id: chip

        Item {
            RingIndicator {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.capsuleHeight
                height: Theme.capsuleHeight
                thickness: 2.5
                progress: OmniRouteService.quality
                trackColor: Theme.indicatorDim
                fillColor: OmniRouteService.tone

                Behavior on fillColor { ColorAnimation { duration: Theme.durationMedium } }

                Text {
                    anchors.centerIn: parent
                    text: "󰚩"
                    font.family: Theme.fontMono
                    font.pixelSize: Math.round(Theme.capsuleHeight * 0.42)
                    color: OmniRouteService.tone
                }
            }
        }
    }

    // ── PIECES THE VIEWS SHARE ──────────────────────────────────────────────

    // A metric as the island draws them: a caption, the figure, and a note.
    component Metric: ColumnLayout {
        property string caption: ""
        property string figure: ""
        property string note: ""
        property color tint: Theme.text

        spacing: 1

        Text {
            text: parent.caption.toUpperCase()
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabel
            font.weight: Font.DemiBold
            color: Theme.textMuted
        }

        Text {
            text: parent.figure
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.DemiBold
            color: parent.tint
        }

        Text {
            text: parent.note
            visible: parent.note !== ""
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabel
            color: Theme.textMuted
        }
    }

    // A rounded panel: the box the trend and the tables sit in.
    component Panel: Rectangle {
        default property alias content: slot.data

        radius: Theme.radiusMedium
        color: Theme.islandSurface
        border.color: Theme.islandBorder
        border.width: 1

        Item {
            id: slot
            anchors.fill: parent
            anchors.margins: 8
        }
    }

    // ── TRAFFIC ─────────────────────────────────────────────────────────────

    component TrafficView: Item {
        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: Tr.t("Traffic")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                Item { Layout.fillWidth: true }

                SegmentedControl {
                    options: [
                        { id: "day", label: Tr.t("Day") },
                        { id: "week", label: Tr.t("Week") },
                        { id: "month", label: Tr.t("Month") }
                    ]
                    current: OmniRouteService.range
                    onSelected: id => OmniRouteService.setRange(id)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                RingIndicator {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    thickness: 3.5
                    progress: OmniRouteService.quality
                    trackColor: Theme.indicatorDim
                    fillColor: OmniRouteService.tone

                    Behavior on fillColor { ColorAnimation { duration: Theme.durationMedium } }

                    Column {
                        anchors.centerIn: parent
                        spacing: -1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: OmniRouteService.available
                                ? `${Math.round(OmniRouteService.success)}%` : "—"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Tr.t("success")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.textMuted
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 8

                    Metric {
                        Layout.fillWidth: true
                        caption: Tr.t("Requests")
                        figure: OmniRouteService.available
                            ? OmniRouteService.compact(OmniRouteService.requests) : "—"
                        note: OmniRouteService.available
                            ? `${OmniRouteService.summary?.successful ?? 0} ${Tr.t("answered")}` : ""
                    }

                    Metric {
                        Layout.fillWidth: true
                        caption: Tr.t("Tokens")
                        figure: OmniRouteService.available
                            ? OmniRouteService.compact(OmniRouteService.tokens) : "—"
                        note: OmniRouteService.available
                            ? `${OmniRouteService.modelCount} ${Tr.t("models")} · ${OmniRouteService.accounts.length} ${Tr.t("accounts")}` : ""
                    }

                    Metric {
                        Layout.fillWidth: true
                        caption: Tr.t("Spent")
                        figure: OmniRouteService.available
                            ? OmniRouteService.money(OmniRouteService.cost) : "—"
                        note: OmniRouteService.history
                            ? `${OmniRouteService.money(OmniRouteService.history.cost)} ${Tr.t("all time")}` : ""
                        tint: Theme.accent
                    }

                    Metric {
                        Layout.fillWidth: true
                        caption: Tr.t("Latency")
                        figure: OmniRouteService.available
                            ? OmniRouteService.seconds(OmniRouteService.latency) : "—"
                        note: OmniRouteService.telemetry && OmniRouteService.telemetry.p95 > 0
                            ? `p95 ${OmniRouteService.seconds(OmniRouteService.telemetry.p95)}`
                            : (OmniRouteService.available
                                ? `${Math.round(OmniRouteService.coverage)}% ${Tr.t("as asked")}` : "")
                    }
                }
            }

            // The trend: tokens a bucket, oldest on the left.
            Panel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 44

                Sparkline {
                    anchors.fill: parent
                    anchors.topMargin: 6
                    anchors.bottomMargin: 16
                    visible: OmniRouteService.trend.length > 1
                    values: OmniRouteService.trendTokens
                    maximum: 0
                    stroke: OmniRouteService.tone
                }

                Text {
                    anchors.centerIn: parent
                    visible: OmniRouteService.trend.length <= 1
                    text: Tr.t("not enough history yet")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom

                    Text {
                        width: parent.width / 2
                        text: OmniRouteService.trend.length > 0
                            ? OmniRouteService.trend[0].date : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }

                    Text {
                        width: parent.width / 2
                        horizontalAlignment: Text.AlignRight
                        text: OmniRouteService.trend.length > 1
                            ? OmniRouteService.trend[OmniRouteService.trend.length - 1].date : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }
            }

            // The week as seven bars, and the footer line.
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4

                    Repeater {
                        model: ScriptModel {
                            values: OmniRouteService.weekly
                            objectProp: "day"
                        }

                        Column {
                            id: dayBar

                            required property var modelData
                            readonly property real share: dayBar.modelData.tokens
                                / Math.max(1, OmniRouteService.weekMaxTokens)

                            spacing: 2

                            Rectangle {
                                width: 8
                                height: Math.max(2, 26 * dayBar.share)
                                radius: 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: dayBar.share > 0 ? OmniRouteService.tone : Theme.islandBorder
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: dayBar.modelData.day.slice(0, 1)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: Theme.textMuted
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: {
                        if (!OmniRouteService.available)
                            return ""
                        const streak = OmniRouteService.streak
                        const tier = OmniRouteService.tiers[0]
                        const parts = [`${streak} ${Tr.t("day streak")}`]
                        if (tier && tier.tier !== "")
                            parts.push(`${tier.tier} ${OmniRouteService.money(tier.cost)}`)
                        return parts.join(" · ")
                    }
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }
            }
        }
    }

    // ── MODELS ──────────────────────────────────────────────────────────────

    component ModelsView: Item {
        id: models

        property string open: ""

        ListView {
            anchors.fill: parent
            clip: true
            spacing: 4
            model: ScriptModel {
                values: OmniRouteService.models
                objectProp: "model"
            }
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row

                required property var modelData
                readonly property bool expanded: models.open === row.modelData.model
                readonly property real share: row.modelData.tokens
                    / Math.max(1, OmniRouteService.busiestTokens)

                width: ListView.view.width
                height: row.expanded ? 86 : 46
                radius: Theme.radiusMedium
                color: rowMouse.containsMouse || row.expanded
                    ? Theme.islandSurfaceHover : Theme.islandSurface
                border.color: row.expanded ? Theme.accent : Theme.islandBorder
                border.width: 1
                clip: true

                Behavior on height {
                    NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                }

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 6
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: row.modelData.provider
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.accent
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.model
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            text: OmniRouteService.compact(row.modelData.tokens)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.text
                        }

                        Text {
                            text: OmniRouteService.money(row.modelData.cost)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.textMuted
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 3
                        radius: 1.5
                        color: Theme.islandBorder

                        Rectangle {
                            width: parent.width * Math.max(0.02, Math.min(1, row.share))
                            height: parent.height
                            radius: parent.radius
                            color: OmniRouteService.tone
                        }
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.bottomMargin: 6
                    visible: row.expanded
                    spacing: 14

                    Text {
                        text: `${row.modelData.requests} ${Tr.t("requests")}`
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }

                    Text {
                        text: `${Tr.t("in")} ${OmniRouteService.compact(row.modelData.promptTokens)} · ${Tr.t("out")} ${OmniRouteService.compact(row.modelData.completionTokens)}`
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }

                    Text {
                        text: `${OmniRouteService.seconds(row.modelData.latency)} · ${Math.round(row.modelData.success)}%`
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: models.open = row.expanded ? "" : row.modelData.model
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: OmniRouteService.models.length === 0
            text: Tr.t("no models have run yet")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
        }
    }

    // ── PROVIDERS ───────────────────────────────────────────────────────────

    component ProvidersView: Item {
        id: providers

        property string open: ""

        ListView {
            anchors.fill: parent
            clip: true
            spacing: 4
            model: ScriptModel {
                values: OmniRouteService.connections
                objectProp: "id"
            }
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row

                required property var modelData
                readonly property bool expanded: providers.open === row.modelData.id
                readonly property color stateColor: OmniRouteService.connectionColor(row.modelData)
                readonly property var traffic: {
                    const found = OmniRouteService.byProvider.filter(
                        entry => entry.provider === row.modelData.provider)
                    return found.length > 0 ? found[0] : null
                }

                width: ListView.view.width
                height: row.expanded ? 76 : 44
                radius: Theme.radiusMedium
                color: rowMouse.containsMouse || row.expanded
                    ? Theme.islandSurfaceHover : Theme.islandSurface
                border.color: row.expanded ? Theme.accent : Theme.islandBorder
                border.width: 1
                clip: true

                Behavior on height {
                    NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 6
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: row.stateColor
                    }

                    Text {
                        text: row.modelData.provider
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.accent
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.name
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        visible: row.traffic !== null && row.traffic.tokens > 0
                        text: row.traffic !== null
                            ? `${OmniRouteService.compact(row.traffic.tokens)} · ${Math.round(row.traffic.success)}%`
                            : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }

                    Text {
                        text: row.modelData.status
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: row.stateColor
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 26
                    anchors.rightMargin: 10
                    anchors.bottomMargin: 6
                    visible: row.expanded
                    elide: Text.ElideRight
                    text: row.modelData.lastError !== ""
                        ? row.modelData.lastError
                        : (row.modelData.proxy ? Tr.t("through a proxy") : Tr.t("direct"))
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: providers.open = row.expanded ? "" : row.modelData.id
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: OmniRouteService.connections.length === 0
            text: Tr.t("no provider connections")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
        }
    }

    // ── ACTIVITY ────────────────────────────────────────────────────────────

    component ActivityView: Item {
        id: activity

        property string open: ""

        ListView {
            anchors.fill: parent
            clip: true
            spacing: 3
            model: ScriptModel {
                values: OmniRouteService.callLogs
                objectProp: "id"
            }
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row

                required property var modelData
                readonly property bool expanded: activity.open === row.modelData.id
                readonly property bool failed: row.modelData.status >= 400

                width: ListView.view.width
                height: row.expanded ? 78 : 40
                radius: Theme.radiusMedium
                color: rowMouse.containsMouse || row.expanded
                    ? Theme.islandSurfaceHover : Theme.islandSurface
                border.color: row.expanded ? Theme.accent : Theme.islandBorder
                border.width: 1
                clip: true

                Behavior on height {
                    NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: row.expanded ? 6 : 10
                    spacing: 8

                    // The status, as a dot and the code itself.
                    Text {
                        text: `${row.modelData.status}`
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        font.weight: Font.DemiBold
                        color: OmniRouteService.statusColor(row.modelData.status)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.model || row.modelData.provider
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }

                    Text {
                        visible: row.modelData.combo !== ""
                        text: `⌁ ${row.modelData.combo}`
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.accent
                    }

                    Text {
                        text: row.modelData.duration > 0
                            ? OmniRouteService.seconds(row.modelData.duration) : "—"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }

                    Text {
                        text: row.modelData.input + row.modelData.output > 0
                            ? OmniRouteService.compact(row.modelData.input + row.modelData.output)
                            : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }

                    Text {
                        text: OmniRouteService.isoAgo(row.modelData.time)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }

                // The line only the expanded row has room for.
                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.bottomMargin: 6
                    visible: row.expanded
                    elide: Text.ElideRight
                    text: row.failed && row.modelData.error !== ""
                        ? row.modelData.error
                        : [row.modelData.provider, row.modelData.account,
                            row.modelData.key].filter(part => part !== "").join(" · ")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: row.failed && row.modelData.error !== ""
                        ? OmniRouteService.statusColor(row.modelData.status)
                        : Theme.textMuted
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: activity.open = row.expanded ? "" : row.modelData.id
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: OmniRouteService.callLogs.length === 0
            text: Tr.t("no requests logged yet")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
        }
    }

    // ── SERVER ──────────────────────────────────────────────────────────────

    component ServerView: Item {
        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: OmniRouteService.health?.status ?? "—"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: OmniRouteService.available ? OmniRouteService.tone : Theme.textMuted
                    }

                    Text {
                        text: `uptime ${OmniRouteService.duration(OmniRouteService.health?.uptime ?? 0)}`
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: `${OmniRouteService.health?.connections ?? 0}`
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        text: Tr.t("live connections")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: OmniRouteService.bytes(OmniRouteService.health?.memoryRss ?? 0)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        text: Tr.t("resident memory")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 10
                rowSpacing: 8

                Metric {
                    Layout.fillWidth: true
                    caption: Tr.t("Latency")
                    figure: OmniRouteService.telemetry && OmniRouteService.telemetry.p50 > 0
                        ? OmniRouteService.seconds(OmniRouteService.telemetry.p50)
                        : OmniRouteService.seconds(OmniRouteService.latency)
                    note: `p99 ${OmniRouteService.seconds(OmniRouteService.telemetry?.p99 ?? 0)}`
                }

                Metric {
                    Layout.fillWidth: true
                    caption: Tr.t("Errors")
                    figure: `${OmniRouteService.telemetry?.errorRate ?? 0}%`
                    note: `${OmniRouteService.telemetry?.requests ?? 0} ${Tr.t("sampled")}`
                }

                Metric {
                    Layout.fillWidth: true
                    caption: Tr.t("Sessions")
                    figure: `${OmniRouteService.telemetry?.sessions ?? 0}`
                    note: `${OmniRouteService.telemetry?.quotaExhausted ?? 0} ${Tr.t("exhausted")}`
                }

                Metric {
                    Layout.fillWidth: true
                    caption: Tr.t("Cache")
                    figure: `${OmniRouteService.cache?.size ?? 0}/${OmniRouteService.cache?.maxSize ?? 0}`
                    note: `${Math.round(OmniRouteService.cache?.hitRate ?? 0)}% ${Tr.t("hit rate")}`
                }

                Metric {
                    Layout.fillWidth: true
                    caption: Tr.t("Storage")
                    figure: OmniRouteService.bytes(OmniRouteService.storage?.size ?? 0)
                    note: `${OmniRouteService.storage?.backups ?? 0} ${Tr.t("backups")}`
                }

                Metric {
                    Layout.fillWidth: true
                    caption: Tr.t("Keys")
                    figure: `${OmniRouteService.keys.filter(key => key.active).length}/${OmniRouteService.keys.length}`
                    note: `${OmniRouteService.combos.length} ${Tr.t("combos")}`
                }
            }

            Panel {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 3

                    Text {
                        text: Tr.t("Pacing")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        font.weight: Font.DemiBold
                        color: Theme.textMuted
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Metric {
                            Layout.fillWidth: true
                            caption: Tr.t("Per minute")
                            figure: `${OmniRouteService.resilience?.rpm ?? 0}`
                            note: Tr.t("requests")
                        }

                        Metric {
                            Layout.fillWidth: true
                            caption: Tr.t("Concurrent")
                            figure: `${OmniRouteService.resilience?.concurrent ?? 0}`
                            note: `${OmniRouteService.resilience?.minGap ?? 0} ms ${Tr.t("gap")}`
                        }

                        Metric {
                            Layout.fillWidth: true
                            caption: Tr.t("Breakers")
                            figure: `${OmniRouteService.health?.breakerOpen ?? 0} ${Tr.t("open")}`
                            note: `${OmniRouteService.health?.breakerClosed ?? 0} ${Tr.t("closed")}`
                        }
                    }

                    // The most recently used key, and what it may do.
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: {
                            const used = OmniRouteService.keys.filter(key => key.lastUsed)
                                .sort((a, b) => Date.parse(b.lastUsed) - Date.parse(a.lastUsed))
                            if (used.length === 0)
                                return ""
                            const key = used[0]
                            return `${key.name} · used ${OmniRouteService.isoAgo(key.lastUsed)}`
                                + (key.scopes.length > 0 ? ` · ${key.scopes.join(", ")}` : "")
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }
            }
        }
    }

    // ── THE DETAIL ──────────────────────────────────────────────────────────

    Component {
        id: detail

        Item {
            id: detailFace

            property string view: "traffic"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "󰚩"
                        font.family: Theme.fontMono
                        font.pixelSize: 20
                        color: OmniRouteService.tone
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: OmniRouteService.available
                                && OmniRouteService.health?.version !== ""
                                ? `OmniRoute ${OmniRouteService.health?.version ?? ""}`
                                : "OmniRoute"
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            Layout.fillWidth: true
                            text: OmniRouteService.available
                                ? `${OmniRouteService.host} · ${OmniRouteService.ago(OmniRouteService.fetchedAt)}`
                                : OmniRouteService.statusNote
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            color: OmniRouteService.available ? Theme.textMuted : Theme.indicatorWarn
                        }
                    }

                    IconButton {
                        icon: "󰑐"
                        iconSize: 14
                        enabled: !OmniRouteService.loading
                        onClicked: {
                            OmniRouteService.refresh()
                            spin.restart()
                        }

                        RotationAnimator on rotation {
                            id: spin
                            from: 0
                            to: 360
                            duration: 700
                            loops: 1
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                SegmentedControl {
                    Layout.alignment: Qt.AlignHCenter
                    options: root.views
                    current: detailFace.view
                    onSelected: id => detailFace.view = id
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    TrafficView {
                        anchors.fill: parent
                        visible: detailFace.view === "traffic"
                    }

                    ModelsView {
                        anchors.fill: parent
                        visible: detailFace.view === "models"
                    }

                    ProvidersView {
                        anchors.fill: parent
                        visible: detailFace.view === "providers"
                    }

                    ActivityView {
                        anchors.fill: parent
                        visible: detailFace.view === "activity"
                    }

                    ServerView {
                        anchors.fill: parent
                        visible: detailFace.view === "server"
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 20
                        visible: !OmniRouteService.available
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: OmniRouteService.statusNote
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }
            }
        }
    }
}
