// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C   O   D   I   N   G       F   A   C   E                              │
// │   the practice wall as an object · analogue                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"
import "../../../services"
import "../../../components"

// The practice wall, with embossed tiles instead of flat ones, and no caption
// or frame. As in the Modern face the cell size is fixed and the width decides
// how many weeks fit; the bevels derive from each cell's colour, so `ink` is
// only here to match the registry's interface.
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
        raised: true
    }

    // Says why the wall is empty, as the Modern face does.
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
