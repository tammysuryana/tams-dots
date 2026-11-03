import QtQuick
import Quickshell

import qs
import qs.modules.common
import qs.modules.tams.background
import qs.modules.tams.bar
import qs.modules.tams.dock
import qs.modules.tams.equalizer
import qs.modules.tams.lock
import qs.modules.tams.mediaControls
import qs.modules.tams.notificationPopup
import qs.modules.tams.onScreenDisplay
import qs.modules.tams.onScreenKeyboard
import qs.modules.tams.overview
import qs.modules.tams.polkit
import qs.modules.tams.settings
import qs.modules.tams.regionSelector
import qs.modules.tams.screenCorners
import qs.modules.tams.screenTranslator
import qs.modules.tams.sessionScreen
import qs.modules.tams.sidebarLeft
import qs.modules.tams.sidebarRight
import qs.modules.tams.overlay
import qs.modules.tams.verticalBar
import qs.modules.tams.wallpaperSelector
import qs.modules.tams.desktopMenu
import qs.modules.tams.dropover
import qs.modules.tams.frame

Scope {
    PanelLoader { extraCondition: !Config.options.bar.vertical; component: Bar {} }
    PanelLoader { component: Background {} }
    PanelLoader { extraCondition: Config.options.dock.enable; component: Dock {} }
    PanelLoader { component: EqualizerPopup {} }
    PanelLoader { component: Lock {} }
    PanelLoader { component: MediaControls {} }
    PanelLoader { component: NotificationPopup {} }
    PanelLoader { component: OnScreenDisplay {} }
    PanelLoader { component: OnScreenKeyboard {} }
    PanelLoader { component: Overlay {} }
    PanelLoader { component: Overview {} }
    PanelLoader { component: Polkit {} }
    PanelLoader { component: RegionSelector {} }
    PanelLoader { component: ScreenCorners {} }
    PanelLoader { component: ScreenTranslator {} }
    PanelLoader { component: SessionScreen {} }
    PanelLoader { component: SidebarLeft {} }
    PanelLoader { component: SidebarRight {} }
    PanelLoader { extraCondition: Config.options.bar.vertical; component: VerticalBar {} }
    PanelLoader { component: WallpaperSelector {} }
    PanelLoader { component: Settings {} }
    PanelLoader { component: DesktopMenu {} }
    PanelLoader { extraCondition: GlobalStates.dropShelfOpen; component: DropShelfPanel {} }
    PanelLoader { component: NiriBackdrop {} }
    PanelLoader { component: ScreenFrame {} }
}
