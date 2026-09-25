// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C   O   D   I   N   G       F   A   C   E                              │
// │   the activity wall on the wallpaper · modern                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../../components"

// The activity wall and nothing else, with no caption or logo; the count is
// in the island's detail and on the bar chip.
//
// GitHub, LeetCode, Codeforces and GitLab added together by default, or whichever one
// the toggle is showing, in that platform's own ramp. Hover the wall for the
// toggle, so the platform can be changed without leaving the wallpaper.
//
// The cell size is fixed (ContributionGrid derives it from the height, which
// the families share), so a wider face shows more weeks rather than smaller
// cells.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property string family: "2x2"

    ContributionGrid {
        anchors.fill: parent
        anchors.margins: 12
        visible: CodingService.available

        weeks: CodingService.weeks
        levels: CodingService.levels
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
            ? Tr.t("No GitHub, LeetCode, Codeforces or GitLab user set")
            : `${CodingService.platformName} is out of reach`
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: root.ink.muted
    }

    // ── SOURCE ──────────────────────────────────────────────────────────────
    //
    // A choice to make only with more than one handle set, and then only
    // while the pointer is on the wall.

    HoverHandler {
        id: hover
    }

    SourcePicker {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        shown: hover.hovered && CodingService.platforms.length > 1
        onSelected: id => CodingService.setPlatform(id)
    }
}
