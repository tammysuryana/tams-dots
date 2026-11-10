import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var monitorConfig
    property real padding: 20
    property int selectedIndex: 0
    property var previewPositions: ({})
    property bool dragHasOverlap: false

    implicitHeight: 280

    // Batas peta dari posisi yang SUDAH tersimpan saja. Kalau ikut posisi pratinjau, skala dan
    // titik nol peta berubah terus selama kotak diseret, sehingga kotak "lari" dari kursor.
    // Peta diberi ruang tetap di keempat sisi layar jangkar (panel laptop, atau layar pertama)
    // selebar/setinggi layar lain terbesar. Dengan begitu skala dan letak jangkar di peta tidak
    // berubah ke mana pun kotak diseret, termasuk ke kiri/atas (koordinat negatif yang lalu
    // dinormalkan ke 0) yang dulu membuat seluruh peta melompat sesudah drop.
    property var bounds: {
        const enabled = monitorConfig.monitors.filter(m => !m.disabled)
        if (enabled.length === 0) return { minX: 0, minY: 0, width: 1920, height: 1080 }
        const anchor = enabled.find(m => /^(eDP|LVDS|DSI)/i.test(m.name)) ?? enabled[0]
        const aw = monitorConfig.logicalWidth(anchor), ah = monitorConfig.logicalHeight(anchor)
        let ew = 0, eh = 0
        for (const m of enabled) {
            if (m === anchor) continue
            ew = Math.max(ew, monitorConfig.logicalWidth(m))
            eh = Math.max(eh, monitorConfig.logicalHeight(m))
        }
        let minX = anchor.x - ew, minY = anchor.y - eh
        let maxX = anchor.x + aw + ew, maxY = anchor.y + ah + eh
        for (const m of enabled) {
            minX = Math.min(minX, m.x)
            minY = Math.min(minY, m.y)
            maxX = Math.max(maxX, m.x + monitorConfig.logicalWidth(m))
            maxY = Math.max(maxY, m.y + monitorConfig.logicalHeight(m))
        }
        return { minX, minY, width: maxX - minX, height: maxY - minY }
    }

    property real scaleFactor: {
        if (bounds.width === 0 || bounds.height === 0) return 0.1
        const scaleX = (canvas.width  - padding * 2) / bounds.width
        const scaleY = (canvas.height - padding * 2) / bounds.height
        return Math.min(scaleX, scaleY)
    }

    property point offset: Qt.point(
        (canvas.width  - bounds.width  * scaleFactor) / 2 - bounds.minX * scaleFactor,
        (canvas.height - bounds.height * scaleFactor) / 2 - bounds.minY * scaleFactor
    )

    function checkOverlap(monitors, idx) {
        const a = monitors[idx]
        const aw = monitorConfig.logicalWidth(a)
        const ah = monitorConfig.logicalHeight(a)
        for (let i = 0; i < monitors.length; i++) {
            if (i === idx) continue
            if (monitors[i].disabled) continue
            const b = monitors[i]
            const bw = monitorConfig.logicalWidth(b)
            const bh = monitorConfig.logicalHeight(b)
            if (a.x < b.x + bw && a.x + aw > b.x &&
                a.y < b.y + bh && a.y + ah > b.y) {
                return true
            }
        }
        return false
    }

    function computeNormalized(monitors, changedIdx, newX, newY) {
        let m = monitors.slice().map(mon => Object.assign({}, mon))
        m[changedIdx].x = newX
        m[changedIdx].y = newY
        let minX = Infinity, minY = Infinity
        for (let i = 0; i < m.length; i++) {
            if (m[i].disabled) continue
            minX = Math.min(minX, m[i].x)
            minY = Math.min(minY, m[i].y)
        }
        const offX = minX < 0 ? -minX : 0
        const offY = minY < 0 ? -minY : 0
        if (offX > 0 || offY > 0) {
            for (let i = 0; i < m.length; i++) {
                m[i].x += offX
                m[i].y += offY
            }
        }
        return m
    }

    function updatePreview(idx, newX, newY) {
        const normalized = computeNormalized(monitorConfig.monitors, idx, newX, newY)
        root.dragHasOverlap = checkOverlap(normalized, idx)
        let preview = {}
        for (let i = 0; i < normalized.length; i++) {
            preview[normalized[i].name] = { x: normalized[i].x, y: normalized[i].y }
        }
        root.previewPositions = preview
    }

    function commitPosition(idx, newX, newY) {
        const before = monitorConfig.monitors
        const normalized = computeNormalized(before, idx, newX, newY)
        root.previewPositions = {}
        for (let i = 0; i < normalized.length; i++) {
            // Dicatat sebagai perubahan tertunda supaya ikut tersimpan ke monitors.lua
            // (dulu save() dipanggil tanpa index, jadi seretan tidak pernah tersimpan).
            if (normalized[i].x !== before[i].x || normalized[i].y !== before[i].y)
                monitorConfig.updateMonitor(i, { x: normalized[i].x, y: normalized[i].y })
            monitorConfig.applyMonitor(normalized[i])
        }
        monitorConfig.saveAll()
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
        clip: true   // kotak yang diseret keluar peta tidak menimpa isi lain

        Item {
            id: canvas
            anchors.fill: parent

            Repeater {
                model: root.monitorConfig.monitors.length
                delegate: MonitorRect {
                    required property int index
                    monitor: root.monitorConfig.monitors[index]
                    monitorIndex: index
                    monitorConfig: root.monitorConfig
                    scaleFactor: root.scaleFactor
                    canvasOffset: root.offset
                    allMonitors: root.monitorConfig.monitors
                    isSelected: index === root.selectedIndex
                    previewPositions: root.previewPositions
                    hasOverlap: root.dragHasOverlap && isDragging

                    onMonitorClicked: (idx) => root.selectedIndex = idx
                    onPositionDragging: (idx, x, y) => root.updatePreview(idx, x, y)
                    onPositionCommitted: (idx, x, y) => {
                        const hadOverlap = root.dragHasOverlap
                        root.previewPositions = {}
                        root.dragHasOverlap = false
                        if (!hadOverlap)
                            root.commitPosition(idx, x, y)
                    }
                }
            }
        }
    }
}