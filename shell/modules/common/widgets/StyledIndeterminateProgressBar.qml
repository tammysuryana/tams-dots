import qs.modules.common
import QtQuick

// Bar progres tak tentu gaya macOS (menggantikan ProgressBar Material bawaan end4):
// kapsul tipis dengan potongan warna aksen yang meluncur bolak-balik.
// `value` dipertahankan untuk pemakai lama (mis. LocalWallpaperGrid membandingkan value == 0).
Item {
    id: root

    property real value: 0
    property color colTrack: Qt.rgba(Appearance.colors.colOnLayer1.r, Appearance.colors.colOnLayer1.g,
        Appearance.colors.colOnLayer1.b, 0.12)
    property color colAccent: Appearance.colors.colPrimary

    implicitWidth: 200
    implicitHeight: 4

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: height / 2
        color: root.colTrack
        clip: true

        Rectangle {
            id: segment
            width: track.width * 0.35
            height: track.height
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.0) }
                GradientStop { position: 0.3; color: root.colAccent }
                GradientStop { position: 0.7; color: root.colAccent }
                GradientStop { position: 1.0; color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.0) }
            }

            SequentialAnimation on x {
                running: root.visible
                loops: Animation.Infinite
                NumberAnimation { from: -segment.width; to: track.width; duration: 1100; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 150 }
            }
        }
    }
}
