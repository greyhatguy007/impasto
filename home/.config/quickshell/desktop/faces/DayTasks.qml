// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D A Y   T A S K S                                                      │
// │   one day's tasks                                                        │
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

// A calendar widget's day view, in every family and both themes: the day, how
// much of it is left, and every task on it, scrolling if needed — with the
// day's Google Calendar events beneath when the day has any. The parent face
// decides when to show it and restores the month through `back` or when the
// pointer leaves.
//
// `ink` is TaskRow's; `rule` colours the line under the header.
Item {
    id: root

    property string day: ""
    property var ink: ({
        text: Theme.text, muted: Theme.textMuted, accent: Theme.accent,
        accentText: Theme.accentText, raised: Theme.islandSurfaceHover,
        red: Theme.red, rule: Theme.hairline
    })

    // False where the face already shows the day (the analogue ribbon); the
    // header is then only the arrow and the count.
    property bool titled: true

    signal back()

    // The day last shown, kept through the fade-out: `day` is cleared at once,
    // and an emptied list would flash "0 of 0".
    property string shown: ""
    onDayChanged: {
        if (root.day !== "")
            root.shown = root.day
    }

    readonly property var due: root.shown !== "" ? TasksService.on(root.shown) : []
    readonly property int pending: root.due.filter(task => task.state !== "done").length
    readonly property string count: `${root.pending} of ${root.due.length} to do`

    // The day's events, from Google Calendar when connected.
    readonly property var events: root.shown !== "" ? GCalendarService.on(root.shown) : []

    // Too narrow for the day and the count on one line.
    readonly property bool narrow: root.titled && root.width < 240

    ColumnLayout {
        anchors.fill: parent
        spacing: root.narrow ? 6 : 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "󰅁"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeMedium
                color: root.ink.muted

                HoverHandler { cursorShape: Qt.PointingHandCursor }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.back()
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.titled
                text: root.shown === "" ? ""
                    : Qt.formatDate(TasksService.dateOf(root.shown), "dddd d")
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.DemiBold
                color: root.ink.text
            }

            Text {
                Layout.fillWidth: !root.titled
                visible: !root.narrow
                text: root.count
                horizontalAlignment: root.titled ? Text.AlignRight : Text.AlignLeft
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: root.titled ? Font.Normal : Font.DemiBold
                color: root.ink.muted
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.narrow
            text: root.count
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: root.ink.muted
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: root.ink.rule
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel {
                values: root.due
                objectProp: "key"
            }

            delegate: TaskRow {
                required property var modelData

                width: ListView.view.width
                task: modelData
                dated: false
                ink: root.ink
                onOpened: {
                    TasksService.open(modelData.key)
                    ModuleService.requestPanel("board")
                }
            }
        }

        // The day's events, under the tasks. A running event takes the
        // accent; an all-day one is italic and carries no time. The list is
        // capped so a long day cannot push the tasks out of view.
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.events.length > 0
            spacing: 3

            Text {
                Layout.fillWidth: true
                text: root.events.length === 1
                    ? Tr.t("1 event") : `${root.events.length} ${Tr.t("events")}`
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.weight: Font.DemiBold
                color: root.ink.muted
            }

            ListView {
                id: eventList

                readonly property bool now: Qt.formatDateTime(clock.date, "HH:mm")

                // Minutes catch an event beginning or ending.
                SystemClock {
                    id: clock
                    precision: SystemClock.Minutes
                }

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 96)
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                model: ScriptModel {
                    values: root.events
                    objectProp: "id"
                }

                delegate: Item {
                    id: eventRow

                    required property var modelData

                    readonly property bool live: eventRow.modelData.startTime !== ""
                        && eventRow.modelData.day === TasksService.todayKey
                        && eventRow.modelData.startTime <= eventList.now
                        && (eventRow.modelData.endTime === ""
                            || eventRow.modelData.endTime > eventList.now)

                    width: eventList.width
                    height: 18

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: eventRow.modelData.startTime !== ""
                            text: eventRow.modelData.startTime
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            color: eventRow.live ? root.ink.accent : root.ink.muted
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                                - (eventRow.modelData.startTime !== "" ? 40 : 0)
                            text: eventRow.modelData.title !== ""
                                ? eventRow.modelData.title : Tr.t("(untitled event)")
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.italic: eventRow.modelData.allDay
                            color: eventRow.live ? root.ink.text : root.ink.muted
                        }
                    }
                }
            }
        }
    }
}
