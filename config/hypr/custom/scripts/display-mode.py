#!/usr/bin/env python3
# Atur layar ala Windows (Win+P): laptop saja / eksternal saja / extend / mirror,
# Letak layar eksternal saat extend diatur dengan menyeret di Settings → Hyprland → Displays.
#   display-mode.py daemon     -> jalan di background, terapkan mode tiap
#                                 monitor dicolok/dicabut atau config di-reload
#   display-mode.py menu       -> munculkan menu pilihan (fuzzel)
#   display-mode.py set <mode> -> pilih mode langsung
#   display-mode.py letak <atas|bawah|kiri|kanan> -> letak layar eksternal saat extend
# Pilihan terakhir disimpan, jadi pas HDMI dicolok lagi mode-nya sama.
# Kalau tidak ada monitor eksternal, layar laptop SELALU dinyalakan.
import json, os, re, socket, subprocess, sys, time

# Layar bawaan laptop: eDP-1 di laptop ini, laptop lain bisa eDP-2 / LVDS-1. PC desktop: tidak ada.
LAPTOP_PREFIX = ("eDP", "LVDS")
STATE = os.path.expanduser("~/.local/state/display-mode")
# Rule ditulis ke file ini (di-require hyprland.lua setelah monitors.lua) lalu
# `hyprctl reload`. Lewat `hyprctl eval` saja tidak bisa: monitor yang sudah
# disabled tidak mau nyala lagi sampai reload penuh.
RULES = os.path.expanduser("~/.config/hypr/custom/display-mode.lua")
MODES = {
    "eksternal": "Monitor eksternal saja",
    "extend": "Extend (dua layar)",
    "mirror": "Mirror / duplikat",
    "laptop": "Laptop saja",
}
DEFAULT = "eksternal"
# Letak layar eksternal relatif terhadap laptop saat extend. Disimpan terpisah dari mode.
LETAK_STATE = STATE + "-letak"
LETAK = {
    "atas": "Layar eksternal di ATAS laptop",
    "bawah": "Layar eksternal di BAWAH laptop",
    "kiri": "Layar eksternal di KIRI laptop",
    "kanan": "Layar eksternal di KANAN laptop",
    "custom": "Posisi bebas (seret di Settings → Hyprland → Displays)",
}
LETAK_DEFAULT = "atas"
# Kanvas Settings menulis posisi ke file ini; letak "custom" membacanya.
MONITORS_LUA = os.path.expanduser("~/.config/hypr/monitors.lua")


def lua_blocks():
    """output (mis. 'desc:BOE 0x0957') -> field dari monitors.lua."""
    try:
        with open(MONITORS_LUA) as f:
            text = f.read()
    except OSError:
        return {}
    out = {}
    for body in re.findall(r"hl\.monitor\(\{(.*?)\}\)", text, re.S):
        fields = {k: v.strip().strip('"') for k, v in
                  re.findall(r'([A-Za-z_]\w*)\s*=\s*("(?:[^"\\]|\\.)*"|[^,\n]+)', body)}
        if "output" in fields:
            out[fields["output"]] = fields
    return out


def custom_position(m):
    # Kanvas Settings menulis blok dengan nama keluaran (eDP-1); blok lama bisa memakai desc:.
    blocks = lua_blocks()
    b = blocks.get(m["name"]) or blocks.get("desc:" + m["description"]) or {}
    pos = b.get("position", "")
    return pos if re.fullmatch(r"-?\d+x-?\d+", pos) else None


def hyprctl(*args):
    return subprocess.run(["hyprctl", *args], capture_output=True, text=True).stdout


def monitors():
    return [m for m in json.loads(hyprctl("monitors", "all", "-j") or "[]")
            if m["name"] != "FALLBACK"]


