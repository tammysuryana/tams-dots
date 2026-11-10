#!/usr/bin/env bash
# tams-dots — installer desktop Hyprland + tams-shell untuk Arch Linux & turunannya.
#
#   git clone https://github.com/tammysuryana/tams-dots.git ~/tams-dots
#   cd ~/tams-dots && ./install.sh
#
# Opsi:
#   ./install.sh                 pasang semuanya (bertanya di langkah penting)
#   ./install.sh --yes           pasang semuanya, semua pertanyaan dijawab pilihan bawaan
#   ./install.sh --configs-only  hanya salin pengaturan (tanpa install paket & tema sistem)
#   ./install.sh --update        perbarui shell & config bawaan, pengaturan pribadimu tidak disentuh
#   ./install.sh --help          tampilkan bantuan ini
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.tams-dots-backup-$TS"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
VENV="$XDG_STATE_HOME/tams-dots/.venv"

C='\033[0;36m'; G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; B='\033[1m'; N='\033[0m'
LANGKAH=0; TOTAL=8
say()  { LANGKAH=$((LANGKAH + 1)); echo -e "\n${C}${B}==> ${LANGKAH}/${TOTAL} $*${N}"; }
ok()   { echo -e "${G}   ✓ $*${N}"; }
warn() { echo -e "${Y}   ! $*${N}"; PERINGATAN+=("$*"); }
die()  { echo -e "${R}✗ $*${N}"; exit 1; }
PERINGATAN=()

YES=0; MODE=full
for a in "$@"; do
  case "$a" in
    -y|--yes) YES=1 ;;
    --configs-only) MODE=configs ;;
    --update) MODE=update; YES=1 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) die "opsi tidak dikenal: $a (lihat ./install.sh --help)" ;;
  esac
done

case "$MODE" in configs) TOTAL=4 ;; update) TOTAL=2 ;; esac

# tanya "pertanyaan" y|n  -> pilihan bawaan dipakai kalau langsung Enter atau --yes
tanya() {
  local q="$1" def="$2" a hint="[y/N]"
  [ "$def" = y ] && hint="[Y/n]"
  if [ $YES -eq 1 ]; then echo -e "${Y}$q $hint: ${N}$def (otomatis)"; [ "$def" = y ]; return; fi
  read -r -p "$(echo -e "${Y}$q $hint: ${N}")" a || a=""
  a="${a:-$def}"
  [[ "$a" =~ ^[Yy]$ ]]
}

# ---------------------------------------------------------------------------
# Pemeriksaan awal
# ---------------------------------------------------------------------------
[ "$(id -u)" -eq 0 ] && die "Jangan jalankan sebagai root / pakai sudo. Jalankan sebagai user biasa: ./install.sh"
command -v pacman >/dev/null || die "Installer ini hanya untuk Arch Linux dan turunannya (butuh pacman)."

ARCH="$(uname -m)"
DISTRO="$(. /etc/os-release 2>/dev/null; echo "${ID:-arch}")"
case "$ARCH" in
  x86_64|aarch64) ;;
  *) die "Arsitektur $ARCH belum didukung (hanya x86_64 dan aarch64)." ;;
esac

echo -e "${C}${B}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║        tams-dots — installer           ║"
echo "  ╚════════════════════════════════════════╝${N}"
echo "  Sistem : $DISTRO ($ARCH)"
echo "  User   : $USER  (home: $HOME)"
echo "  Repo   : $REPO"
echo "  Mode   : $MODE"
[ "$ARCH" = aarch64 ] && echo -e "  ${Y}Catatan: ARM (mis. Apple Silicon via Asahi) didukung sebisanya; paket yang tidak tersedia untuk ARM dilewati.${N}"
[ "$DISTRO" = manjaro ] && echo -e "  ${Y}Catatan: Manjaro memakai repo yang tertinggal dari Arch, sebagian paket bisa gagal.${N}"

