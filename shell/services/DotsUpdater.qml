pragma Singleton

import qs
import QtQuick
import Quickshell

Singleton {
    id: root

    function runSystemUpdate() {
        Quickshell.execDetached([
            "kitty", "--hold",
            "fish", "-i", "-l", "-c",
            "yay -Syu --combinedupgrade=false"
        ])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }

    function runUpdateDots() {
        // Tarik versi terbaru tams-dots lalu pasang ulang bagian shell saja (pengaturan pribadi tidak disentuh).
        // Lokasi repo dicatat installer di ~/.config/tams-dots/repo-path.
        const updateScript = `
            set -e
            REPO="$(cat "$HOME/.config/tams-dots/repo-path" 2>/dev/null || echo "$HOME/tams-dots")"
            if [ ! -d "$REPO/.git" ]; then
                git clone https://github.com/tammysuryana/tams-dots.git "$REPO"
            fi
            git -C "$REPO" pull --ff-only
            "$REPO/install.sh" --update
        `

        Quickshell.execDetached(["kitty", "--hold", "bash", "-c", updateScript])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }
}
