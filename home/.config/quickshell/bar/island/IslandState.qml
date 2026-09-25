// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I S L A N D   S T A T E                                                │
// │   decides which layer the island is showing                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../services"

// Arbitration for the island, separate from how any layer looks. Layers are
// ranked, and the island shows the highest one that currently wants the
// screen:
//
//     panel         opened by the user      until dismissed
//     notification  something arrived       until it expires or is closed
//     transient     volume, brightness…     shown, then expires
//     pinned        lyrics, pinned          until unpinned
//     summary       the pointer rests on it  until it leaves
//     modules       nothing happening       always available
//
// A notification outranks a transient, which only confirms something the user
// just did. The pinned lyrics sit above the summary, since a pin is a decision
// and a glance is only a rest; a panel or a notification still takes the island
// and the pin comes back when they go. Adding a layer means giving it a rank.
//
// There is one of these per screen, and only the live one arbitrates: an
// island that is not stays at rest, whatever arrives.
QtObject {
    id: root

    // Whether this island is the one being worked on (`Bar.live`). A panel, a
    // notification or an OSD on two screens at once is one thing shown twice,
    // so every layer above rest belongs to the live island alone.
    property bool active: true

    // "transient" on its own is a reserved QML keyword, hence the prefix.
    readonly property string layerModules: "modules"
    readonly property string layerNotification: "notification"
    readonly property string layerOsd: "osd"
    readonly property string layerPanel: "panel"
    readonly property string layerPinned: "pinned"
    readonly property string layerSummary: "summary"

    // How long a transient event holds the island before it falls away.
    readonly property int transientDuration: 1800

    property bool transientActive: false

    property string transientIcon: ""
    property string transientLabel: ""
    property real transientProgress: -1

    // Set by the island when the user opens a panel; "" means none.
    property string openPanel: ""

    // Set by the island while the pointer has rested on it long enough.
    property bool summary: false

    // Set while the user wants the lyrics pinned. Not cleared by anything but
    // an unpick or the setting going off, so the pin survives a pause, a
    // panel, a notification and the island moving between screens.
    property bool pinned: false

    readonly property string layer: {
        if (!root.active)
            return root.layerModules
        if (root.openPanel !== "")
            return root.layerPanel
        if (NotificationService.active)
            return root.layerNotification
        if (root.transientActive)
            return root.layerOsd
        if (root.pinned)
            return root.layerPinned
        if (root.summary)
            return root.layerSummary
        return root.layerModules
    }

    readonly property bool expanded: root.openPanel !== ""

    // Handing the island to another screen puts this one back to rest at once:
    // the layer is already forced above, and what is left is the state behind
    // it, which would otherwise come back when the island returned.
    onActiveChanged: {
        if (root.active)
            return
        root.openPanel = ""
        root.summary = false
        root.transientActive = false
        root.expiry.stop()
    }

    readonly property Timer expiry: Timer {
        interval: root.transientDuration
        onTriggered: root.transientActive = false
    }

    // A transient event arriving while a panel is open is dropped rather than
    // queued: by the time the panel closes the value would be stale, and
    // showing it then would look like a ghost.
    readonly property Connections osd: Connections {
        target: OsdService
        enabled: root.active

        function onRequested(icon: string, label: string, progress: real): void {
            if (root.openPanel !== "")
                return
            root.transientIcon = icon
            root.transientLabel = label
            root.transientProgress = progress
            root.transientActive = true
            root.expiry.restart()
        }
    }

    function open(panel: string): void {
        if (!root.active)
            return
        // A panel takes over immediately; whatever was flashing is now noise.
        root.transientActive = false
        root.expiry.stop()
        // The notification goes too, without being marked as acted on: opening
        // a panel is not the same as answering what was on screen.
        NotificationService.dismiss()
        root.summary = false
        root.openPanel = panel
    }

    // The pin from the lyric line's own chip, from the mark on the resting
    // clock or from the glance. A pin without a player is refused: the line
    // has nothing to show. A paused track is fine — the line sits where it
    // was left.
    function setPinned(on: bool): void {
        if (on && !MediaService.available)
            return
        root.pinned = on
    }

    // The setting going off takes the pin with it, so the clock is back at
    // once; turning it on again waits for the next pin.
    readonly property Connections setting: Connections {
        target: SettingsService

        function onIslandLyricsChanged(): void {
            if (!SettingsService.islandLyrics)
                root.pinned = false
        }
    }

    function close(): void {
        root.openPanel = ""
    }
}
