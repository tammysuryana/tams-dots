pragma Singleton
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

/**
 * A nice wrapper for date and time strings.
 */
Singleton {
    id: root

    property alias inhibit: idleInhibitor.enabled
    inhibit: false

    // Singleton is created lazily: if Persistent was already ready by then,
    // onReadyChanged never fires and the saved state would be ignored.
    Component.onCompleted: {
        if (Persistent.ready) root.inhibit = Persistent.states.idle.inhibit;
    }

    Connections {
        target: Persistent
        function onReadyChanged() {
            root.inhibit = Persistent.states.idle.inhibit;
        }
    }

    IpcHandler {
        target: "idle"

        function toggle(): void {
            root.toggleInhibit()
        }

        function status(): string {
            return root.inhibit ? "on" : "off"
        }
    }

    function toggleInhibit(active = null) {
        if (active !== null) {
            root.inhibit = active;
        } else {
            root.inhibit = !root.inhibit;
        }
        Persistent.states.idle.inhibit = root.inhibit;
    }

    IdleInhibitor {
        id: idleInhibitor
        window: PanelWindow {
            // Inhibitor requires a mapped surface: 0x0 never gets mapped by Hyprland,
            // so the inhibitor silently did nothing. 1x1 transparent pixel instead.
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:idleInhibitor"
            // Just in case...
            anchors {
                right: true
                bottom: true
            }
            // Make it not interactable
            mask: Region {
                item: null
            }
        }
    }
}