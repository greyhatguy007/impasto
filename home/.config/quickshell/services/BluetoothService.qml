// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B L U E T O O T H   S E R V I C E                                      │
// │   adapter state, what is connected to it, and what its devices report    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

import "../theme"

// The default adapter, flattened for the control centre.
//
// `enabled` on the adapter is writable, so nothing shells out here: the toggle
// is a property assignment and the state comes back over D-Bus.
Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: root.adapter !== null
    readonly property bool enabled: root.available && root.adapter.enabled

    // Everything BlueZ currently knows about, listed or not.
    readonly property var allDevices: {
        if (!root.available || !root.adapter.devices)
            return []
        return root.adapter.devices.values
    }

    readonly property var connectedDevices: root.allDevices.filter(device => device.connected)

    // A single device is named; several are counted.
    readonly property string summary: {
        if (!root.available)
            return "Unavailable"
        if (!root.enabled)
            return "Off"
        const connected = root.connectedDevices
        if (connected.length === 0)
            return "No devices"
        if (connected.length === 1)
            return connected[0].name
        return `${connected.length} devices`
    }

    readonly property string icon: {
        if (!root.available)
            return "󰂲"
        if (!root.enabled)
            return "󰂲"
        return root.connectedDevices.length > 0 ? "󰂱" : "󰂯"
    }

    // ── DEVICE BATTERY ──────────────────────────────────────────────────────
    //
    // The battery of the device that reports one, for the battery widget and
    // the island. Headsets and mice that speak the standard battery service
    // carry `battery` as a 0–1 fraction; the property is present on every
    // device, so a reading is known from the membership of this map, taken
    // when the device list changes.

    // Address → percent, only for devices reporting a battery right now.
    property var batteryMap: ({})

    // Address → percent, kept through a disconnection. BlueZ drops the
    // property the moment a device disconnects, and a headset that does not
    // report again until it is low would otherwise be shown at its last
    // reading only while connected.
    property var lastBattery: ({})

    // How long a device away from the desk still counts as where it was.
    // Covers putting the headset down and walking off with it, not a machine
    // rebooted — the map is in-memory.
    readonly property int memoryMs: 15000

    // `connected` flips false before BlueZ withdraws the battery property on
    // the way down, so the reading is taken off the connected list — a device
    // going away has already been seen here.
    readonly property var batteryDevices: root.allDevices.filter(
        device => device.batteryAvailable && device.connected)

    onBatteryDevicesChanged: root.remember()

    function remember(): void {
        const now = Date.now()
        const current = ({})
        for (const device of root.batteryDevices) {
            const percent = Math.round((device.battery ?? 0) * 100)
            current[device.address] = percent
            root.lastBattery[device.address] = { percent: percent, at: now }
        }
        root.batteryMap = current
        root.batteryExpiry.restart()
    }

    // Bumps when a reading expires, so `deviceBatteries` re-runs. A var
    // assigned to itself would not count as a change.
    property int batteryTick: 0

    // Ages `lastBattery`, so the bar does not promise a headset that left
    // with its charge still showing.
    readonly property Timer batteryExpiry: Timer {
        interval: root.memoryMs + 1000
        repeat: false
        onTriggered: root.batteryTick++
    }

    // Battery readings, connected or just left. Device order, best reading
    // first — with two headsets out, the widget watches the one that will run
    // out first.
    readonly property var deviceBatteries: {
        void root.batteryTick
        const now = Date.now()
        const out = []
        for (const device of root.connectedDevices) {
            const percent = root.batteryMap[device.address]
            if (percent !== undefined)
                out.push({ name: device.name, address: device.address,
                           percent: percent, icon: root.deviceIcon(device) })
        }
        if (out.length === 0) {
            for (const address in root.lastBattery) {
                const entry = root.lastBattery[address]
                if (now - entry.at < root.memoryMs) {
                    const device = root.allDevices.find(known => known.address === address)
                    out.push({ name: device?.name ?? address, address: address,
                               percent: entry.percent,
                               icon: device ? root.deviceIcon(device) : "󰂯" })
                }
            }
        }
        return out.sort((a, b) => a.percent - b.percent)
    }

    // Whether any connected device reports a battery. A binding on
    // `batteryMap` alone would miss the readings going away with the device.
    readonly property bool hasDeviceBattery: root.deviceBatteries.length > 0

    // The weakest connected reading, 0–100.
    readonly property int deviceBatteryPercent: root.hasDeviceBattery
        ? root.deviceBatteries[0].percent : 0

    // The one device's charge the widget draws: weakest first, so the headset
    // about to run out is the one on screen.
    readonly property var deviceBattery: root.hasDeviceBattery
        ? root.deviceBatteries[0] : null

    // Its glyph (the headset, the mouse) rather than the radio's.
    readonly property string deviceBatteryIcon: root.deviceBattery
        ? (root.deviceBattery.icon ?? "󰂯") : "󰂯"

    // Fixed hues, as the battery widget uses: a colour means the same charge
    // whatever the wallpaper.
    readonly property color deviceTint: {
        if (!root.hasDeviceBattery)
            return Theme.indicatorDim
        const percent = root.deviceBatteryPercent
        if (percent <= 15)
            return Theme.indicatorBad
        if (percent <= 35)
            return Theme.indicatorWarn
        return Theme.indicatorGood
    }

    function deviceBatteryName(address: string): string {
        return root.deviceBatteries.find(entry => entry.address === address)?.name ?? ""
    }

    // ── LISTING ─────────────────────────────────────────────────────────────

    // `name` is BlueZ's Alias, which falls back to the MAC address when the
    // device never advertised a name; `deviceName` is empty in that case.
    function isNamed(device: var): bool {
        return ((device.deviceName ?? "") + "").length > 0
    }

    // Named, paired, connected or pairing devices. Paired devices stay listed
    // whatever BlueZ has cached for their name.
    readonly property var devices: {
        const listed = root.allDevices.filter(device => root.isNamed(device)
            || device.paired || device.connected || device.pairing)
        // Connected first, then paired, then whatever else is in range.
        return listed.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            if (a.paired !== b.paired) return a.paired ? -1 : 1
            return (a.name ?? "").localeCompare(b.name ?? "")
        })
    }

    // Everything else, shown in a collapsed second list.
    readonly property var unnamedDevices: {
        const rest = root.allDevices.filter(device => !(root.isNamed(device)
            || device.paired || device.connected || device.pairing))
        return rest.sort((a, b) => (a.address ?? "").localeCompare(b.address ?? ""))
    }

    readonly property int unnamedCount: root.unnamedDevices.length

    readonly property bool discovering: root.available && root.adapter.discovering

    function deviceIcon(device: var): string {
        switch (device.icon) {
        case "audio-headset":
        case "audio-headphones": return "󰋋"
        case "audio-card": return "󰓃"
        case "input-mouse": return "󰍽"
        case "input-keyboard": return "󰌌"
        case "phone": return "󰄜"
        case "computer": return "󰟀"
        default: return "󰂯"
        }
    }

    // ── ACTIONS ─────────────────────────────────────────────────────────────
    //
    // `connected` is writable on the device and unpairing is its `forget()`
    // method; either way the state comes back over D-Bus. Unpairing asks
    // twice: the list flips the row into a confirm state and only the second
    // tap writes.

    function connectDevice(device: var): void {
        if (device)
            device.connected = !device.connected
    }

    function disconnectDevice(device: var): void {
        if (device && device.connected)
            device.connected = false
    }

    function unpairDevice(device: var): void {
        if (device && device.paired)
            device.forget()
        root.confirmForgetting = ""
    }

    // The address waiting for its second tap on the unpair button; "" is none.
    property string confirmForgetting: ""

    function confirmForgetConnection(address: string): void {
        root.confirmForgetting = root.confirmForgetting === address ? "" : address
    }

    function cancelForgetConnection(): void {
        root.confirmForgetting = ""
    }

    function setDiscovering(on: bool): void {
        if (root.available)
            root.adapter.discovering = on
    }

    function toggle(): void {
        if (root.available)
            root.adapter.enabled = !root.adapter.enabled
    }
}
