#!/usr/bin/env python3
# Atur layar ala Windows (Win+P): laptop saja / eksternal saja / extend / mirror.
#   display-mode.py daemon     -> jalan di background, terapkan mode tiap
#                                 monitor dicolok/dicabut atau config di-reload
#   display-mode.py menu       -> munculkan menu pilihan (fuzzel)
#   display-mode.py set <mode> -> pilih mode langsung
# Pilihan terakhir disimpan, jadi pas HDMI dicolok lagi mode-nya sama.
# Kalau tidak ada monitor eksternal, layar laptop SELALU dinyalakan.
import json, os, socket, subprocess, sys, time

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
    if lap:
        if mode in ("laptop", "extend"):
            y = max((e["height"] for e in ext), default=0) if mode == "extend" else 0
            # mirror = "" wajib, kalau tidak sisa mode mirror sebelumnya nempel terus.
            rules.append(rule(lap, mode=native(lap), position=f"0x{y}", scale=1, mirror=""))
        elif mode == "mirror":
            rules.append(rule(lap, mode=native(lap), position="auto", scale=1,
                              mirror=ext[0]["name"]))
        else:
            rules.append(rule(lap, disabled=True))
    x = 0
    for e in ext:
        if mode == "laptop":
            rules.append(rule(e, disabled=True))
        else:
            rules.append(rule(e, mode=native(e), position=f"{x}x0", scale=1, mirror=""))
            x += e["width"]
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
    cur = get_mode()
    labels = [("● " if k == cur else "   ") + v for k, v in MODES.items()]
    pick = subprocess.run(["fuzzel", "--dmenu", "--prompt", "Tampilan: ",
                           "--lines", str(len(labels))],
                          input="\n".join(labels), capture_output=True, text=True).stdout.strip()
    for k, v in MODES.items():
        if pick.endswith(v):
            set_mode(k)


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
    else:
        menu()