def rule(m, **kw):
    # Pakai desc: supaya rule ini menimpa rule yang sama di monitors.lua.
    spec = {"output": "desc:" + m["description"], **kw}
    body = ", ".join(f"{k} = {json.dumps(v)}" for k, v in spec.items())
    return "hl.monitor({ " + body + " })"


def native(m):
    # Mode terbaik = urutan pertama di availableModes ("2560x1440@59.95Hz").
    return m["availableModes"][0].removesuffix("Hz") if m["availableModes"] else "preferred"


def is_laptop(m):
    return m["name"].startswith(LAPTOP_PREFIX)


def settings_of(m):
    """Pilihan dari Settings (monitors.lua): mode, scale, transform. Blok bernama didahulukan."""
    blocks = lua_blocks()
    b = blocks.get(m["name"]) or blocks.get("desc:" + m["description"]) or {}
    out = {}
    if re.fullmatch(r"\d+x\d+@[\d.]+", b.get("mode", "")):
        out["mode"] = b["mode"]
    try:
        sc = float(b.get("scale", ""))
        if 0.5 <= sc <= 4:
            out["scale"] = int(sc) if sc == int(sc) else sc
    except ValueError:
        pass
    if b.get("transform", "") in ("1", "2", "3", "4", "5", "6", "7"):
        out["transform"] = int(b["transform"])
    return out


def chosen_mode(m):
    return settings_of(m).get("mode") or native(m)


def dims(m):
    # Ukuran LOGIS (piksel mode / skala, lebar-tinggi ditukar kalau diputar 90/270), karena
    # posisi Hyprland dihitung dalam piksel logis. Monitor yang disabled melapor 0x0, jadi
    # ukuran diambil dari mode, bukan dari width/height.
    st = settings_of(m)
    try:
        w, h = (int(v) for v in chosen_mode(m).split("@")[0].split("x"))
    except ValueError:
        w, h = m["width"], m["height"]
    if st.get("transform", 0) % 2 == 1:
        w, h = h, w
    sc = st.get("scale", 1)
    return round(w / sc), round(h / sc)


def extra_fields(m):
    """scale/transform pilihan Settings untuk dimasukkan ke rule."""
    st = settings_of(m)
    out = {"scale": st.get("scale", 1)}
    if "transform" in st:
        out["transform"] = st["transform"]
    return out


def get_letak():
    try:
        with open(LETAK_STATE) as f:
            letak = f.read().strip()
        return letak if letak in LETAK else LETAK_DEFAULT
    except OSError:
        return LETAK_DEFAULT


def set_letak(letak):
    os.makedirs(os.path.dirname(LETAK_STATE), exist_ok=True)
    with open(LETAK_STATE, "w") as f:
        f.write(letak)
    apply(get_mode())


def get_mode():
    try:
        with open(STATE) as f:
            mode = f.read().strip()
        return mode if mode in MODES else DEFAULT
    except OSError:
        return DEFAULT


