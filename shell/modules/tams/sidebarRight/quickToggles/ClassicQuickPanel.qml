import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

import qs.modules.tams.sidebarRight.quickToggles.classicStyle

AbstractQuickPanel {
    id: root
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: buttonGroup.implicitWidth
    implicitHeight: buttonGroup.implicitHeight
    // Latar modul selebar sidebar, tombol di tengah (ala Control Center)
    radius: 18
    color: Appearance.colors.colLayer1

    ButtonGroup {
        id: buttonGroup
        anchors.centerIn: parent
        spacing: 10
        padding: 12
        color: "transparent"

        NetworkToggle {
            altAction: () => {
                root.openWifiDialog();
            }
        }
        BluetoothToggle {
            altAction: () => {
                root.openBluetoothDialog();
            }
        }
        AudioOutputToggle {
            altAction: () => {
                root.openAudioOutputDialog();
            }
        }
        MicToggle {
            altAction: () => {
                root.openAudioInputDialog();
            }
        }
        NightLight {}
        LiveWallpaperToggle {}
        GameMode {}
        IdleInhibitor {}
        EasyEffectsToggle {}
        CloudflareWarp {}
    }
}
