// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B L U E T O O T H   M O D U L E                                        │
// │   bluetooth · connected device, its charge, radio switch when open       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"
import "../widgets"

// The chip names the connected device, so audio that fell back to the
// speakers is visible at a glance, and its ring is the device's charge —
// the same gauge the battery widget draws, for the headset rather than the
// laptop. Pairing is not supported (no PIN agent); the device list is in the
// control centre.
Item {
    id: root

    property bool compact: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    // Ring face; `ChipFace` draws the device's name beside it.
    Component {
        id: chip

        Item {
            BluetoothWidget {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.capsuleHeight
            }
        }
    }

    Component {
        id: detail

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 13

                // The connected device's charge, or the radio's glyph when
                // nothing reports one.
                BluetoothWidget {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    size: 44
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: BluetoothService.summary
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!BluetoothService.enabled)
                                return "Adapter off"
                            if (BluetoothService.hasDeviceBattery)
                                return `${BluetoothService.deviceBattery.name} · ${BluetoothService.deviceBatteryPercent}%`
                            const count = BluetoothService.connectedDevices.length
                            if (count === 0)
                                return "On · nothing connected"
                            return count === 1
                                ? "On · 1 device connected"
                                : `On · ${count} devices connected`
                        }
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: BluetoothService.hasDeviceBattery
                            ? BluetoothService.deviceTint : Theme.textMuted
                    }
                }

                // The figure, so the charge reads at a glance beside the ring.
                Text {
                    visible: BluetoothService.hasDeviceBattery
                    text: `${BluetoothService.deviceBatteryPercent}%`
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: BluetoothService.deviceTint
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Figure {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: "DEVICES"
                    value: `${BluetoothService.connectedDevices.length}`
                    note: BluetoothService.hasDeviceBattery
                        ? "charge shown above"
                        : "pairing lives in the control centre"
                }

                PillButton {
                    Layout.alignment: Qt.AlignVCenter
                    text: "Bluetooth"
                    active: BluetoothService.enabled
                    implicitHeight: 28
                    onClicked: BluetoothService.toggle()
                }
            }
        }
    }
}
