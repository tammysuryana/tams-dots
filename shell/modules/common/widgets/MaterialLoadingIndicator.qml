import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// Indikator loading gaya macOS (menggantikan bentuk Material berganti-ganti bawaan end4).
// Nama & properti dipertahankan supaya semua pemakai lama tetap jalan tanpa diubah:
// colBg / color (latar lingkaran) sengaja tidak dipakai, macOS tidak memakai latar;
// colShape tetap bisa mewarnai jari-jari. pullProgress = tarik-untuk-muat-ulang.
Item {
    id: root

    property bool loading: true
    property double pullProgress: 0

    property color colBg: "transparent"
    property color color: "transparent"
    property color colShape: Appearance.colors.colOnLayer1

    property double implicitSize: 48
    implicitWidth: implicitSize
    implicitHeight: implicitSize

    MacSpinner {
        anchors.centerIn: parent
        size: root.implicitSize * 0.6
        running: root.loading
        revealed: root.loading ? 1 : root.pullProgress
        color: root.colShape
    }
}
