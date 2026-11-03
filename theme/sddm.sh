#!/bin/bash
# tams-dots: layar login SDDM (panel kaca + latar video bergerak).
#   sudo bash theme/sddm.sh install                pasang dengan latar bawaan
#   sudo bash theme/sddm.sh install <file>         pasang dengan latar gambar/video sendiri
#   sudo bash theme/sddm.sh uninstall              kembali ke layar login bawaan SDDM
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Jalankan dengan sudo:  sudo bash $0 ${1:-install}"; exit 1; }

DIR="$(cd "$(dirname "$0")" && pwd)"
NAMA=tams-dots
TUJUAN="/usr/share/sddm/themes/$NAMA"
KONF="/etc/sddm.conf.d/10-$NAMA.conf"

pasang() {
    command -v sddm >/dev/null || { echo "SDDM tidak terpasang. Pasang dulu: sudo pacman -S sddm"; exit 1; }
    local kerja; kerja="$(mktemp -d)"
    cp -r "$DIR/sddm/$NAMA/." "$kerja/"

    # Latar sendiri (opsional): video dikecilkan ke 1080p 30fps kalau berat, gambar dipotong 1920x1080
    local sumber="${1:-}"
    if [ -n "$sumber" ]; then
        [ -f "$sumber" ] || { echo "File tidak ada: $sumber"; exit 1; }
        case "$(file -b --mime-type "$sumber")" in
        video/*|image/gif)
            ffmpeg -v error -y -i "$sumber" -map 0:v:0 -an \
                -vf "scale=1920:1080:force_original_aspect_ratio=increase:flags=lanczos,crop=1920:1080,fps=30,format=yuv420p" \
                -c:v libx264 -preset medium -crf 22 -movflags +faststart "$kerja/background.mp4"
            ffmpeg -v error -y -i "$kerja/background.mp4" -frames:v 1 -q:v 2 "$kerja/background.jpg"
            grep -q '^video=' "$kerja/theme.conf" || echo "video=background.mp4" >> "$kerja/theme.conf"
            ;;
        image/*)
            magick "$sumber" -resize 1920x1080^ -gravity center -extent 1920x1080 -quality 92 "$kerja/background.jpg"
            rm -f "$kerja/background.mp4"
            sed -i '/^video=/d' "$kerja/theme.conf"
            ;;
        *) echo "Bukan gambar/video: $sumber"; exit 1 ;;
        esac
        magick "$kerja/background.jpg" -resize 25% -blur 0x18 -resize 1920x1080! \
            -fill '#0d0f1a' -colorize 25% -quality 90 "$kerja/background-blur.jpg"
    fi

    rm -rf "$TUJUAN"
    install -d -m 755 "$TUJUAN"
    cp -r "$kerja/." "$TUJUAN/"
    rm -rf "$kerja"
    chown -R root:root "$TUJUAN"
    find "$TUJUAN" -type d -exec chmod 755 {} +
    find "$TUJUAN" -type f -exec chmod 644 {} +

    install -d -m 755 /etc/sddm.conf.d
    cat > "$KONF" <<EOF
# dibuat tams-dots - hapus file ini (atau: sudo bash theme/sddm.sh uninstall) untuk kembali ke bawaan
[Theme]
Current=$NAMA
CursorTheme=MacTahoe-light
CursorSize=24
EOF
    chmod 644 "$KONF"
    echo "SELESAI. Tema login $NAMA aktif mulai logout/restart berikutnya."
    echo "Lihat dulu tanpa logout:  sddm-greeter-qt6 --test-mode --theme $TUJUAN"
}

lepas() {
    rm -f "$KONF"
    echo "Tema login $NAMA dinonaktifkan (berlaku setelah logout/restart)."
}

case "${1:-install}" in
    install)   pasang "${2:-}" ;;
    uninstall) lepas ;;
    *) echo "Pakai: sudo bash $0 [install [file]|uninstall]"; exit 1 ;;
esac