if [ "$MODE" != configs ] && [ "$MODE" != update ]; then
  curl -fsI --max-time 15 https://archlinux.org >/dev/null 2>&1 || die "Tidak ada internet. Sambungkan dulu (WiFi: nmtui), lalu ulangi."
  echo
  echo "  Installer akan meminta password sudo (password login kamu) beberapa kali."
  sudo -v || die "sudo gagal. Pastikan user $USER boleh memakai sudo."
  # jaga sesi sudo tetap aktif selama install
  ( while true; do sudo -n true 2>/dev/null; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
  SUDO_KEEP=$!
  trap 'kill $SUDO_KEEP 2>/dev/null || true' EXIT
fi

baca_daftar() { grep -vE '^\s*(#|$)' "$1" | sed 's/\s*#.*//'; }

# makepkg -si (pacman >= 7.1) memanggil "sudo -k" -> selalu minta password lagi.
# Jadi build saja di folder sekarang, dependensi & hasil dipasang lewat sesi sudo installer.
makepkg_pasang() {
  local deps pkgs
  mapfile -t deps < <(makepkg --printsrcinfo | sed -nE 's/^\s*(make|check)?depends = ([^<>=]+).*/\2/p')
  [ ${#deps[@]} -eq 0 ] || sudo pacman -S --needed --noconfirm --asdeps "${deps[@]}" || return
  makepkg -f --noconfirm || return
  mapfile -t pkgs < <(makepkg --packagelist | grep -v -- '-debug-')
  sudo pacman -U --needed --noconfirm "${pkgs[@]}"
}

# ---------------------------------------------------------------------------
# 1-4: Paket (dilewati di --configs-only / --update)
# ---------------------------------------------------------------------------
if [ "$MODE" = full ]; then
  say "Update sistem & paket dari repo resmi"
  sudo pacman -Syu --noconfirm
  mapfile -t WANT < <(baca_daftar "$REPO/packages/pacman.txt")
  ADA=(); KE_AUR=()
  for p in "${WANT[@]}"; do
    if pacman -Si "$p" >/dev/null 2>&1; then ADA+=("$p"); else KE_AUR+=("$p"); fi
  done
  # pulseaudio (mis. pilihan audio di archinstall) bentrok dengan pipewire-pulse,
  # dan --noconfirm menjawab "N" saat ditanya menghapusnya -> ganti dulu ke pipewire
  mapfile -t PULSE < <(pacman -Qq 2>/dev/null | grep -xE 'pulseaudio(-(bluetooth|equalizer|jack|lirc|rtp|zeroconf))?' || true)
  if [ ${#PULSE[@]} -gt 0 ]; then
    echo "   pulseaudio terpasang, diganti ke pipewire: ${PULSE[*]}"
    sudo pacman -Rdd --noconfirm "${PULSE[@]}"
    ok "pulseaudio dilepas (audio pindah ke pipewire setelah login ulang)"
  fi
  sudo pacman -S --needed --noconfirm "${ADA[@]}"
  ok "${#ADA[@]} paket resmi terpasang"
  [ ${#KE_AUR[@]} -gt 0 ] && echo "   (tidak ada di repo komputer ini, dicoba lewat AUR: ${KE_AUR[*]})"

  say "Paket AUR (lewat yay)"
  if ! command -v yay >/dev/null; then
    sudo pacman -S --needed --noconfirm base-devel git
    tmp="$(mktemp -d)"
    git clone -q https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg_pasang)
    rm -rf "$tmp"
  fi
  mapfile -t AUR < <(baca_daftar "$REPO/packages/aur.txt")
  AUR+=("${KE_AUR[@]}")
  if ! yay -S --needed --noconfirm --answerdiff None --answerclean None "${AUR[@]}"; then
    warn "pemasangan AUR sekaligus gagal, dicoba satu per satu"
    for p in "${AUR[@]}"; do
      yay -S --needed --noconfirm --answerdiff None --answerclean None "$p" >/dev/null 2>&1 \
        && ok "$p" || warn "paket AUR gagal: $p"
    done
  fi
  # PKGBUILD lokal: ikon OneUI4 & MicroTeX (rumus LaTeX di chat AI)
  for d in "$REPO"/packages/local/*/; do
    nama="$(basename "$d")"
    if pacman -Q "$nama" >/dev/null 2>&1; then ok "$nama sudah ada"; continue; fi
    tmp="$(mktemp -d)"; cp -r "$d." "$tmp/"
    (cd "$tmp" && makepkg_pasang) && ok "$nama" || warn "gagal build $nama"
    rm -rf "$tmp"
  done

  say "Driver kartu grafis"
  if [ "$ARCH" = aarch64 ]; then
    ok "ARM: driver grafis mengikuti kernel distro (mis. Asahi), dilewati"
  elif command -v chwd >/dev/null; then
    # CachyOS: deteksi hardware otomatis
    sudo chwd -a && ok "driver dipilih otomatis oleh chwd" || warn "chwd gagal, cek manual: sudo chwd -a"
  else
    GPU="$(lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' || true)"
    echo "$GPU" | sed 's/^/   /'
    DRV=(mesa)
    echo "$GPU" | grep -qi 'intel'  && DRV+=(vulkan-intel intel-media-driver)
    echo "$GPU" | grep -qiE 'amd|ati|radeon' && DRV+=(vulkan-radeon)
    if echo "$GPU" | grep -qi nvidia; then
      if echo "$GPU" | grep -qE '\b(TU|GA|AD|GB)[0-9]{3}'; then
        DRV+=(nvidia-open-dkms nvidia-utils egl-wayland)
        while read -r k; do DRV+=("$k-headers"); done < <(pacman -Qq | grep -xE 'linux|linux-lts|linux-zen|linux-hardened' || true)
      else
        warn "kartu NVIDIA lama terdeteksi: pasang driver manual sesuai wiki.archlinux.org/title/NVIDIA"
      fi
    fi
    mapfile -t DRV < <(for p in "${DRV[@]}"; do pacman -Si "$p" >/dev/null 2>&1 && echo "$p"; done)
    if tanya "Pasang driver grafis: ${DRV[*]}?" y; then
      sudo pacman -S --needed --noconfirm "${DRV[@]}" && ok "driver grafis terpasang"
    fi
  fi

  say "Tema ikon, kursor & GTK"
  tmp="$(mktemp -d)"
  if [ -d /usr/share/icons/MacTahoe-light ]; then
    ok "ikon & kursor MacTahoe sudah ada"
  else
    git clone -q --depth 1 https://github.com/vinceliuice/MacTahoe-icon-theme.git "$tmp/mactahoe"
    (cd "$tmp/mactahoe" && sudo ./install.sh >/dev/null && cd cursors && sudo ./install.sh >/dev/null) \
      && ok "ikon & kursor MacTahoe (vinceliuice)" || warn "gagal memasang MacTahoe"
  fi
  if [ -d "$HOME/.themes/Tahoe-Dark" ]; then
    ok "tema GTK Tahoe-Dark sudah ada"
  else
    git clone -q --depth 1 https://github.com/kayozxo/GNOME-macOS-Tahoe.git "$tmp/tahoe" \
      && mkdir -p "$HOME/.themes" && cp -r "$tmp/tahoe/gtk/Tahoe-Dark" "$HOME/.themes/" \
      && ok "tema GTK Tahoe-Dark (kayozxo)" || warn "gagal mengunduh tema GTK Tahoe-Dark"
  fi
  rm -rf "$tmp"
fi

# ---------------------------------------------------------------------------
# Salin pengaturan
# ---------------------------------------------------------------------------
cadangkan() { # cadangkan $1 (path di $HOME) kalau ada, sebelum ditimpa
  [ -e "$1" ] || return 0
  local rel="${1#"$HOME"/}"
  mkdir -p "$BACKUP/$(dirname "$rel")"
  cp -a "$1" "$BACKUP/$rel"
}

say "Pasang shell & pengaturan"
mkdir -p "$XDG_CONFIG_HOME/quickshell" "$XDG_DATA_HOME/tams-dots/wallpapers" "$XDG_STATE_HOME/tams-dots" "$HOME/.local/bin"
# Cache thumbnail freedesktop: tanpa folder ini pratinjau wallpaper (menu klik kanan) tidak pernah muncul
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/thumbnails"/{normal,large,x-large,xx-large}

# Shell: selalu disamakan dengan repo (folder ini tidak untuk diedit pengguna)
rsync -a --delete "$REPO/shell/" "$XDG_CONFIG_HOME/quickshell/tams-shell/"
ok "tams-shell -> ~/.config/quickshell/tams-shell"
rsync -a "$REPO/assets/wallpapers/" "$XDG_DATA_HOME/tams-dots/wallpapers/"
ok "wallpaper -> ~/.local/share/tams-dots/wallpapers"

# Versi lama memasang hyprland-session.target (WantedBy=default.target): target itu menyalakan
# graphical-session.target begitu login, sehingga uwsm menolak menjalankan Hyprland -> balik ke SDDM
if [ -f "$XDG_CONFIG_HOME/systemd/user/hyprland-session.target" ]; then
  systemctl --user disable hyprland-session.target >/dev/null 2>&1 || true
  rm -f "$XDG_CONFIG_HOME/systemd/user/hyprland-session.target"
  ok "hyprland-session.target lama dihapus"
fi

if [ "$MODE" = update ]; then
  # Hanya bagian bawaan Hyprland; custom/, monitor, config.json milikmu tidak disentuh
  cadangkan "$XDG_CONFIG_HOME/hypr/hyprland"
  rsync -a --delete "$REPO/config/hypr/hyprland/" "$XDG_CONFIG_HOME/hypr/hyprland/"
  cp "$REPO/config/hypr/hyprland.lua" "$XDG_CONFIG_HOME/hypr/hyprland.lua"
  ok "config bawaan Hyprland diperbarui (custom/ & pengaturan pribadi tetap)"
else
  for src in "$REPO"/config/*; do
    name="$(basename "$src")"
    dst="$XDG_CONFIG_HOME/$name"
    cadangkan "$dst"
    if [ -d "$src" ]; then
      # hypr/custom & monitors milik pengguna: jangan dihapus kalau sudah ada
      if [ "$name" = hypr ]; then
        rsync -a --exclude='custom/' --exclude='monitors.lua' --exclude='workspaces.lua' "$src/" "$dst/"
        [ -d "$dst/custom" ] || cp -r "$src/custom" "$dst/custom"
        [ -f "$dst/monitors.lua" ] || cp "$src/monitors.lua" "$dst/"
        [ -f "$dst/workspaces.lua" ] || cp "$src/workspaces.lua" "$dst/"
      else
        rsync -a "$src/" "$dst/"
      fi
    else
      cp -a "$src" "$dst"
    fi
  done
  # Isi path rumah pengguna ini
  for f in "$XDG_CONFIG_HOME/tams-dots/config.json" "$XDG_CONFIG_HOME/hypr/hyprlock/colors.conf"; do
    [ -f "$f" ] && sed -i "s#@HOME@#$HOME#g" "$f"
  done
  # GTK2
  cadangkan "$HOME/.gtkrc-2.0"
  printf 'include "%s/.config/gtkrc-2.0"\n' "$HOME" > "$HOME/.gtkrc-2.0"
  ok "pengaturan -> ~/.config"
  [ -d "$BACKUP" ] && echo "   (pengaturan lama dicadangkan di ${BACKUP/#$HOME/\~})"
fi
echo "$REPO" > "$XDG_CONFIG_HOME/tams-dots/repo-path"
find "$XDG_CONFIG_HOME/hypr" "$XDG_CONFIG_HOME/quickshell/tams-shell" -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} + 2>/dev/null || true
[ -f "$XDG_CONFIG_HOME/hypr/custom/scripts/__restore_video_wallpaper.sh" ] || \
  printf '#!/bin/bash\n' > "$XDG_CONFIG_HOME/hypr/custom/scripts/__restore_video_wallpaper.sh"
chmod +x "$XDG_CONFIG_HOME/hypr/custom/scripts/__restore_video_wallpaper.sh"

say "Font & lingkungan Python"
mkdir -p "$XDG_DATA_HOME/fonts/tams-dots"
cp "$REPO/theme/sddm/tams-dots/fonts/"* "$XDG_DATA_HOME/fonts/tams-dots/"
fc-cache -f >/dev/null 2>&1 || true
ok "font Google Sans Flex"
if command -v uv >/dev/null; then
  if [ ! -x "$VENV/bin/python" ] || [ "$MODE" = update ]; then
    UV_NO_MODIFY_PATH=1 uv venv --allow-existing --prompt .venv "$VENV" -p 3.12 >/dev/null
    # shellcheck disable=SC1091
    ( source "$VENV/bin/activate" && uv pip install -q -r "$REPO/packages/python-requirements.txt" ) \
      && ok "python venv -> ${VENV/#$HOME/\~}" || warn "gagal memasang paket python (warna otomatis dari wallpaper bisa tidak jalan)"
  else
    ok "python venv sudah ada"
  fi
else
  warn "uv tidak ada, lewati python venv (jalankan installer penuh dulu)"
fi

if [ "$MODE" = update ]; then
  echo -e "\n${G}${B}Update selesai.${N} Muat ulang shell: tekan Ctrl+Super+R, atau logout lalu login lagi."
  echo -e "Terima kasih sudah memakai tams-dots! 💖 Dukung di ${B}https://saweria.co/tamsrich${N}"
  exit 0
fi

# ---------------------------------------------------------------------------
# Layanan, grup, tampilan aplikasi
# ---------------------------------------------------------------------------
say "Layanan & izin perangkat"
if [ "$MODE" = full ]; then
  getent group i2c >/dev/null || sudo groupadd i2c
  sudo usermod -aG video,i2c,input "$USER" && ok "user $USER masuk grup video, i2c, input"
  echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
  sudo systemctl enable --now bluetooth.service >/dev/null 2>&1 && ok "bluetooth aktif" || warn "bluetooth tidak bisa diaktifkan"
  sudo systemctl enable NetworkManager.service >/dev/null 2>&1 || true
  if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    systemctl --user enable --now ydotool.service >/dev/null 2>&1 || true
  else
    sudo systemctl --machine="$USER@.host" --user enable ydotool.service >/dev/null 2>&1 || true
  fi
fi
systemctl --user daemon-reload 2>/dev/null || true
xdg-user-dirs-update 2>/dev/null || true
if command -v gsettings >/dev/null; then
  gsettings set org.gnome.desktop.interface font-name 'Google Sans Flex Medium 11 @opsz=11,wght=500' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface icon-theme 'MacTahoe-light' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface cursor-theme 'MacTahoe-light' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface gtk-theme 'Tahoe-Dark' 2>/dev/null || true
fi
command -v kwriteconfig6 >/dev/null && kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Darkly 2>/dev/null || true
ok "pengaturan tampilan aplikasi"

# ---------------------------------------------------------------------------
# Login & boot
# ---------------------------------------------------------------------------
say "Shell terminal, layar login & tampilan boot"
if command -v fish >/dev/null && [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v fish)" ]; then
  if tanya "Pakai fish sebagai shell terminal (warna & saran perintah otomatis)?" y; then
    if [ "$MODE" = full ]; then sudo chsh -s "$(command -v fish)" "$USER"; else chsh -s "$(command -v fish)"; fi \
      && ok "shell terminal = fish" || warn "gagal mengganti shell, jalankan manual: chsh -s $(command -v fish)"
  fi
fi
if [ "$MODE" = full ] && command -v sddm >/dev/null; then
  if ! systemctl is-enabled display-manager.service >/dev/null 2>&1; then
    tanya "Aktifkan SDDM sebagai layar login?" y && sudo systemctl enable sddm.service && ok "SDDM aktif"
  fi
  if tanya "Pasang layar login tams-dots (latar video bergerak)?" y; then
    sudo bash "$REPO/theme/sddm.sh" install && ok "layar login tams-dots" || warn "gagal memasang layar login"
  fi
  if tanya "Langsung masuk desktop tanpa password saat nyala (autologin)?" n; then
    printf '[Autologin]\nUser=%s\nSession=hyprland\n' "$USER" | sudo tee /etc/sddm.conf.d/20-tams-dots-autologin.conf >/dev/null
    ok "autologin aktif (hapus /etc/sddm.conf.d/20-tams-dots-autologin.conf untuk mematikan)"
  fi
fi
if [ "$MODE" = full ]; then
  if tanya "Pasang tampilan boot logo Arch (menu GRUB + animasi startup)?" y; then
    sudo bash "$REPO/theme/boot.sh" install && ok "tampilan boot tams-dots" || warn "gagal memasang tampilan boot"
  fi
fi

# ---------------------------------------------------------------------------
echo
echo -e "${G}${B}╔════════════════════════════════════════╗${N}"
echo -e "${G}${B}║  Selesai                               ║${N}"
echo -e "${G}${B}╚════════════════════════════════════════╝${N}"
if [ ${#PERINGATAN[@]} -gt 0 ]; then
  echo -e "${Y}Ada ${#PERINGATAN[@]} peringatan (bagian lain tetap terpasang):${N}"
  for p in "${PERINGATAN[@]}"; do echo -e "${Y}  - $p${N}"; done
fi
echo
echo "Langkah berikutnya:"
echo "  1. Restart komputer:  reboot"
echo "  2. Di layar login pilih sesi 'Hyprland', masuk."
echo "  3. Tekan Super + / untuk melihat semua tombol pintas."
[ -d "$BACKUP" ] && echo "  Pengaturan lama yang tertimpa: ${BACKUP/#$HOME/\~}"
echo
echo -e "${C}Terima kasih sudah memasang tams-dots! 💖${N}"
echo -e "Kalau bermanfaat, dukung pengembangannya di ${B}https://saweria.co/tamsrich${N}"
exit 0
