pragma ComponentBehavior: Bound
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs.modules.common
import qs.modules.common.functions
import "../"

NestableObject {
    id: root

    property var monitors: []
    property var _pendingChanges: ({})

    readonly property string configuratorScriptPath: Quickshell.shellPath("scripts/hyprland/monitor_configurator.py")
    readonly property string capsScriptPath: Quickshell.shellPath("scripts/hyprland/monitor_caps.py")
    readonly property string monitorsLuaPath: FileUtils.trimFileProtocol(`${Directories.config}/hypr/monitors.lua`)

    Component.onCompleted: fetchProc.running = true

    Connections {
        target: Hyprland
        enabled: WM.compositor === "hyprland"
        function onRawEvent(event) {
            if (["monitoradded", "monitoraddedv2", "monitorremoved", "monitorlayout", "configreloaded"].includes(event.name))
                refreshTimer.restart()
        }
    }

    Timer {
        id: refreshTimer
        interval: 300
        repeat: false
        onTriggered: fetchProc.running = true
    }

    // Simpan berurutan (satu proses python per layar), lalu reload sekali.
    property var _saveQueue: []
    property bool _positionChanged: false
    // Jalur Win+P (custom/scripts/display-mode.py, kalau ada): posisi hasil kanvas ini harus
    // didaftarkan sebagai letak "custom", kalau tidak ditimpa lagi oleh letak atas/bawah/kiri/kanan.
    readonly property string displayModeScript:
        `${Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")}/hypr/custom/scripts/display-mode.py`

    function _runNextSave() {
        if (root._saveQueue.length === 0) return
        const args = root._saveQueue[0]
        root._saveQueue = root._saveQueue.slice(1)
        saveProc.command = args
        saveProc.running = true
    }

    function saveAll() {
        for (const idx of Object.keys(root._pendingChanges)) root.save(parseInt(idx))
    }

    function updateMonitor(index, changes) {
        let m = root.monitors.slice()
        m[index] = Object.assign({}, m[index], changes)
        root.monitors = m

        let pending = Object.assign({}, root._pendingChanges)
        pending[index] = Object.assign({}, pending[index] || {}, changes)
        root._pendingChanges = pending
    }

    function _mergeByName(patchByName) {
        root.monitors = root.monitors.map(mon => {
            const patch = patchByName[mon.name]
            return patch ? Object.assign({}, mon, patch) : mon
        })
    }

    function _modeToLua(m) {
        const parts = m.currentMode.match(/(\d+)x(\d+)@([\d.]+)Hz/)
        return parts ? `${parts[1]}x${parts[2]}@${parseFloat(parts[3])}` : m.currentMode
    }

    function _fieldsToWrite(m, changedKeys) {
        const setPairs = {}
        const resetKeys = []

        if (changedKeys.has("disabled")) {
            if (m.disabled) setPairs["disabled"] = "1"
            else resetKeys.push("disabled")
        }
        if (changedKeys.has("x") || changedKeys.has("y")) {
            setPairs["position"] = `${m.x}x${m.y}`
        }
        if (changedKeys.has("currentMode") || changedKeys.has("width") || changedKeys.has("height") || changedKeys.has("refreshRate")) {
            setPairs["mode"] = root._modeToLua(m)
        }
        if (changedKeys.has("scale")) setPairs["scale"] = m.scale
        if (changedKeys.has("transform")) {
            if (m.transform && m.transform !== 0) setPairs["transform"] = m.transform
            else resetKeys.push("transform")
        }
        if (changedKeys.has("bitdepth")) {
            if (m.bitdepth) setPairs["bitdepth"] = m.bitdepth
            else resetKeys.push("bitdepth")
        }
        if (changedKeys.has("cm")) {
            if (m.cm && m.cm !== "auto") setPairs["cm"] = m.cm
            else resetKeys.push("cm")
        }
        if (changedKeys.has("sdrBrightness")) setPairs["sdrbrightness"] = m.sdrBrightness
        if (changedKeys.has("sdrSaturation")) setPairs["sdrsaturation"] = m.sdrSaturation
        if (changedKeys.has("minLuminance")) setPairs["min_luminance"] = m.minLuminance
        if (changedKeys.has("maxLuminance")) setPairs["max_luminance"] = m.maxLuminance
        if (changedKeys.has("maxAvgLuminance")) setPairs["max_avg_luminance"] = m.maxAvgLuminance
        if (changedKeys.has("sdrMinLuminance")) setPairs["sdr_min_luminance"] = m.sdrMinLuminance
        if (changedKeys.has("sdrMaxLuminance")) setPairs["sdr_max_luminance"] = m.sdrMaxLuminance
        if (changedKeys.has("vrr")) setPairs["vrr"] = m.vrr ? "1" : "0"

        return { setPairs, resetKeys }
    }

    function save(index) {
        const m = root.monitors[index]
        if (!m || !m.name) return

        const changed = root._pendingChanges[index]
        if (!changed) return
        const changedKeys = new Set(Object.keys(changed))
        const { setPairs, resetKeys } = root._fieldsToWrite(m, changedKeys)

        if (Object.keys(setPairs).length === 0 && resetKeys.length === 0) return

        let args = ["python3", root.configuratorScriptPath, "--file", root.monitorsLuaPath, "--output", m.name]
        for (const key in setPairs) args.push("--set", key, String(setPairs[key]))
        for (const key of resetKeys) args.push("--reset", key)

        if (changedKeys.has("x") || changedKeys.has("y")) root._positionChanged = true
        root._saveQueue = root._saveQueue.concat([args])
        if (!saveProc.running) root._runNextSave()

        let pending = Object.assign({}, root._pendingChanges)
        delete pending[index]
        root._pendingChanges = pending
    }

    function applyMonitor(m) {
        if (!m.name) return

        const base = `${m.name},${m.currentMode},${m.x}x${m.y},${m.scale}`
        applyProc.command = ["hyprctl", "keyword", "monitor",
            m.disabled
                ? `${m.name},disable`
                : (m.transform && m.transform !== 0)
                    ? `${base},transform,${m.transform}`
                    : base]
        applyProc.running = true
    }

    function applyAndSave(index) {
        root.applyMonitor(root.monitors[index])
        root.save(index)
    }

    function saveHdr(index) {
        root.save(index)
    }

    // Ukuran LOGIS seperti yang dipakai Hyprland untuk posisi: piksel mode dibagi skala,
    // lebar-tinggi ditukar bila diputar 90/270. Dulu skala diabaikan, sehingga layar dengan
    // skala != 100% digambar salah ukuran di kanvas dan hasil seretan bisa tumpang tindih.
    function logicalWidth(m) {
        const px = (m.transform === 1 || m.transform === 3) ? m.height : m.width
        return Math.round(px / (m.scale > 0 ? m.scale : 1))
    }

    function logicalHeight(m) {
        const px = (m.transform === 1 || m.transform === 3) ? m.width : m.height
        return Math.round(px / (m.scale > 0 ? m.scale : 1))
    }

    Process {
        id: fetchProc
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text).map(m => ({
                        name:          m.name,
                        description:   m.description,
                        width:         m.width,
                        height:        m.height,
                        refreshRate:   m.refreshRate,
                        x:             m.x,
                        y:             m.y,
                        scale:         m.scale,
                        transform:     m.transform ?? 0,
                        disabled:      m.disabled,
                        availableModes: m.availableModes,
                        currentMode:   `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}Hz`,
                        cm:            m.colorManagementPreset ?? "auto",
                        sdrBrightness: m.sdrBrightness ?? 1.0,
                        sdrSaturation: m.sdrSaturation ?? 1.0,
                        sdrMinLuminance: m.sdrMinLuminance ?? 0,
                        sdrMaxLuminance: m.sdrMaxLuminance ?? 0,
                        vrr:           m.vrr ?? false,
                        bitdepth:        null,
                        minLuminance:    null,
                        maxLuminance:    null,
                        maxAvgLuminance: null,

                        hdrSupported: null,
                        maxBpc:       null,
                    }))
                    if (root.monitors.length > 0) {
                        capsProc.command = ["python3", root.capsScriptPath].concat(root.monitors.map(mon => mon.name))
                        capsProc.running = true
                        dumpProc.command = ["python3", root.configuratorScriptPath, "--file", root.monitorsLuaPath, "--dump-all"]
                        dumpProc.running = true
                    }
                } catch(e) {
                    console.log("[MonitorConfig] Error parseando JSON:", e)
                }
            }
        }
    }

    Process {
        id: capsProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const caps = JSON.parse(text)
                    let patch = {}
                    for (const name in caps) {
                        patch[name] = { hdrSupported: caps[name].hdr, maxBpc: caps[name].maxBpc }
                    }
                    root._mergeByName(patch)
                } catch(e) {
                    console.log("[MonitorConfig] Error parsing caps JSON:", e)
                }
            }
        }
    }

    Process {
        id: dumpProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const dump = JSON.parse(text)
                    let patch = {}
                    for (const name in dump) {
                        const d = dump[name]
                        patch[name] = {
                            bitdepth:        d.bitdepth ?? null,
                            minLuminance:    d.min_luminance ?? null,
                            maxLuminance:    d.max_luminance ?? null,
                            maxAvgLuminance: d.max_avg_luminance ?? null,
                        }
                    }
                    root._mergeByName(patch)
                } catch(e) {
                    console.log("[MonitorConfig] Error parsing monitors.lua dump JSON:", e)
                }
            }
        }
    }

    Process { id: applyProc }

    Process {
        id: saveProc
        onRunningChanged: {
            if (running) return
            if (root._saveQueue.length > 0) { root._runNextSave(); return }
            if (root._positionChanged) {
                root._positionChanged = false
                letakProc.running = true   // display-mode.py letak custom: terapkan + reload sendiri
            } else {
                reloadProc.running = true
            }
        }
    }

    Process {
        id: letakProc
        command: ["bash", "-c",
            `if [ -f '${root.displayModeScript}' ]; then python3 '${root.displayModeScript}' letak custom; else hyprctl reload; fi`]
    }

    Process {
        id: reloadProc
        command: ["hyprctl", "reload"]
    }
}
