// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S O U R C E   P I C K E R                                              │
// │   all · github · leetcode · codeforces · gitlab                          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"
import "../services"

// Which platform the activity wall is drawn from, as a row of small pills:
// `All` and every platform with a handle, short enough to sit in the corner
// of a desktop widget where the full `SegmentedControl` would not fit. Drawn
// on the island's black so it reads over the wallpaper too.
//
// The bar's detail uses the roomier `SegmentedControl` for the same choice;
// both write the one setting through `CodingService.setPlatform`.
Rectangle {
    id: root

    property string current: CodingService.platform
    property bool shown: false

    signal selected(string id)

    implicitWidth: row.implicitWidth + 10
    implicitHeight: 24
    radius: height / 2
    color: Qt.rgba(Theme.island.r, Theme.island.g, Theme.island.b, 0.88)
    border.color: Theme.islandBorder
    border.width: 1
    opacity: root.shown ? 1 : 0
    visible: opacity > 0

    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 3

        Repeater {
            model: CodingService.platforms

            Rectangle {
                id: pill

                required property var modelData

                readonly property bool active: pill.modelData.id === root.current

                width: label.implicitWidth + 14
                height: 17
                radius: height / 2
                color: pill.active ? Theme.accent
                    : (area.containsMouse ? Theme.islandSurfaceHover : "transparent")

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                Text {
                    id: label

                    anchors.centerIn: parent
                    text: Tr.t(pill.modelData.short)
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                    font.weight: pill.active ? Font.DemiBold : Font.Normal
                    color: pill.active ? Theme.accentText
                        : (area.containsMouse ? Theme.text : Theme.textMuted)
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(pill.modelData.id)
                }
            }
        }
    }
}
