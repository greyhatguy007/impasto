// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B   A   T   T   E   R   Y       F   A   C   E                          │
// │   the charge as a cell that fills · red when it is running low           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// A battery cell filled to the charge, with a bolt while charging. The fill
// takes the fixed battery red when the charge is low. A Bluetooth device's
// charge rides the reading when it is the one about to run out.
Instrument {
    id: face

    line: BatteryService.available || BatteryService.hasDeviceBattery
        ? `${BatteryService.level}% · ${BatteryService.levelIsDevice
            ? BatteryService.deviceBatteryName : BatteryService.estimate}`
        : "No battery"
    reading: BatteryService.available || BatteryService.hasDeviceBattery
        ? `${BatteryService.level}%` : "—"
    note: !BatteryService.available && !BatteryService.hasDeviceBattery ? "no battery"
        : BatteryService.levelIsDevice
        ? `${BatteryService.deviceBatteryName} · bluetooth`
        : BatteryService.estimate

    BatteryCell {
        anchors.centerIn: parent
        ink: face.ink
        size: Math.min(parent.width, parent.height / 0.48)
        fraction: BatteryService.level / 100
        charging: BatteryService.charging || BatteryService.full
        fill: BatteryService.levelLow ? BatteryService.tint : face.ink.text
    }

    WheelSetter {
        anchors.fill: parent
        onUp: BrightnessService.step(2)
        onDown: BrightnessService.step(-2)
    }
}
