pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Pilihan keluaran suara per port kartu suara (Speaker, Headphones, HDMI, ...), gaya tamsOS.
 * Daftar perangkat PipeWire saja tidak cukup: speaker & headphone laptop adalah dua port dari
 * satu sink, dan HDMI kartu yang profilnya "off" tidak punya sink sama sekali. Maka dibaca
 * langsung dari kartu lewat pactl; memilih = ganti profil kartu bila perlu, lalu port + bawaan.
 * Headphones selalu ditampilkan walau colokan tak terbaca (deteksi jack sering meleset,
 * mis. Razer Blade ALC256), supaya tetap bisa dipaksa ke sana.
 */
Singleton {
    id: root

    // [{ key, label, sub, kind: "speaker"|"headphones"|"hdmi", plugged, active, card, cardProfile, profile, port }]
    property var outputs: []
    readonly property var current: outputs.find(o => o.active) ?? null
    property var pending: null      // { card, port } yang sedang dipindah ke sana
    property var _sinks: []

    function select(o) {
        if (!o || o.active) return
        root.pending = { card: o.card, port: o.port }
        pendingTimeout.restart()
        if (o.profile !== o.cardProfile) {
            run(["pactl", "set-card-profile", o.card, o.profile])
        } else {
            applyPending()
        }
    }

    // Sink kartu itu sudah ada: pilih port-nya, jadikan bawaan, pindahkan suara yang sedang main.
    // Suara yang lewat Easyeffects tidak dipindah (efeknya tetap jalan; Easyeffects ikut sink bawaan).
    function applyPending() {
        const p = root.pending
        if (!p) return
        const s = root._sinks.find(s => s.properties["device.name"] === p.card && s.ports.some(sp => sp.name === p.port))
        if (!s) return    // profil baru belum selesai dibuat; tunggu event berikutnya
        root.pending = null
        pendingTimeout.stop()
        run(["sh", "-c", 'pactl set-sink-port "$1" "$2"; pactl set-default-sink "$1"; '
            + 'ee=$(pactl list short sinks | awk \'$2=="easyeffects_sink"{print $1}\'); '
            + 'pactl list short sink-inputs | while read -r i sink _; do '
            + '[ "$sink" = "$ee" ] || pactl move-sink-input "$i" "$1"; done',
            "sh", s.name, p.port])
    }

    function run(cmd) { Quickshell.execDetached(cmd); refreshDelay.restart() }

    function parse(cardsJson, sinksJson, defaultSink) {
        const cards = JSON.parse(cardsJson)
        const sinks = JSON.parse(sinksJson)
        const list = []
        for (const c of cards) {
            const bt = c.name.startsWith("bluez_card")
            const internal = c.properties["device.form_factor"] === "internal"
            const activeWords = c.active_profile.split(/[^\w-]+/)
            for (const pn in c.ports) {
                if (!(pn.startsWith("[Out]") || /output/i.test(pn))) continue
                if (/iec958|spdif/i.test(pn)) continue
                const p = c.ports[pn]
                const type = (p.properties["port.type"] || p.type || "").toLowerCase()
                const kind = /head/.test(type) ? "headphones" : type === "hdmi" ? "hdmi" : "speaker"
                const plugged = p.availability !== "not available"
                const s = sinks.find(s => s.properties["device.name"] === c.name && s.ports.some(sp => sp.name === pn))
                const active = !!s && s.name === defaultSink && s.active_port === pn
                // Port tak tercolok disembunyikan, kecuali headphone (deteksi colokan sering meleset)
                if (!plugged && kind !== "headphones" && !active) continue

                // Profil: yang aktif kalau sudah memuat port ini; kalau tidak, yang tersedia,
                // paling mirip profil sekarang, lalu prioritas tertinggi.
                let profile = c.active_profile
                if (!p.profiles.includes(profile)) {
                    const score = n => n.split(/[^\w-]+/).filter(w => w && activeWords.includes(w)).length
                    profile = p.profiles
                        .filter(n => c.profiles[n])
                        .sort((a, b) => (c.profiles[b].available - c.profiles[a].available)
                            || (score(b) - score(a))
                            || (c.profiles[b].priority - c.profiles[a].priority))[0]
                    if (!profile) continue
                }

                let label = p.description
                if (bt) label = c.properties["device.description"] || label
                else if (kind === "hdmi" && p.properties["device.product.name"]) label = "HDMI · " + p.properties["device.product.name"]

                const sub = []
                if (!internal && !bt) sub.push(c.properties["device.description"] || c.name)
                if (!plugged) sub.push("tidak terdeteksi")

                list.push({
                    key: c.name + "|" + pn, label: label, sub: sub.join(" · "), kind: kind,
                    plugged: plugged, active: active,
                    card: c.name, cardProfile: c.active_profile, profile: profile, port: pn
                })
            }
        }
        const rank = { speaker: 0, headphones: 1, hdmi: 2 }
        root.outputs = list.sort((a, b) => (b.plugged - a.plugged) || (rank[a.kind] - rank[b.kind]) || a.label.localeCompare(b.label))
        root._sinks = sinks
        applyPending()
    }

    function refresh() { readProc.running = true }

    Process {
        id: readProc
        // Bila bawaan = easyeffects_sink, keluaran nyata = sink tujuan output Easyeffects (pw-link)
        command: ["sh", "-c", "pactl -f json list cards; echo; echo @@; pactl -f json list sinks; echo; echo @@; "
            + "d=$(pactl get-default-sink); [ \"$d\" = easyeffects_sink ] && d=$(pw-link -l 2>/dev/null | "
            + "awk '/^ee_soe_output_level:output_FL/{getline; sub(/^ *\\|-> */, \"\"); split($0, a, \":\"); print a[1]; exit}') ; echo \"$d\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const part = text.split("\n@@\n")
                if (part.length < 3) return
                try { root.parse(part[0], part[1], part[2].trim()) } catch (e) { console.warn("AudioOutputs: " + e) }
            }
        }
    }

    // Colok/cabut, ganti profil, sink baru, ganti bawaan -> baca ulang (dikumpulkan dulu)
    Process {
        id: subscribeProc
        command: ["pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            onRead: line => { if (/on (card|sink|server)\b(?!-)/.test(line)) refreshDelay.restart() }
        }
        onExited: restartSubscribe.start()
    }
    Timer { id: restartSubscribe; interval: 3000; onTriggered: subscribeProc.running = true }
    Timer { id: refreshDelay; interval: 150; onTriggered: root.refresh() }
    Timer { id: pendingTimeout; interval: 4000; onTriggered: root.pending = null }
}
