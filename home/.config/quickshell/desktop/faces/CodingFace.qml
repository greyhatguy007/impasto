// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C   O   D   I   N   G       F   A   C   E                              │
// │   the practice wall on the wallpaper · modern                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../../components"

// The practice wall and nothing else, with no caption or logo; the count and
// the streak are in the island's detail. The same drawing as the GitHub face,
// in the platform's own ramp: LeetCode's amber or Codeforces' blue.
//
// The cell size is fixed (ContributionGrid derives it from the height, which
// the families share), so a wider face shows more weeks rather than smaller
// cells.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property string family: "2x2"

    readonly property var levels: CodingService.platform === "codeforces"
        ? Theme.codeforcesLevels : Theme.leetcodeLevels

    ContributionGrid {
        anchors.fill: parent
        anchors.margins: 12
        visible: CodingService.available

        weeks: CodingService.weeks
        levels: root.levels
        spacing: 3
        radius: 2.5
        maxCell: 24
    }

    // Says why the wall is empty: no handle set, or the platform out of reach.
    Text {
        anchors.centerIn: parent
        width: parent.width - 24
        visible: !CodingService.available
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: CodingService.configured.length === 0
            ? "No LeetCode or Codeforces user set"
            : `${CodingService.platformName} is out of reach`
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: root.ink.muted
    }
}
