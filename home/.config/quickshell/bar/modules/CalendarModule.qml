// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C   A   L   E   N   D   A   R       M   O   D   U   L   E              │
// │   date · the month when open                                             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

// The date and its month. Days with tasks due get a dot, and the detail lists
// the tasks for the selected day. Finished tasks stay on their day, struck
// through.
//
// With Google Calendar connected, the day's events are read in beside the
// tasks, and a day with only events on it gets a blue dot.
Item {
    id: root

    // Minute precision is enough to catch midnight.
    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
    }

    readonly property date today: root.clock.date

    // Weeks start on Monday. Cells outside the month stay blank so every date
    // keeps its weekday column.
    readonly property var cells: {
        const year = root.today.getFullYear()
        const month = root.today.getMonth()
        const shift = (new Date(year, month, 1).getDay() + 6) % 7
        const total = new Date(year, month + 1, 0).getDate()
        const list = []
        for (let blank = 0; blank < shift; blank++)
            list.push(0)
        for (let date = 1; date <= total; date++)
            list.push(date)
        while (list.length % 7 !== 0)
            list.push(0)
        return list
    }

    readonly property var weekdays: ["M", "T", "W", "T", "F", "S", "S"]

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: detail
    }

    Component {
        id: detail

        Item {
            id: page

            // Selected day: today unless another was clicked; reset whenever
            // the detail is rebuilt.
            property int picked: 0

            readonly property int day: page.picked > 0 ? page.picked : root.today.getDate()
            readonly property bool onToday: page.day === root.today.getDate()

            function keyOf(date: int): string {
                return TasksService.dayKey(
                    new Date(root.today.getFullYear(), root.today.getMonth(), date))
            }

            readonly property var due: TasksService.on(page.keyOf(page.day))
            readonly property var events: GCalendarService.on(page.keyOf(page.day))

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 6

                Item {
                    width: parent.width
                    height: 18

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(root.clock.date, "MMMM yyyy")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(root.clock.date, "dddd d")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }

                Grid {
                    id: month

                    width: parent.width
                    height: 150
                    columns: 7

                    readonly property real cellWidth: width / 7
                    readonly property real cellHeight: height / 7

                    Repeater {
                        model: root.weekdays

                        Item {
                            required property var modelData

                            width: month.cellWidth
                            height: month.cellHeight

                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                font.weight: Font.DemiBold
                                color: Theme.textMuted
                            }
                        }
                    }

                    Repeater {
                        model: root.cells

                        Item {
                            id: cell

                            required property int modelData

                            readonly property bool today:
                                cell.modelData === root.today.getDate()
                            readonly property bool picked:
                                cell.modelData > 0 && cell.modelData === page.day && !cell.today
                            readonly property string key:
                                cell.modelData > 0 ? page.keyOf(cell.modelData) : ""
                            readonly property int tasks: cell.key !== "" ? TasksService.countOn(cell.key) : 0
                            readonly property int pending: cell.key !== "" ? TasksService.pendingOn(cell.key) : 0
                            readonly property int events: cell.key !== "" ? GCalendarService.on(cell.key).length : 0

                            width: month.cellWidth
                            height: month.cellHeight

                            // Today takes the accent; the selected day gets an
                            // accent ring.
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height) - 2
                                height: width
                                radius: width / 2
                                visible: cell.today || cell.picked
                                color: cell.today ? Theme.accent : "transparent"
                                border.color: Theme.accent
                                border.width: cell.picked ? 1 : 0
                            }

                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: cell.tasks > 0 ? -1 : 0
                                visible: cell.modelData > 0
                                text: `${cell.modelData}`
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                font.weight: cell.today ? Font.DemiBold : Font.Normal
                                color: cell.today ? Theme.accentText : Theme.text
                            }

                            // Tasks due: accent while any is open, muted once
                            // all are done. A day with only events takes blue.
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2
                                visible: cell.tasks > 0 || cell.events > 0
                                width: 3
                                height: 3
                                radius: 1.5
                                color: cell.today ? Theme.accentText
                                    : (cell.tasks > 0
                                        ? (cell.pending > 0 ? Theme.accent : Theme.textMuted)
                                        : Theme.blue)
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: cell.modelData > 0
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.picked = cell.today ? 0 : cell.modelData
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.hairline
                }

                // Tasks due on the selected day: a summary line and up to two
                // rows. Clicking one opens it on the board.
                Column {
                    width: parent.width
                    spacing: 3

                    Text {
                        width: parent.width
                        text: {
                            const name = page.onToday ? "Today"
                                : Qt.formatDate(new Date(root.today.getFullYear(),
                                    root.today.getMonth(), page.day), "dddd d")
                            const n = page.due.length
                            const left = page.due.filter(task => task.state !== "done").length
                            const m = page.events.length
                            const parts = []
                            if (n === 0 && m === 0)
                                return `${name} · nothing on`
                            if (n > 0)
                                parts.push(`${left} of ${n} to do`)
                            if (m > 0)
                                parts.push(`${m} ${m === 1 ? Tr.t("event") : Tr.t("events")}`)
                            return `${name} · ${parts.join(" · ")}`
                        }
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        font.weight: Font.DemiBold
                        color: Theme.textMuted
                    }

                    Repeater {
                        model: ScriptModel {
                            values: page.due.slice(0, 2)
                            objectProp: "key"
                        }

                        Rectangle {
                            id: row

                            required property var modelData

                            readonly property bool done: row.modelData.state === "done"

                            width: parent.width
                            height: 18
                            radius: Theme.radiusSmall - 2
                            color: rowMouse.containsMouse ? Theme.islandSurfaceHover : "transparent"

                            Row {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: TasksService.stateEntry(row.modelData.state).icon
                                    font.family: Theme.fontMono
                                    font.pixelSize: 11
                                    color: row.done ? Theme.green : Theme.accent
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 17
                                    text: row.modelData.text
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.strikeout: row.done
                                    color: row.done ? Theme.textMuted : Theme.text
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    TasksService.open(row.modelData.key)
                                    ModuleService.requestPanel("board")
                                }
                            }
                        }
                    }

                    // The day's events, from Google Calendar when connected.
                    // A running event takes the accent; the rest stay plain.
                    Repeater {
                        model: ScriptModel {
                            values: page.events.slice(0, 2)
                            objectProp: "id"
                        }

                        Item {
                            id: eventRow

                            required property var modelData

                            readonly property bool now: eventRow.modelData.startTime !== ""
                                && eventRow.modelData.day === TasksService.todayKey
                                && eventRow.modelData.startTime <= Qt.formatDateTime(root.clock.date, "HH:mm")
                                && (eventRow.modelData.endTime === ""
                                    || eventRow.modelData.endTime > Qt.formatDateTime(root.clock.date, "HH:mm"))

                            width: parent.width
                            height: 18

                            Row {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: eventRow.modelData.startTime !== ""
                                    text: eventRow.modelData.startTime
                                    font.family: Theme.fontMono
                                    font.pixelSize: 10
                                    color: eventRow.now ? Theme.accent : Theme.textMuted
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - (eventRow.modelData.startTime !== "" ? 46 : 17)
                                    text: eventRow.modelData.title !== ""
                                        ? eventRow.modelData.title : Tr.t("(untitled event)")
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.italic: eventRow.modelData.allDay
                                    color: eventRow.now ? Theme.text : Theme.textMuted
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
