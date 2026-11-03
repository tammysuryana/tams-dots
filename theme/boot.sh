#!/bin/bash
# tams-dots: tema boot (menu GRUB + animasi startup Plymouth) bergaya logo Arch Linux.
#   sudo bash theme/boot.sh install     pasang
#   sudo bash theme/boot.sh uninstall   kembalikan seperti sebelum dipasang
# Aman dijalankan ulang. Bagian yang tidak ada di komputer ini (misal bootloader bukan GRUB) dilewati.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Jalankan dengan sudo:  sudo bash $0 ${1:-install}"; exit 1; }

DIR="$(cd "$(dirname "$0")" && pwd)"
NAMA=tams-dots
SIMPAN=/var/lib/tams-dots/boot        # catatan pengaturan lama, untuk uninstall
mkdir -p "$SIMPAN"

ok()   { echo "   ✓ $*"; }
skip() { echo "   - $*"; }

# Cari grub.cfg yang dipakai (Arch: /boot/grub, sebagian pakai /efi/grub atau /boot/efi/grub)
grub_cfg() {
    for f in /boot/grub/grub.cfg /efi/grub/grub.cfg /boot/efi/grub/grub.cfg; do
        [ -f "$f" ] && { echo "$f"; return; }
    done
    echo /boot/grub/grub.cfg
}

# Set KUNCI=nilai di /etc/default/grub (ganti kalau ada, tambah kalau belum ada)
set_grub() {
    if grep -qE "^#?\s*$1=" /etc/default/grub; then
        sed -i -E "s|^#?\s*$1=.*|$1=$2|" /etc/default/grub
    else
        echo "$1=$2" >> /etc/default/grub
    fi
}

rebuild_initramfs() {
    if command -v update-initramfs >/dev/null; then update-initramfs      # CachyOS
    elif command -v mkinitcpio >/dev/null; then mkinitcpio -P            # Arch
    elif command -v dracut >/dev/null; then dracut --regenerate-all -f    # EndeavourOS dll.
    else echo "   ! tidak tahu cara membangun ulang initramfs, lakukan manual"; fi
}

pakai_grub() { [ -f /etc/default/grub ] && command -v grub-mkconfig >/dev/null; }

install_grub() {
    echo "[GRUB] menu boot"
    if ! pakai_grub; then skip "bootloader bukan GRUB, dilewati"; return; fi
    [ -f "$SIMPAN/grub.default" ] || cp -a /etc/default/grub "$SIMPAN/grub.default"
    install -d -m 755 "/usr/share/grub/themes/$NAMA"
    cp -r "$DIR/grub/$NAMA/." "/usr/share/grub/themes/$NAMA/"
    set_grub GRUB_THEME "'/usr/share/grub/themes/$NAMA/theme.txt'"
    set_grub GRUB_DISTRIBUTOR "'Arch Linux'"
    set_grub GRUB_GFXMODE "auto"
    # "splash" perlu ada supaya animasi Plymouth tampil
    if command -v plymouth-set-default-theme >/dev/null && ! grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=.*\bsplash\b' /etc/default/grub; then
        sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=["'"'"'])/\1splash /' /etc/default/grub
    fi
    grub-mkconfig -o "$(grub_cfg)"
    ok "tema GRUB $NAMA"
}

install_plymouth() {
    echo "[Plymouth] animasi startup"
    if ! command -v plymouth-set-default-theme >/dev/null; then skip "plymouth tidak terpasang, dilewati"; return; fi
    [ -f "$SIMPAN/plymouth-theme" ] || plymouth-set-default-theme > "$SIMPAN/plymouth-theme"
    install -d -m 755 "/usr/share/plymouth/themes/$NAMA"
    cp -r "$DIR/plymouth/$NAMA/." "/usr/share/plymouth/themes/$NAMA/"
    # Arch biasa: hook plymouth belum ada di mkinitcpio -> tambahkan setelah udev/systemd
    if [ -f /etc/mkinitcpio.conf ] && ! grep -qE '^HOOKS=.*\bplymouth\b' /etc/mkinitcpio.conf; then
        [ -f "$SIMPAN/mkinitcpio.conf" ] || cp -a /etc/mkinitcpio.conf "$SIMPAN/mkinitcpio.conf"
        sed -i -E '/^HOOKS=/ s/\b(systemd|udev)\b/\1 plymouth/' /etc/mkinitcpio.conf
        ok "hook plymouth ditambahkan ke /etc/mkinitcpio.conf"
    fi
    plymouth-set-default-theme "$NAMA"
    rebuild_initramfs
    ok "tema Plymouth $NAMA"
}

uninstall_all() {
    echo "[GRUB]"
    if [ -f "$SIMPAN/grub.default" ] && pakai_grub; then
        cp -a "$SIMPAN/grub.default" /etc/default/grub
        grub-mkconfig -o "$(grub_cfg)"
        ok "pengaturan GRUB lama dikembalikan"
    else skip "tidak ada yang perlu dikembalikan"; fi
    echo "[Plymouth]"
    if [ -f "$SIMPAN/mkinitcpio.conf" ]; then cp -a "$SIMPAN/mkinitcpio.conf" /etc/mkinitcpio.conf; fi
    if [ -f "$SIMPAN/plymouth-theme" ] && command -v plymouth-set-default-theme >/dev/null; then
        plymouth-set-default-theme "$(cat "$SIMPAN/plymouth-theme")"
        rebuild_initramfs
        ok "tema Plymouth lama dikembalikan"
    else skip "tidak ada yang perlu dikembalikan"; fi
    rm -rf "$SIMPAN"
    echo "Folder tema di /usr/share dibiarkan (tidak dipakai, aman)."
}

case "${1:-install}" in
    install)   install_grub; install_plymouth; echo "SELESAI. Reboot untuk melihat hasilnya." ;;
    uninstall) uninstall_all; echo "SELESAI. Reboot untuk melihat tampilan lama." ;;
    *) echo "Pakai: sudo bash $0 [install|uninstall]"; exit 1 ;;
esac
