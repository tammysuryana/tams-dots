pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property color textColor: "white"
    property color activeColor: "white"
    property color dimColor: Qt.rgba(1, 1, 1, 0.35)
    property color indicatorColor: Appearance.colors.colPrimaryContainer
    property color indicatorShapeColor: Appearance.colors.colOnPrimaryContainer
    property int textAlignment: Text.AlignLeft
    property real fontScale: 1.0
    property bool animateTransitions: false
    property real lineSpacing: 6

    implicitWidth: 200
    implicitHeight: 200

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: LyricsService.status !== "ok"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12

                // Loading gaya macOS (spinner jari-jari). Bila lirik tidak ada: teks kecil, klik = coba lagi.
                MacSpinner {
                    Layout.alignment: Qt.AlignHCenter
                    visible: LyricsService.status === "loading"
                    running: visible
                    size: 28
                    color: root.textColor
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    visible: LyricsService.status !== "loading"
                    horizontalAlignment: Text.AlignHCenter
                    color: root.dimColor
                    font.pixelSize: Appearance.font.pixelSize.small * root.fontScale
                    text: (LyricsService.status === "no_info" ? "Info lagu tidak tersedia" : "Lirik tidak ditemukan")
                        + "  ·  klik untuk coba lagi"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LyricsService.restartLyrics()
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: LyricsService.status === "ok"
            spacing: root.lineSpacing

            Repeater {
                model: 7
                delegate: StyledText {
                    id: lyricSlot
                    required property int index
                    Layout.fillWidth: true
                    horizontalAlignment: root.textAlignment
                    wrapMode: Text.WordWrap
                    text: LyricsService.slots[index] ?? ""
                    readonly property int dist: Math.abs(index - LyricsService.before)
                    font.pixelSize: {
                        if (dist === 0) return Appearance.font.pixelSize.normal * root.fontScale
                        if (dist === 1) return Appearance.font.pixelSize.small * root.fontScale
                        return Appearance.font.pixelSize.smaller * root.fontScale
                    }
                    opacity: {
                        if (dist === 0) return 1.0
                        if (dist === 1) return 0.6
                        if (dist === 2) return 0.35
                        return 0.15
                    }
                    color: dist === 0 ? root.activeColor : root.textColor
                    transform: Translate { id: lineSlide }
                    onTextChanged: {
                        if (root.animateTransitions) slideAnim.restart();
                    }
                    SequentialAnimation {
                        id: slideAnim
                        ScriptAction { script: lineSlide.y = 28 * root.fontScale }
                        NumberAnimation { target: lineSlide; property: "y"; to: 0; duration: 420; easing.type: Easing.OutBack }
                    }
                    Behavior on font.pixelSize {
                        enabled: root.animateTransitions
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}