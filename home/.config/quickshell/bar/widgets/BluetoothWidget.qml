// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B L U E T O O T H   W I D G E T                                        │
// │   device charge as a ring · the level is the outline                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../../components"

// The outline is the charge of the connected Bluetooth device that reports
// one; the glyph says which device it is. The same gauge as `BatteryWidget`,
// but for the headset or mouse rather than the laptop, so the two never share
// a ring.
//
// With no reading the track shows alone and the glyph is the radio's, since
// there is nothing measured to point at.
RingIndicator {
    id: root

    // Smaller inside the island, where the capsule's edge would clip it.
    property real size: Theme.capsuleHeight

    // A desktop face passes its own ink so the ring reads on its background.
    property color glyphColor: Theme.indicator
    property color track: Theme.indicatorDim

    implicitWidth: root.size
    implicitHeight: root.size

    progress: BluetoothService.hasDeviceBattery
        ? BluetoothService.deviceBatteryPercent / 100 : 0
    thickness: 2.5

    trackColor: root.track
    fillColor: BluetoothService.hasDeviceBattery
        ? BluetoothService.deviceTint : root.track

    Behavior on fillColor { ColorAnimation { duration: Theme.durationMedium } }

    Text {
        anchors.centerIn: parent
        text: BluetoothService.hasDeviceBattery
            ? BluetoothService.deviceBatteryIcon : BluetoothService.icon
        font.family: Theme.fontMono
        font.pixelSize: Math.round(root.size * 0.38)
        // The ring carries the level; the glyph only says what is measured.
        color: root.glyphColor
    }
}
