// tams-dots: layar login SDDM (Qt6).
// Wallpaper/video di kanan, panel kaca buram di kiri: logo Arch, jam, pengguna, password, sesi, tombol daya.
import QtQuick
import QtQuick.Effects
import QtMultimedia

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#0d0f1a"

    readonly property real s: Math.max(0.6, height / 1080)   // skala relatif layar 1080p
    readonly property color accent: config.accent ? config.accent : "#1793d1"
    readonly property color teks: "#eef1fb"
    readonly property color teksRedup: "#a9b1d6"
    readonly property color merah: "#ff6b81"
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool sedangMasuk: false

    FontLoader { id: fontSans; source: "fonts/GoogleSansFlex.ttf" }
    readonly property string font: fontSans.status === FontLoader.Ready ? fontSans.name : "sans-serif"

    // Data pengguna & sesi dibaca lewat Repeater tak terlihat.
    Item {
        visible: false
        Repeater {
            id: daftarUser
            model: userModel
            delegate: Item {
                property string nama: model.name
                property string namaAsli: model.realName
            }
        }
        Repeater {
            id: daftarSesi
            model: sessionModel
            delegate: Item { property string nama: model.name }
        }
    }
    readonly property var userAktif: daftarUser.count > 0 ? daftarUser.itemAt(Math.min(userIndex, daftarUser.count - 1)) : null
    readonly property string namaUser: userAktif ? userAktif.nama : (userModel.lastUser || "")
    readonly property string namaTampil: userAktif && userAktif.namaAsli ? userAktif.namaAsli : namaUser
    readonly property var sesiAktif: daftarSesi.count > 0 ? daftarSesi.itemAt(Math.min(sessionIndex, daftarSesi.count - 1)) : null

    function masuk() {
        if (sedangMasuk || namaUser === "")
            return
        sedangMasuk = true
        pesan.text = ""
        sddm.login(namaUser, password.text, sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            sedangMasuk = false
            password.text = ""
            pesan.text = "Password salah, coba lagi"
            goyang.restart()
            password.forceActiveFocus()
        }
        function onLoginSucceeded() {
            keluar.start()
        }
    }

    // ---------- Latar ----------
    Image {
        id: latar
        anchors.fill: parent
        source: config.background ? config.background : "background.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        smooth: true
    }
    // Video latar (opsional, theme.conf video=). background.jpg = frame pertamanya, tampil
    // sampai video siap dan jadi cadangan kalau video gagal diputar.
    Video {
        id: video
        anchors.fill: parent
        source: config.video ? Qt.resolvedUrl(config.video) : ""  // wajib resolvedUrl: di Qt 6 path relatif Video dibaca dari modul Qt, bukan folder tema
        visible: source != "" && playbackState === MediaPlayer.PlayingState
        fillMode: VideoOutput.PreserveAspectCrop
        loops: MediaPlayer.Infinite
        muted: true
        autoPlay: true
    }
    // Gelap tipis ke arah kiri supaya panel menyatu dengan wallpaper.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#99070912" }
            GradientStop { position: 0.45; color: "#33070912" }
            GradientStop { position: 1.0; color: "#00070912" }
        }
    }

    // ---------- Panel kaca ----------
    Item {
        id: panel
        width: Math.max(420 * s, root.width * 0.31)
        height: root.height
        clip: true
        opacity: 0
        x: -40 * s

        Image {   // wallpaper buram, diposisikan sama dengan latar → efek kaca
            width: root.width
            height: root.height
            x: -panel.x
            source: config.backgroundBlur ? config.backgroundBlur : "background-blur.jpg"
            fillMode: Image.PreserveAspectCrop
        }
        ShaderEffectSource {   // potongan video di belakang panel, dibuat buram secara langsung
            id: potonganVideo
            visible: false
            sourceItem: video.visible ? video : null
            sourceRect: Qt.rect(0, 0, panel.width, panel.height)
            textureSize: Qt.size(panel.width / 2, panel.height / 2)
            live: true
        }
        MultiEffect {
            visible: video.visible
            x: -panel.x
            width: panel.width
            height: panel.height
            source: potonganVideo
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            brightness: -0.08
        }
        Rectangle { anchors.fill: parent; color: "#730d0f1a" }
        Rectangle {   // garis tepi kanan
            anchors.right: parent.right
            width: 1
            height: parent.height
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00ffffff" }
                GradientStop { position: 0.5; color: "#33ffffff" }
                GradientStop { position: 1.0; color: "#00ffffff" }
            }
        }

        // Logo Arch di atas
        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 64 * s
            anchors.topMargin: 56 * s
            spacing: 14 * s
            Image {
                source: "arch-logo.svg"
                width: 40 * s
                height: width
                sourceSize: Qt.size(width * 2, height * 2)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: config.title || "Arch Linux"
                color: root.teks
                font.family: root.font
                font.pixelSize: 24 * s
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Isi tengah
        Column {
            id: isi
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 64 * s
            anchors.rightMargin: 64 * s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                id: jam
                color: root.teks
                font.family: root.font
                font.pixelSize: 112 * s
                font.weight: Font.Light
                text: Qt.formatTime(new Date(), "HH:mm")
            }
            Text {
                id: tanggal
                color: root.teksRedup
                font.family: root.font
                font.pixelSize: 24 * s
                text: Qt.locale(config.locale || "").toString(new Date(), "dddd, d MMMM yyyy")
            }

            Item { width: 1; height: 72 * s }

            // Pengguna
            Row {
                spacing: 18 * s
                Rectangle {
                    id: avatar
                    width: 64 * s
                    height: width
                    radius: width / 2
                    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
                    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.8)
                    border.width: 2
                    Text {
                        anchors.centerIn: parent
                        text: root.namaTampil.length > 0 ? root.namaTampil.charAt(0).toUpperCase() : "?"
                        color: root.teks
                        font.family: root.font
                        font.pixelSize: 28 * s
                        font.weight: Font.DemiBold
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2 * s
                    Text {
                        text: root.namaTampil
                        color: root.teks
                        font.family: root.font
                        font.pixelSize: 26 * s
                        font.weight: Font.Medium
                    }
                    Text {
                        visible: daftarUser.count > 1
                        text: "ganti pengguna  ›"
                        color: gantiUser.containsMouse ? root.teks : root.teksRedup
                        font.family: root.font
                        font.pixelSize: 15 * s
                        MouseArea {
                            id: gantiUser
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.userIndex = (root.userIndex + 1) % daftarUser.count
                                password.text = ""
                                password.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 28 * s }

            // Kolom password
            Item {
                id: kotakPassword
                width: Math.min(isi.width, 440 * s)
                height: 56 * s

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: password.activeFocus ? "#33ffffff" : "#1fffffff"
                    border.width: password.activeFocus ? 2 : 1
                    border.color: pesan.text !== "" ? root.merah
                                  : password.activeFocus ? root.accent : "#33ffffff"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                TextInput {
                    id: password
                    anchors.left: parent.left
                    anchors.right: tombolMasuk.left
                    anchors.leftMargin: 24 * s
                    anchors.rightMargin: 12 * s
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: root.teks
                    selectionColor: root.accent
                    font.family: root.font
                    font.pixelSize: 20 * s
                    font.letterSpacing: 2 * s
                    clip: true
                    focus: true
                    enabled: !root.sedangMasuk
                    onAccepted: root.masuk()
                    onTextChanged: if (text !== "") pesan.text = ""
                    Keys.onEscapePressed: text = ""

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: password.text.length === 0
                        text: root.sedangMasuk ? "Masuk…" : "Password"
                        color: "#8a93b8"
                        font.family: root.font
                        font.pixelSize: 19 * s
                    }
                }

                Rectangle {
                    id: tombolMasuk
                    width: 44 * s
                    height: width
                    radius: width / 2
                    anchors.right: parent.right
                    anchors.rightMargin: 6 * s
                    anchors.verticalCenter: parent.verticalCenter
                    color: areaMasuk.pressed ? Qt.darker(root.accent, 1.2)
                           : areaMasuk.containsMouse ? Qt.lighter(root.accent, 1.15) : root.accent
                    opacity: password.text.length > 0 ? 1 : 0.55
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Canvas {   // panah →
                        anchors.centerIn: parent
                        width: 18 * s
                        height: width
                        onPaint: {
                            var c = getContext("2d")
                            c.reset()
                            c.strokeStyle = "white"
                            c.lineWidth = 2.4 * root.s
                            c.lineCap = "round"
                            c.lineJoin = "round"
                            c.beginPath()
                            c.moveTo(width * 0.12, height / 2)
                            c.lineTo(width * 0.88, height / 2)
                            c.moveTo(width * 0.55, height * 0.18)
                            c.lineTo(width * 0.88, height / 2)
                            c.lineTo(width * 0.55, height * 0.82)
                            c.stroke()
                        }
                    }
                    MouseArea {
                        id: areaMasuk
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.masuk()
                    }
                }

                SequentialAnimation {
                    id: goyang
                    property real x0: 0
                    NumberAnimation { target: kotakPassword; property: "x"; to: -14 * root.s; duration: 50 }
                    NumberAnimation { target: kotakPassword; property: "x"; to: 12 * root.s; duration: 70 }
                    NumberAnimation { target: kotakPassword; property: "x"; to: -8 * root.s; duration: 70 }
                    NumberAnimation { target: kotakPassword; property: "x"; to: 5 * root.s; duration: 60 }
                    NumberAnimation { target: kotakPassword; property: "x"; to: 0; duration: 50 }
                }
            }

            Item { width: 1; height: 14 * s }

            Text {
                id: pesan
                leftPadding: 24 * s
                height: 22 * s
                color: root.merah
                font.family: root.font
                font.pixelSize: 16 * s
                text: ""
            }
            Text {
                leftPadding: 24 * s
                height: 22 * s
                visible: keyboard.capsLock
                text: "Caps Lock menyala"
                color: "#ffcb6b"
                font.family: root.font
                font.pixelSize: 16 * s
            }
        }

        // Bawah: sesi + tombol daya
        Row {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 64 * s
            anchors.bottomMargin: 48 * s
            spacing: 10 * s

            Pil {
                label: "Sesi: " + (root.sesiAktif ? root.sesiAktif.nama : "-")
                visible: daftarSesi.count > 0
                onDiklik: root.sessionIndex = (root.sessionIndex + 1) % daftarSesi.count
            }
        }
        Row {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 64 * s
            anchors.bottomMargin: (48 + 52) * s
            spacing: 10 * s
            Pil { label: "Tidur"; visible: sddm.canSuspend; onDiklik: sddm.suspend() }
            Pil { label: "Mulai ulang"; visible: sddm.canReboot; onDiklik: sddm.reboot() }
            Pil { label: "Matikan"; visible: sddm.canPowerOff; onDiklik: sddm.powerOff() }
        }
    }

    component Pil: Rectangle {
        id: pil
        property string label
        signal diklik
        height: 38 * root.s
        width: teksPil.implicitWidth + 32 * root.s
        radius: height / 2
        color: areaPil.pressed ? "#40ffffff" : areaPil.containsMouse ? "#2affffff" : "#14ffffff"
        border.width: 1
        border.color: "#26ffffff"
        Behavior on color { ColorAnimation { duration: 120 } }
        Text {
            id: teksPil
            anchors.centerIn: parent
            text: pil.label
            color: root.teks
            font.family: root.font
            font.pixelSize: 15 * root.s
        }
        MouseArea {
            id: areaPil
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pil.diklik()
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var d = new Date()
            jam.text = Qt.formatTime(d, "HH:mm")
            tanggal.text = Qt.locale(config.locale || "").toString(d, "dddd, d MMMM yyyy")
        }
    }

    ParallelAnimation {
        running: true
        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: 450; easing.type: Easing.OutCubic }
        NumberAnimation { target: panel; property: "x"; to: 0; duration: 550; easing.type: Easing.OutCubic }
    }
    NumberAnimation {
        id: keluar
        target: root; property: "opacity"; to: 0; duration: 250
    }

    Component.onCompleted: password.forceActiveFocus()
}
