pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string firstRunFilePath: `${Directories.state}/user/first_run.txt`
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property string firstRunNotifSummary: "Welcome!"
    property string firstRunNotifBody: "Hit Super+/ for a list of keybinds"
    property string defaultWallpaperPath: FileUtils.trimFileProtocol(`${Directories.home}/.local/share/tams-dots/wallpapers/tams-default.jpg`)
    property string welcomeQmlPath: FileUtils.trimFileProtocol(Quickshell.shellPath("welcome.qml"))

    function load() {
        firstRunFileView.reload()
    }

    function enableNextTime() {
        Quickshell.execDetached(["rm", "-f", root.firstRunFilePath])
    }
    function disableNextTime() {
        Quickshell.execDetached(["bash", "-c", `echo '${root.firstRunFileContent}' > '${root.firstRunFilePath}'`])
    }

    function handleFirstRun() {
        // Pasang wallpaper bawaan, lalu terapkan skema warna dari config (mis. Tokyo Night).
        // Dengan skema bernama, ganti wallpaper saja tidak membuat warna, jadi perlu --noswitch.
        Quickshell.execDetached(["bash", "-c", `'${Directories.wallpaperSwitchScriptPath}' '${root.defaultWallpaperPath}'; '${Directories.wallpaperSwitchScriptPath}' --noswitch`])
        Quickshell.execDetached(["bash", "-c", `qs -p '${root.welcomeQmlPath}'`])
    }

    FileView {
        id: firstRunFileView
        path: Qt.resolvedUrl(firstRunFilePath)
        onLoadFailed: (error) => {
            if (error == FileViewError.FileNotFound) {
                firstRunFileView.setText(root.firstRunFileContent)
                root.handleFirstRun()
            }
        }
    }
}
