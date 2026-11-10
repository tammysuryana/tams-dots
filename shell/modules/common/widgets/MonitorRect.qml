import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    required property var monitor
    required property int monitorIndex
    required property var monitorConfig
    required property real scaleFactor
    required property point canvasOffset
    required property var allMonitors
    property bool isSelected: false
    property var previewPositions: ({})
    property bool hasOverlap: false

    signal positionCommitted(int index, int x, int y)
    signal monitorClicked(int index)
    signal positionDragging(int index, int x, int y)

    property bool isDragging: false
    property real dragX: 0
    property real dragY: 0
    property int snappedX: 0
    property int snappedY: 0
    property real snapThreshold: 12

    property int logW: monitorConfig?.logicalWidth(monitor) ?? 0
    property int logH: monitorConfig?.logicalHeight(monitor) ?? 0

    x: isDragging ? dragX : (previewPositions[monitor.name]?.x ?? monitor.x) * scaleFactor + canvasOffset.x
    y: isDragging ? dragY : (previewPositions[monitor.name]?.y ?? monitor.y) * scaleFactor + canvasOffset.y
    width:  logW * scaleFactor
    height: logH * scaleFactor

    radius: Appearance.rounding.small
    z: isDragging ? 100 : isSelected ? 2 : 1

    color: {
        if (monitor.disabled)             return Appearance.colors.colLayer2
        if (isDragging && hasOverlap)     return Qt.alpha(Appearance.m3colors.m3error, 0.5)
        if (isDragging)                   return Qt.alpha(Appearance.colors.colPrimaryContainer, 0.7)
        if (isSelected)                   return Appearance.colors.colPrimaryContainer
        if (hoverArea.containsMouse)      return Appearance.colors.colSecondaryContainerHover
        return Appearance.colors.colSecondaryContainer
    }

    border.color: (isDragging && hasOverlap) ? Appearance.m3colors.m3error
        : (isDragging || isSelected) ? Appearance.colors.colPrimary
        : Appearance.colors.colLayer0Border
    border.width: (isDragging || isSelected) ? 2 : 1

    Behavior on x { enabled: !isDragging; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: !isDragging; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        visible: root.isDragging && !root.hasOverlap
        x: root.snappedX * root.scaleFactor + root.canvasOffset.x - root.x
        y: root.snappedY * root.scaleFactor + root.canvasOffset.y - root.y
        width: root.width
        height: root.height
        radius: root.radius
        color: "transparent"
        border.color: Appearance.colors.colPrimary
        border.width: 2
        opacity: 0.6
    }

    Column {
        anchors.centerIn: parent
        spacing: 2

        MaterialSymbol {
            anchors.horizontalCenter: parent.horizontalCenter
            text: monitor.disabled ? "desktop_access_disabled" : "desktop_windows"
            iconSize: Math.min(20, Math.min(root.width * 0.25, root.height * 0.25))
            color: monitor.disabled ? Appearance.colors.colSubtext
                : isSelected ? Appearance.colors.colOnPrimaryContainer
                : Appearance.colors.colPrimary
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: monitor?.name ?? ""
            font.pixelSize: Math.max(9, Math.min(13, root.width * 0.1))
            font.weight: Font.Medium
            color: monitor.disabled ? Appearance.colors.colSubtext
                : isSelected ? Appearance.colors.colOnPrimaryContainer
                : Appearance.colors.colOnSecondaryContainer
            elide: Text.ElideMiddle
            width: Math.min(implicitWidth, root.width - 8)
            horizontalAlignment: Text.AlignHCenter
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: `${root.logW}x${root.logH}`
            font.pixelSize: Math.max(8, Math.min(10, root.width * 0.08))
            color: Appearance.colors.colSubtext
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Posisi tempel untuk titik jatuh (px, py): kotak selalu menempel ke tepi layar lain yang
    // terdekat (kanan/kiri/bawah/atas) tanpa celah dan tanpa tumpang tindih, lalu disejajarkan
    // ke atas/tengah/bawah (atau kiri/tengah/kanan) kalau jaraknya di bawah snapThreshold.
    // Hasil berupa koordinat logis Hyprland. Tanpa layar lain: posisi apa adanya.
    function snapPosition(px, py) {
        const w = logW, h = logH
        const tol = snapThreshold / scaleFactor
        const others = []
        for (let i = 0; i < allMonitors.length; i++) {
            if (i === monitorIndex || allMonitors[i].disabled) continue
            const o = allMonitors[i]
            others.push({ x: o.x, y: o.y, w: monitorConfig.logicalWidth(o), h: monitorConfig.logicalHeight(o) })
        }
        if (others.length === 0) return Qt.point(Math.round(px), Math.round(py))

        const overlaps = (x, y) => others.some(o => x < o.x + o.w && x + w > o.x && y < o.y + o.h && y + h > o.y)
        const snapTo = (v, targets) => { for (const t of targets) if (Math.abs(v - t) < tol) return t; return v }
        let cands = []
        for (const o of others) {
            // Harus bersinggungan minimal 10% supaya kursor bisa menyeberang antar layar
            const minY = o.y - h + Math.min(h, o.h) * 0.1, maxY = o.y + o.h - Math.min(h, o.h) * 0.1
            const minX = o.x - w + Math.min(w, o.w) * 0.1, maxX = o.x + o.w - Math.min(w, o.w) * 0.1
            const cy = Math.max(minY, Math.min(maxY, py)), cx = Math.max(minX, Math.min(maxX, px))
            const alignY = [o.y, o.y + (o.h - h) / 2, o.y + o.h - h]
            const alignX = [o.x, o.x + (o.w - w) / 2, o.x + o.w - w]
            cands.push({ x: o.x + o.w, y: snapTo(cy, alignY) })   // kanan o
            cands.push({ x: o.x - w,   y: snapTo(cy, alignY) })   // kiri o
            cands.push({ x: snapTo(cx, alignX), y: o.y + o.h })   // bawah o
            cands.push({ x: snapTo(cx, alignX), y: o.y - h })     // atas o
        }
        cands = cands.map(c => ({ x: Math.round(c.x), y: Math.round(c.y) })).filter(c => !overlaps(c.x, c.y))
        if (cands.length === 0) return Qt.point(Math.round(px), Math.round(py))
        const d = c => Math.hypot(c.x - px, c.y - py)
        const best = cands.reduce((a, b) => d(b) < d(a) ? b : a)
        return Qt.point(best.x, best.y)
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: !monitor.disabled
        cursorShape: monitor.disabled ? Qt.ArrowCursor
            : (root.isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
        drag.target: root
        drag.axis: Drag.XAndYAxis
        drag.threshold: 4

        onPressed: {
            root.dragX = monitor.x * root.scaleFactor + root.canvasOffset.x
            root.dragY = monitor.y * root.scaleFactor + root.canvasOffset.y
            root.snappedX = monitor.x
            root.snappedY = monitor.y
            root.isDragging = true
        }

        onPositionChanged: {
            if (!root.isDragging) return
            root.dragX = root.x
            root.dragY = root.y
            const realX = Math.round((root.x - root.canvasOffset.x) / root.scaleFactor)
            const realY = Math.round((root.y - root.canvasOffset.y) / root.scaleFactor)
            const snapped = root.snapPosition(realX, realY)
            root.snappedX = snapped.x
            root.snappedY = snapped.y
            root.positionDragging(root.monitorIndex, root.snappedX, root.snappedY)
        }

        onReleased: {
            root.isDragging = false
            if (root.snappedX === monitor.x && root.snappedY === monitor.y) {
                root.monitorClicked(root.monitorIndex)
                return
            }
            root.positionCommitted(root.monitorIndex, root.snappedX, root.snappedY)
        }
    }
}