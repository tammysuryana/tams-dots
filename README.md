# tams-dots

**Desktop Hyprland siap pakai untuk Arch Linux**: bar & panel tams-shell, warna otomatis,
layar login dengan latar video bergerak, menu boot & animasi startup bergaya logo Arch.
Cukup satu perintah untuk memasang semuanya.

🇬🇧 English: [README.en.md](README.en.md)

---

## Daftar isi

1. [Bisa dipakai di komputer apa?](#1-bisa-dipakai-di-komputer-apa)
2. [Sebelum mulai](#2-sebelum-mulai)
3. [Istilah & cara mengetik perintah](#3-istilah--cara-mengetik-perintah)
4. [Install Arch Linux dulu (kalau belum)](#4-install-arch-linux-dulu-kalau-belum)
5. [Pasang tams-dots](#5-pasang-tams-dots)
6. [Setelah restart](#6-setelah-restart)
7. [Tombol pintas penting](#7-tombol-pintas-penting)
8. [Update, ubah, dan copot](#8-update-ubah-dan-copot)
9. [Kalau ada masalah](#9-kalau-ada-masalah)
10. [Lisensi & kredit](#10-lisensi--kredit)

---

## 1. Bisa dipakai di komputer apa?

| Komputer | Status |
|---|---|
| ✅ Laptop & PC desktop Intel / AMD (64-bit) | Didukung penuh |
| ✅ Kartu grafis Intel, AMD, NVIDIA seri GTX 16xx / RTX ke atas | Driver dipasang otomatis |
| ⚠️ NVIDIA lama (GTX 10xx ke bawah) | Bisa, tapi driver dipasang manual ([wiki NVIDIA](https://wiki.archlinux.org/title/NVIDIA)) |
| ✅ Monitor apa saja, 1 atau lebih | Otomatis memakai resolusi terbaik |
| ✅ Distro: **Arch Linux**, **CachyOS**, **EndeavourOS**, dan turunan Arch lainnya | Diuji di CachyOS |
| ⚠️ Mac Intel (sebelum akhir 2020) | Bisa, tapi WiFi/keyboard/touchpad sering butuh driver tambahan |
| 🧪 Mac Apple Silicon M1/M2 lewat [Asahi Linux versi Arch](https://asahi-alarm.org) | Eksperimental, belum diuji. Paket yang tidak ada untuk ARM dilewati |
| ❌ Mac M3/M4, Windows, Ubuntu/Fedora/Debian | Tidak didukung |

Nama pengguna bebas, tidak harus sama dengan pembuatnya.

---

## 2. Sebelum mulai

| Siapkan | Keterangan |
|---|---|
| Internet | Installer mengunduh ±3–5 GB |
| Waktu ±45–90 menit | Kebanyakan cuma menunggu download & build |
| Charger | Colokkan terus selama install |
| Arch Linux / CachyOS yang sudah terpasang | Kalau belum, lihat [bagian 4](#4-install-arch-linux-dulu-kalau-belum) |
| User biasa yang boleh `sudo` | Akun yang dibuat saat install Arch/CachyOS sudah otomatis boleh |

> 💡 Buka halaman ini di HP supaya bisa diikuti sambil install.

---

## 3. Istilah & cara mengetik perintah

| Istilah | Artinya |
|---|---|
| **Terminal** | Jendela tempat mengetik perintah |
| **Perintah** | Teks di kotak abu-abu. Ketik/tempel ke terminal lalu tekan **Enter** |
| **sudo** | "Jalankan sebagai admin", biasanya diikuti permintaan **password login** |
| **Tombol Super** | Tombol berlogo **Windows** di keyboard |
| **`~`** | Folder rumahmu, misalnya `/home/budi` |

- Menempel di terminal: **`Ctrl + Shift + V`** (bukan `Ctrl + V`).
- **Saat mengetik password, tulisannya memang tidak muncul sama sekali.** Ketik saja lalu Enter.
- Pertanyaan `[Y/n]`: langsung Enter = **ya**. Pertanyaan `[y/N]`: langsung Enter = **tidak**.
- Membatalkan perintah yang sedang jalan: `Ctrl + C`.

---

## 4. Install Arch Linux dulu (kalau belum)

Pilih salah satu. **CachyOS paling mudah** karena installernya bergambar (pakai mouse).

### Pilihan A — CachyOS (paling mudah)

1. Download ISO di <https://cachyos.org/download/>, tulis ke flashdisk pakai [Rufus](https://rufus.ie) (mode **DD**) atau [Ventoy](https://www.ventoy.net).
2. Colok flashdisk, nyalakan komputer sambil menekan tombol menu boot (`F12`, `F11`, `F8`, atau `Esc`, tergantung merek), pilih flashdisk.
3. Di desktop live, sambungkan WiFi, lalu klik **Launch Installer**. Pilihan penting:

   | Layar | Pilih |
   |---|---|
   | Bootloader | **GRUB** (supaya menu boot bergaya Arch bisa dipasang) |
   | Partisi | **Erase disk** ⚠️ menghapus semua isi disk |
   | Desktop | **Hyprland** (atau "No Desktop", tams-dots yang memasang sisanya) |
   | User | Nama & password bebas, **ingat passwordnya** |

4. Selesai → restart → cabut flashdisk → login.

### Pilihan B — Arch Linux (archinstall)

1. Download ISO di <https://archlinux.org/download/>, tulis ke flashdisk, boot seperti di atas.
2. Sambungkan internet (kabel otomatis; WiFi: ketik `iwctl`, lalu `station wlan0 connect NAMA-WIFI`).
3. Ketik `archinstall`, lalu pilih:

   | Menu | Pilih |
   |---|---|
   | Bootloader | **Grub** |
   | Profile | **Minimal** (tams-dots memasang desktopnya) |
   | Audio | **Pipewire** |
   | Network configuration | **Use NetworkManager** |
   | User account | buat user + password, centang **superuser (sudo)** |

4. **Install** → selesai → `reboot` → cabut flashdisk → login di layar teks.

---

## 5. Pasang tams-dots

1. Buka terminal. Di Hyprland: `Super + Enter`. Di layar teks (tanpa desktop) langsung ketik saja.
2. Kalau WiFi belum tersambung: ketik `nmtui` → **Activate a connection** → pilih WiFi → isi password.
3. Jalankan perintah ini satu per satu:

   ```bash
   sudo pacman -Syu --needed git
   git clone https://github.com/tammysuryana/tams-dots.git ~/tams-dots
   cd ~/tams-dots
   ./install.sh
   ```

   > ⚠️ **Jangan** pakai `sudo` di depan `./install.sh`. Installer sendiri yang minta password saat perlu.

4. Installer mengerjakan 8 tahap (`==> 1/8` sampai `8/8`). Biarkan berjalan. Di beberapa tempat dia bertanya:

   | Pertanyaan | Saran | Penjelasan |
   |---|---|---|
   | `[sudo] password for ...` | password login | Tulisan memang tidak muncul |
   | `Pasang driver grafis: ...?` | **Enter** (ya) | Tidak muncul di CachyOS (otomatis) |
   | `Pakai fish sebagai shell terminal ...?` | **Enter** (ya) | Terminal berwarna dengan saran perintah |
   | `Aktifkan SDDM sebagai layar login?` | **Enter** (ya) | Hanya muncul kalau belum ada layar login |
   | `Pasang layar login tams-dots (latar video bergerak)?` | **Enter** (ya) | |
   | `Langsung masuk desktop tanpa password saat nyala (autologin)?` | **Enter** (tidak) | Ketik `y` kalau mau langsung masuk tanpa password |
   | `Pasang tampilan boot logo Arch (menu GRUB + animasi startup)?` | **Enter** (ya) | Dilewati otomatis kalau bootloader bukan GRUB |

   Tidak mau ditanya-tanya? Pakai `./install.sh --yes` (semua dijawab pilihan yang disarankan).

5. Selesai kalau muncul kotak hijau **Selesai**. Tulisan kuning `!` = ada bagian yang dilewati, sisanya tetap terpasang.
   Kalau berhenti di tengah (internet putus dll.), **jalankan lagi** `./install.sh`. Aman diulang.

6. Restart:

   ```bash
   reboot
   ```

---

## 6. Setelah restart

Yang terlihat berurutan: menu boot **Arch Linux** → animasi logo Arch → **layar login dengan latar bergerak** → desktop.

1. Di layar login pastikan sesi **Hyprland** (klik tombol "Sesi" di kiri bawah untuk mengganti), lalu masuk.
2. Pertama kali masuk, wallpaper & warna dipasang otomatis dan muncul jendela sambutan.
3. Tekan **`Super + /`** untuk melihat semua tombol pintas.
4. Atur monitor kalau perlu: buka `nwg-displays`, atau `Super + Alt + P` untuk mode laptop/monitor luar.
5. Pengaturan tampilan (warna, bar, wallpaper): **`Super + Esc`**.

---

## 7. Tombol pintas penting

| Tombol | Fungsi |
|---|---|
| `Super` (tekan sekali) | Cari aplikasi |
| `Super + Enter` | Terminal |
| `Super + E` | File manager |
| `Super + W` | Browser |
| `Super + Q` | Tutup jendela |
| `Super + Tab` | Lihat semua jendela |
| `Super + Esc` | Pengaturan tams-shell |
| `Super + /` | **Contekan semua tombol** |
| `Super + Alt + P` | Mode layar (laptop / monitor luar / extend / mirror) |
| `Super + L` | Kunci layar |
| `Print Screen` | Screenshot (langsung tersalin) |
| `Ctrl + Alt + Delete` | Menu logout / restart / matikan |
| `Ctrl + Super + R` | Muat ulang shell (kalau bar/panel hilang) |
| `Ctrl + Alt + F3` | Layar teks darurat kalau tampilan macet |

---

## 8. Update, ubah, dan copot

**Update ke versi terbaru**: Pengaturan (`Super + Esc`) → **About** → **Update Dots**, atau lewat terminal:

```bash
cd ~/tams-dots && git pull && ./install.sh --update
```

`--update` hanya memperbarui shell dan config bawaan. Pengaturan pribadimu tetap.

**Tempat menaruh pengaturan pribadi** (tidak tertimpa saat update):

| Mau mengubah | File |
|---|---|
| Tombol pintas | `~/.config/hypr/custom/keybinds.lua` |
| Program yang jalan saat login | `~/.config/hypr/custom/execs.lua` |
| Variabel lingkungan | `~/.config/hypr/custom/env.lua` |
| Monitor | `~/.config/hypr/monitors.lua` (atau `nwg-displays`) |
| Shell fish (alias, PATH) | `~/.config/fish/conf.d/pribadi.fish` |

**Ganti latar layar login** dengan gambar atau video sendiri:

```bash
sudo bash ~/tams-dots/theme/sddm.sh install /lokasi/video-atau-gambar.mp4
```

**Copot tema login / boot** (kembali seperti semula):

```bash
sudo bash ~/tams-dots/theme/sddm.sh uninstall
sudo bash ~/tams-dots/theme/boot.sh uninstall
```

Pengaturan lama yang tertimpa saat install disimpan di `~/.tams-dots-backup-<tanggal>`.

---

## 9. Kalau ada masalah

| Masalah | Solusi |
|---|---|
| `Permission denied` saat `./install.sh` | `chmod +x ~/tams-dots/install.sh` lalu ulangi |
| Installer berhenti di tengah | Jalankan ulang `cd ~/tams-dots && ./install.sh` |
| `Tidak ada internet` | Sambungkan dulu: `nmtui` |
| Setelah login layar hitam / macet | `Ctrl + Alt + F3` → login → `hyprctl dispatch exit`. Belum pulih: `sudo systemctl restart sddm` |
| Bar/panel tidak muncul | Tekan `Ctrl + Super + R` (muat ulang shell), atau di terminal: `qs -c tams-shell` lalu baca pesan errornya |
| Layar patah-patah / game lambat | Driver grafis: CachyOS `sudo chwd -a`, Arch lihat [wiki](https://wiki.archlinux.org/title/Xorg#Driver_installation), lalu `reboot` |
| Layar login polos / video tidak bergerak | `sudo pacman -S --needed qt6-multimedia qt6-multimedia-ffmpeg` lalu `sudo bash ~/tams-dots/theme/sddm.sh install` |
| Warna tidak berubah saat ganti wallpaper | Bawaannya memakai skema warna tetap **Tokyo Night**. Ganti/matikan skema di Pengaturan (`Super + Esc`) bagian warna kalau mau warna mengikuti wallpaper |
| Menu boot tidak berubah | Bootloader bukan GRUB. Tema boot hanya untuk GRUB |
| Masih bingung | Buka [Issues](https://github.com/tammysuryana/tams-dots/issues) dan sertakan foto/teks pesan errornya |

---

## 10. Lisensi & kredit

tams-dots dirilis dengan lisensi **GNU GPL-3.0** ([LICENSE](LICENSE)). Kamu bebas memakai, mengubah, dan membagikan,
asalkan hasil ubahannya juga GPL-3.0 dan kredit ini tetap ada.

tams-dots dibangun dari karya open-source lain. Shell-nya turunan dari *illogical-impulse* (end-4) melalui fork pctrade,
dan tema bootnya turunan tema CachyOS. Daftar lengkap pembuat asli dan lisensinya ada di [NOTICE](NOTICE).
"Arch Linux" dan logonya adalah merek dagang Arch Linux. tams-dots bukan proyek resmi Arch Linux.

### Isi repo

```
install.sh                 installer
shell/                     tams-shell (quickshell) -> ~/.config/quickshell/tams-shell
config/                    pengaturan -> ~/.config (hypr, kitty, fish, matugen, tams-dots, ...)
assets/wallpapers/         wallpaper bawaan -> ~/.local/share/tams-dots/wallpapers
theme/sddm.sh, sddm/       layar login (panel kaca + latar video)
theme/boot.sh, grub/, plymouth/   menu boot & animasi startup
packages/                  daftar paket resmi, AUR, PKGBUILD lokal, paket python
```
