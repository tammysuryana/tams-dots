import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

QuickToggleButton {
    id: root
    toggled: !(Audio.source?.audio?.muted ?? true)
    buttonIcon: toggled ? "mic" : "mic_off"
    onClicked: {
        Audio.toggleMicMute()
    }
    StyledToolTip {
        text: Translation.tr("%1 | Right-click to choose device").arg(Audio.source ? Audio.friendlyDeviceName(Audio.source) : Translation.tr("Microphone"))
    }
}
