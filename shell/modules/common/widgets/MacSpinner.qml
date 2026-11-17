import QtQuick

// Indikator loading gaya macOS: 12 jari-jari membulat tanpa latar, berputar searah jarum jam
// per langkah (satu putaran per detik), jari-jari terdepan paling terang dan ekornya memudar.
// revealed (0..1): saat tidak berputar, jari-jari muncul satu per satu searah jarum jam
// (gaya tarik-untuk-muat-ulang macOS/iOS). 1 = semua tampak.
Item {
    id: root

    property bool running: true
    property color color: "white"
    property int spokes: 12
    property real size: 28
    property real revealed: 1

    implicitWidth: size
    implicitHeight: size

    property int step: 0

    Timer {
        interval: Math.round(1000 / root.spokes)
        repeat: true
        running: root.running && root.visible
        onTriggered: root.step = (root.step + 1) % root.spokes
    }

    Repeater {
        model: root.spokes
        delegate: Item {
            id: spoke
            required property int index
            anchors.fill: parent
            rotation: index * 360 / root.spokes

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.size * 0.03
                width: Math.max(2, root.size * 0.09)
                height: root.size * 0.28
                radius: width / 2
                color: root.color
                // umur = berapa langkah sejak jari-jari ini paling terang
                readonly property int age: (root.step - spoke.index + root.spokes) % root.spokes
                opacity: root.running ? Math.max(0.15, 1 - age / root.spokes)
                    : (spoke.index < Math.round(root.revealed * root.spokes) ? 0.45 : 0)
            }
        }
    }
}