def apply(mode):
    mons = monitors()
    lap = next((m for m in mons if is_laptop(m)), None)
    ext = [m for m in mons if not is_laptop(m)]
    rules = []
    if not ext:
        mode = "laptop"
    elif not lap and mode == "laptop":
        mode = "extend"  # PC desktop tanpa layar laptop: jangan matikan semua monitor
    # Letak saat extend: layar eksternal dijajar mendatar, laptop di sisi yang dipilih.
    letak = get_letak()
    ext_w = sum(dims(e)[0] for e in ext)
    ext_h = max((dims(e)[1] for e in ext), default=0)
    lap_w, lap_h = dims(lap) if lap else (0, 0)
    lap_pos, ext_x0, ext_y = "0x0", 0, 0
    if mode == "extend" and lap:
        if letak == "atas":      lap_pos, ext_y = f"0x{ext_h}", 0
        elif letak == "bawah":   lap_pos, ext_y = "0x0", lap_h
        elif letak == "kiri":    lap_pos, ext_x0 = f"{ext_w}x0", 0
        elif letak == "kanan":   lap_pos, ext_x0 = "0x0", lap_w
    if mode == "extend" and letak == "custom" and lap:
        lap_pos = custom_position(lap) or lap_pos
    if lap:
        if mode in ("laptop", "extend"):
            # mirror = "" wajib, kalau tidak sisa mode mirror sebelumnya nempel terus.
            rules.append(rule(lap, mode=chosen_mode(lap), position=lap_pos, mirror="", **extra_fields(lap)))
        elif mode == "mirror":
            rules.append(rule(lap, mode=chosen_mode(lap), position="auto", mirror=ext[0]["name"],
                              **extra_fields(lap)))
        else:
            rules.append(rule(lap, disabled=True))
    x = ext_x0
    for e in ext:
        if mode == "laptop":
            rules.append(rule(e, disabled=True))
        else:
            pos = f"{x}x{ext_y}"
            if mode == "extend" and letak == "custom":
                pos = custom_position(e) or pos
            rules.append(rule(e, mode=chosen_mode(e), position=pos, mirror="", **extra_fields(e)))
            x += dims(e)[0]
    text = "-- Dibuat otomatis oleh custom/scripts/display-mode.py, jangan diedit.\n" + "\n".join(rules) + "\n"
    try:
        with open(RULES) as f:
            if f.read() == text:
                return  # sudah sesuai, jangan reload (biar tidak loop)
    except OSError:
        pass
    with open(RULES, "w") as f:
        f.write(text)
    hyprctl("reload")
    # Live wallpaper: nyalakan untuk layar baru / sesuaikan crop-fit kalau layar diputar.
    restore = os.path.expanduser("~/.config/hypr/custom/scripts/__restore_video_wallpaper.sh")
    if os.access(restore, os.X_OK):
        subprocess.Popen(["bash", "-c", f"sleep 1.5; '{restore}'"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


def set_mode(mode):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "w") as f:
        f.write(mode)
    apply(mode)


def menu():
    if not any(not is_laptop(m) for m in monitors()):
        subprocess.run(["notify-send", "-a", "Display", "Tidak ada monitor eksternal",
                        "Colok HDMI dulu untuk pilih mode tampilan."])
        return
    # Hanya mode. Letak layar eksternal diatur dengan menyeret di Settings → Hyprland → Displays
    # (otomatis jadi letak "custom"); CLI `letak` tetap ada untuk skrip.
    cur = get_mode()
    labels = [("● " if k == cur else "   ") + v for k, v in MODES.items()]
    pick = subprocess.run(["fuzzel", "--dmenu", "--prompt", "Tampilan: ",
                           "--lines", str(len(labels))],
                          input="\n".join(labels), capture_output=True, text=True).stdout.strip()
    for k, v in MODES.items():
        if pick.endswith(v):
            set_mode(k)
            return


def daemon():
    sock = f"{os.environ['XDG_RUNTIME_DIR']}/hypr/{os.environ['HYPRLAND_INSTANCE_SIGNATURE']}/.socket2.sock"
    apply(get_mode())
    while True:
        try:
            s = socket.socket(socket.AF_UNIX)
            s.connect(sock)
            buf = b""
            while chunk := s.recv(4096):
                buf += chunk
                *lines, buf = buf.split(b"\n")
                ev = {l.split(b">>")[0] for l in lines}
                if ev & {b"monitoraddedv2", b"monitorremovedv2", b"configreloaded"}:
                    time.sleep(0.3)  # tunggu Hyprland selesai ngurus monitornya
                    apply(get_mode())
        except OSError:
            pass
        time.sleep(1)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "menu"
    if cmd == "daemon":
        daemon()
    elif cmd == "set" and len(sys.argv) > 2 and sys.argv[2] in MODES:
        set_mode(sys.argv[2])
    elif cmd == "letak" and len(sys.argv) > 2 and sys.argv[2] in LETAK:
        set_letak(sys.argv[2])
    else:
        menu()
