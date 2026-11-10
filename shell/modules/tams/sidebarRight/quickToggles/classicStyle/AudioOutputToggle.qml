import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

QuickToggleButton {
    id: root
    toggled: !(Audio.sink?.audio?.muted ?? true)
    buttonIcon: toggled ? "volume_up" : "volume_off"
    onClicked: {
        Audio.toggleMute()
    }
    StyledToolTip {
        text: Translation.tr("%1 | Right-click to choose device").arg(Audio.sink ? Audio.friendlyDeviceName(Audio.sink) : Translation.tr("Sound"))
    }
}
