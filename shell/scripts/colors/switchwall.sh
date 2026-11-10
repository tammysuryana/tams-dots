#!/usr/bin/env bash

QUICKSHELL_CONFIG_NAME="tams-desktop"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG_FILE="$XDG_CONFIG_HOME/tams-desktop/config.json"
MATUGEN_DIR="$XDG_CONFIG_HOME/matugen"
terminalscheme="$SCRIPT_DIR/terminal/scheme-base.json"

# shellcheck source=../lib/config.sh
source "$SCRIPT_DIR/../lib/config.sh"

handle_kde_material_you_colors() {
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        enable_qt_apps=$(jq -r '.appearance.wallpaperTheming.enableQtApps' "$SHELL_CONFIG_FILE")
        if [ "$enable_qt_apps" == "false" ]; then
            return
        fi
    fi

    local kde_scheme_variant=""
    case "$type_flag" in
        scheme-content|scheme-expressive|scheme-fidelity|scheme-fruit-salad|scheme-monochrome|scheme-neutral|scheme-rainbow|scheme-tonal-spot)
            kde_scheme_variant="$type_flag"
            ;;
        *)
            kde_scheme_variant="scheme-tonal-spot"
            ;;
    esac
    "$XDG_CONFIG_HOME"/matugen/templates/kde/kde-material-you-colors-wrapper.sh --scheme-variant "$kde_scheme_variant"
}

# 2026-10-29 (tams): jangan paksa adw-gtk3; pakai tema GTK pilihan user dari gtk-3.0/settings.ini
keep_user_gtk_theme() {
    local t
    t=$(sed -n "s/^gtk-theme-name=//p" "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" 2>/dev/null | head -1)
    [[ -n "$t" ]] && gsettings set org.gnome.desktop.interface gtk-theme "$t"
}

pre_process() {
    local mode_flag="$1"
    if [[ "$mode_flag" == "dark" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
        keep_user_gtk_theme
    elif [[ "$mode_flag" == "light" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
        keep_user_gtk_theme
    fi

    if [ ! -d "$CACHE_DIR"/user/generated ]; then
        mkdir -p "$CACHE_DIR"/user/generated
    fi
}

post_process() {
    local screen_width="$1"
    local screen_height="$2"
    local wallpaper_path="$3"
    local colors_lock_flag="$4"

    if [[ -n "$colors_lock_flag" ]]; then
        return
    fi

    handle_kde_material_you_colors &
    "$SCRIPT_DIR/code/material-code-set-color.sh" &
}

apply_named_scheme() {
    local mode_flag="$1"
    local wallpaper_path="$2"
    python3 "$SCRIPT_DIR/named_scheme.py" \
        --scheme "$named_scheme" \
        --mode "$mode_flag" \
        --image "$wallpaper_path" \
        --primary "$named_primary" \
        --secondary "$named_secondary" \
        --scss "$STATE_DIR/user/generated/material_colors.scss" \
        --cache "$STATE_DIR/user/generated/color.txt" || {
            notify-send "Color scheme" "'$named_scheme' is invalid, going back to Material colors" -a "Shell"
            config_json_update "$SHELL_CONFIG_FILE" '.appearance.palette.namedScheme = ""'
            return 1
        }
    "$SCRIPT_DIR"/applycolor.sh
    apply_named_qt &
    "$SCRIPT_DIR/code/material-code-set-color.sh" &
}

apply_named_qt() {
    if [ -f "$SHELL_CONFIG_FILE" ] && [ "$(jq -r '.appearance.wallpaperTheming.enableQtApps' "$SHELL_CONFIG_FILE")" == "false" ]; then
        return
    fi
    command -v plasma-apply-colorscheme >/dev/null || return
    plasma-apply-colorscheme TamsNamed2 >/dev/null 2>&1
    plasma-apply-colorscheme TamsNamed >/dev/null 2>&1
}

check_and_prompt_upscale() {
    local img="$1"
    if [ -f "$SHELL_CONFIG_FILE" ] && [ "$(jq -r '.background.collage.enable // false' "$SHELL_CONFIG_FILE")" == "true" ]; then
        return
    fi
    min_width_desired="$(hyprctl monitors -j | jq '([.[].width] | max)' | xargs)"
    min_height_desired="$(hyprctl monitors -j | jq '([.[].height] | max)' | xargs)"

    if command -v identify &>/dev/null && [ -f "$img" ]; then
        local img_width img_height
        if is_video "$img"; then
            img_width=$min_width_desired
            img_height=$min_height_desired
        else
            img_width=$(identify -format "%w" "$img" 2>/dev/null)
            img_height=$(identify -format "%h" "$img" 2>/dev/null)
        fi
        if [[ "$img_width" -lt "$min_width_desired" || "$img_height" -lt "$min_height_desired" ]]; then
            action=$(notify-send "Upscale?" \
                "Image resolution (${img_width}x${img_height}) is lower than screen resolution (${min_width_desired}x${min_height_desired})" \
                -A "open_upscayl=Open Upscayl"\
                -a "Wallpaper switcher")
            if [[ "$action" == "open_upscayl" ]]; then
                if command -v upscayl &>/dev/null; then
                    nohup upscayl > /dev/null 2>&1 &
                else
                    action2=$(notify-send \
                        -a "Wallpaper switcher" \
                        -c "im.error" \
                        -A "install_upscayl=Install Upscayl (Arch)" \
                        "Install Upscayl?" \
                        "yay -S upscayl-bin")
                    if [[ "$action2" == "install_upscayl" ]]; then
                        kitty -1 yay -S upscayl-bin
                        if command -v upscayl &>/dev/null; then
                            nohup upscayl > /dev/null 2>&1 &
                        fi
                    fi
                fi
            fi
        fi
    fi
}

CUSTOM_DIR="$XDG_CONFIG_HOME/hypr/custom"
RESTORE_SCRIPT_DIR="$CUSTOM_DIR/scripts"
RESTORE_SCRIPT="$RESTORE_SCRIPT_DIR/__restore_video_wallpaper.sh"
THUMBNAIL_DIR="$RESTORE_SCRIPT_DIR/mpvpaper_thumbnails"
MPVPAPER_FLAGS="-p"
VIDEO_OPTS="no-audio loop hwdec=auto scale=bilinear interpolation=no video-sync=display-resample panscan=1.0 video-scale-x=1.0 video-scale-y=1.0 video-align-x=0 video-align-y=0 load-scripts=no"
# video-align 0 = tengah (0.5 = setengah ke kanan-bawah, bikin crop/fit melenceng)
# One control socket per output, so the shell can pause and resume the live
# wallpaper instead of only being able to kill it.
MPV_SOCKET_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
MPV_SOCKET_PREFIX="$MPV_SOCKET_DIR/mpvpaper-"

# Live wallpaper yang lebih besar dari layar (mis. 4K 60fps di layar 1080p) dibuat ulang
# seukuran layar terbesar dan maksimal LIVE_WALL_MAX_FPS, lalu disimpan di cache.
# Dekode, scaling, dan blit antar-GPU jadi jauh lebih ringan; file asli tidak disentuh.
# Matikan dengan LIVE_WALL_OPTIMIZE=0, ubah batas fps lewat LIVE_WALL_MAX_FPS.
LIVE_WALL_OPTIMIZE="${LIVE_WALL_OPTIMIZE:-1}"
LIVE_WALL_MAX_FPS="${LIVE_WALL_MAX_FPS:-30}"
LIVE_WALL_CACHE="$CACHE_DIR/live-wallpaper"

live_wall_target_size() {
    # Layar terbesar dalam piksel fisik: "lebar tinggi"
    hyprctl monitors -j 2>/dev/null | jq -r 'max_by(.width * .height) | "\(.width) \(.height)"' 2>/dev/null
}

live_wall_encode() {
    # $1 sumber, $2 keluaran, $3 filter video. Coba NVENC, lalu VA-API, lalu libx264.
    local src="$1" out="$2" vf="$3" dev
    local base=(-y -hide_banner -loglevel error -nostdin)
    ffmpeg "${base[@]}" -i "$src" -an -vf "$vf,format=yuv420p" -c:v h264_nvenc -preset p4 -rc vbr -cq 27 -b:v 0 -movflags +faststart "$out" 2>/dev/null && return 0
    for dev in /dev/dri/renderD*; do
        [ -e "$dev" ] || continue
        ffmpeg "${base[@]}" -vaapi_device "$dev" -i "$src" -an -vf "$vf,format=nv12,hwupload" -c:v h264_vaapi -qp 25 -movflags +faststart "$out" 2>/dev/null && return 0
    done
    ffmpeg "${base[@]}" -i "$src" -an -vf "$vf,format=yuv420p" -c:v libx264 -preset veryfast -crf 25 -movflags +faststart "$out" 2>/dev/null
}

optimize_live_wallpaper() {
    # Mengembalikan path video yang akan diputar: hasil optimasi di cache, atau sumber asli.
    local src="$1"
    [[ "$LIVE_WALL_OPTIMIZE" == "1" ]] || { echo "$src"; return; }
    command -v ffprobe >/dev/null && command -v ffmpeg >/dev/null || { echo "$src"; return; }

    local probe sw sh sfps
    probe=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of default=noprint_wrappers=1 "$src" 2>/dev/null) || { echo "$src"; return; }
    sw=$(sed -n 's/^width=//p' <<<"$probe"); sh=$(sed -n 's/^height=//p' <<<"$probe")
    sfps=$(sed -n 's/^r_frame_rate=//p' <<<"$probe" | awk -F/ '{ if ($2 > 0) printf "%.0f", $1 / $2; else printf "%.0f", $1 }')
    [[ "$sw" =~ ^[0-9]+$ && "$sh" =~ ^[0-9]+$ && "$sfps" =~ ^[0-9]+$ ]] || { echo "$src"; return; }

    local tw th
    read -r tw th < <(live_wall_target_size)
    [[ "$tw" =~ ^[0-9]+$ && "$th" =~ ^[0-9]+$ ]] || { echo "$src"; return; }
    local tfps="$LIVE_WALL_MAX_FPS"
    (( sfps < tfps )) && tfps="$sfps"

    # Sudah muat di layar dan fps tidak melebihi batas: pakai apa adanya
    if (( sw <= tw && sh <= th && sfps <= LIVE_WALL_MAX_FPS )); then echo "$src"; return; fi

    local key out tmp
    key=$(printf '%s|%s' "$src" "$(stat -c '%s|%Y' "$src" 2>/dev/null)" | md5sum | cut -c1-10)
    out="$LIVE_WALL_CACHE/$(basename "${src%.*}")-${key}-${tw}x${th}p${tfps}.mp4"
    [[ -s "$out" ]] && { echo "$out"; return; }

    mkdir -p "$LIVE_WALL_CACHE"
    notify-send -a "Wallpaper switcher" "Mengoptimalkan live wallpaper" \
        "${sw}x${sh} ${sfps}fps → maks ${tw}x${th} ${tfps}fps supaya ringan. Tunggu sebentar…" 2>/dev/null
    tmp="$out.tmp.mp4"
    if live_wall_encode "$src" "$tmp" "scale=${tw}:${th}:force_original_aspect_ratio=decrease:force_divisible_by=2,fps=${tfps}"; then
        mv -f "$tmp" "$out"
        # Buang hasil lama dari sumber yang sama (ukuran layar / batas fps berubah)
        find "$LIVE_WALL_CACHE" -maxdepth 1 -name "$(basename "${src%.*}")-${key}-*.mp4" ! -name "$(basename "$out")" -delete 2>/dev/null
        echo "$out"
    else
        rm -f "$tmp"
        notify-send -a "Wallpaper switcher" -c "im.error" "Gagal mengoptimalkan live wallpaper" "Memutar file asli." 2>/dev/null
        echo "$src"
    fi
}

is_video() {
    local extension="${1##*.}"
    [[ "$extension" == "mp4" || "$extension" == "webm" || "$extension" == "mkv" || "$extension" == "avi" || "$extension" == "mov" ]] && return 0 || return 1
}

kill_existing_mpvpaper() {
    pkill -f -9 mpvpaper || true
}

# 1 kalau video lebih lebar daripada tinggi (landscape). Dipakai untuk memilih crop/fit per layar.
video_is_landscape() {
    local wh
    wh=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$1" 2>/dev/null | head -1)
    [[ "$wh" =~ ^([0-9]+),([0-9]+) ]] && (( BASH_REMATCH[1] >= BASH_REMATCH[2] )) && echo 1 || echo 0
}

# Opsi mpvpaper untuk satu layar: layar yang orientasinya sama dengan video di-crop penuh
# (panscan=1), layar yang beda (mis. monitor diputar tegak, video lebar) memakai fit di tengah
# (panscan=0, bilah hitam) supaya gambarnya tidak terpotong.
# $1 = nama monitor, $2 = 1 bila video landscape. Butuh hyprctl.
mpv_opts_for_monitor() {
    local monitor=$1 landscape=$2 transform portrait=0 panscan=1.0
    transform=$(hyprctl monitors -j 2>/dev/null | jq -r --arg m "$monitor" '.[] | select(.name==$m) | .transform' 2>/dev/null)
    [[ "$transform" == "1" || "$transform" == "3" || "$transform" == "5" || "$transform" == "7" ]] && portrait=1
    [[ "$portrait" == "1" && "$landscape" == "1" ]] && panscan=0
    [[ "$portrait" == "0" && "$landscape" == "0" ]] && panscan=0
    echo "${VIDEO_OPTS/panscan=1.0/panscan=$panscan}"
}

create_restore_script() {
    local video_path=$1
    local landscape
    landscape=$(video_is_landscape "$video_path")
    cat > "$RESTORE_SCRIPT.tmp" << EOF
#!/bin/bash
# Generated by switchwall.sh - Don't modify it by yourself.
# Time: $(date)
VIDEO_OPTS="$VIDEO_OPTS"
# video-align 0 = tengah (0.5 = setengah ke kanan-bawah, bikin crop/fit melenceng)
VIDEO_LANDSCAPE=$landscape
$(declare -f mpv_opts_for_monitor)

# Mode "pastikan": nyalakan mpvpaper hanya untuk monitor yang belum punya, matikan yang
# monitornya sudah hilang. Aman dipanggil berulang (saat login, colok/cabut HDMI).
# --restart: matikan semua dulu lalu nyalakan ulang.
if [ "\$1" = "--restart" ]; then
    pkill -f -9 mpvpaper
    rm -f "$MPV_SOCKET_PREFIX"*.sock
fi
monitors=\$(hyprctl monitors -j | jq -r '.[] | .name')
for pid in \$(pgrep -x mpvpaper); do
    mon=\$(tr '\\0' ' ' < /proc/\$pid/cmdline | grep -oE 'mpvpaper-[^ ]+\\.sock' | sed 's/^mpvpaper-//; s/\\.sock$//')
    [ -n "\$mon" ] && grep -qx "\$mon" <<< "\$monitors" && continue
    kill -9 "\$pid" 2>/dev/null; [ -n "\$mon" ] && rm -f "$MPV_SOCKET_PREFIX\$mon.sock"
done
for monitor in \$monitors; do
    opts=\$(mpv_opts_for_monitor "\$monitor" "\$VIDEO_LANDSCAPE")
    pid=\$(pgrep -f "input-ipc-server=$MPV_SOCKET_PREFIX\$monitor.sock" | head -1)
    if [ -n "\$pid" ]; then
        # Sudah jalan: biarkan, kecuali crop/fit-nya tidak lagi sesuai orientasi layar (layar diputar)
        want=\$(grep -oE 'panscan=[0-9.]+' <<< "\$opts"); have=\$(tr '\\0' ' ' < /proc/\$pid/cmdline | grep -oE 'panscan=[0-9.]+')
        [ "\$want" = "\$have" ] && continue
        kill -9 "\$pid" 2>/dev/null
    fi
    rm -f "$MPV_SOCKET_PREFIX\$monitor.sock"
    mpvpaper $MPVPAPER_FLAGS -o "\$opts input-ipc-server=$MPV_SOCKET_PREFIX\$monitor.sock" "\$monitor" "$video_path" &
    sleep 0.1
done
EOF
    mv "$RESTORE_SCRIPT.tmp" "$RESTORE_SCRIPT"
    chmod +x "$RESTORE_SCRIPT"
}

remove_restore() {
    cat > "$RESTORE_SCRIPT.tmp" << EOF
#!/bin/bash
# The content of this script will be generated by switchwall.sh - Don't modify it by yourself.
EOF
    mv "$RESTORE_SCRIPT.tmp" "$RESTORE_SCRIPT"
}

set_wallpaper_path() {
    local path="$1"
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        config_json_update "$SHELL_CONFIG_FILE" --arg path "$path" '.background.wallpaperPath = $path'
    fi
}

set_thumbnail_path() {
    local path="$1"
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        config_json_update "$SHELL_CONFIG_FILE" --arg path "$path" '.background.thumbnailPath = $path'
    fi
}

categorize_wallpaper() {
    img_cat=$("$SCRIPT_DIR/../ai/gemini-categorize-wallpaper.sh" "$1")
    echo "$img_cat" > "$STATE_DIR/user/generated/wallpaper/category.txt"
}

switch() {
    imgpath="$1"
    mode_flag="$2"
    type_flag="$3"
    color_flag="$4"
    color="$5"
    colors_only_flag="$6"
    colors_lock_flag="$7"

    aiStylingEnabled=$(jq -r '.background.widgets.clock.cookie.aiStyling' "$SHELL_CONFIG_FILE")
    if [[ "$aiStylingEnabled" == "true" && -z "$colors_only_flag" ]]; then
        categorize_wallpaper "$imgpath" &
    fi

    read scale screenx screeny screensizey < <(hyprctl monitors -j | jq '.[] | select(.focused) | .scale, .x, .y, .height' | xargs)
    cursorposx=$(hyprctl cursorpos -j | jq '.x' 2>/dev/null) || cursorposx=960
    cursorposx=$(bc <<< "scale=0; ($cursorposx - $screenx) * $scale / 1")
    cursorposy=$(hyprctl cursorpos -j | jq '.y' 2>/dev/null) || cursorposy=540
    cursorposy=$(bc <<< "scale=0; ($cursorposy - $screeny) * $scale / 1")
    cursorposy_inverted=$((screensizey - cursorposy))

    matugen_args=(--source-color-index 0)

    if [[ "$color_flag" == "1" ]]; then
        matugen_args+=(color hex "$color")
        generate_colors_material_args=(--color "$color")
    else
        if [[ -z "$imgpath" ]]; then
            echo 'Aborted'
            exit 0
        fi

        # Toggle warna saja (--noswitch): jangan ganggu dengan prompt upscale wallpaper
        if [[ -z "$noswitch_flag" ]]; then
            check_and_prompt_upscale "$imgpath" &
        fi

        if [[ -z "$colors_only_flag" ]]; then
            kill_existing_mpvpaper
        fi

        if is_video "$imgpath"; then
            mkdir -p "$THUMBNAIL_DIR"

            missing_deps=()
            if ! command -v mpvpaper &> /dev/null; then
                missing_deps+=("mpvpaper")
            fi
            if ! command -v ffmpeg &> /dev/null; then
                missing_deps+=("ffmpeg")
            fi
            if [ ${#missing_deps[@]} -gt 0 ]; then
                echo "Missing deps: ${missing_deps[*]}"
                echo "Arch: sudo pacman -S ${missing_deps[*]}"
                action=$(notify-send \
                    -a "Wallpaper switcher" \
                    -c "im.error" \
                    -A "install_arch=Install (Arch)" \
                    "Can't switch to video wallpaper" \
                    "Missing dependencies: ${missing_deps[*]}")
                if [[ "$action" == "install_arch" ]]; then
                    kitty -1 sudo pacman -S "${missing_deps[*]}"
                    if command -v mpvpaper &>/dev/null && command -v ffmpeg &>/dev/null; then
                        notify-send 'Wallpaper switcher' 'Alright, try again!' -a "Wallpaper switcher"
                    fi
                fi
                exit 0
            fi

            if [[ -z "$colors_only_flag" ]]; then
                set_wallpaper_path "$imgpath"

                local video_path
                video_path=$(optimize_live_wallpaper "$imgpath")
                monitors=$(hyprctl monitors -j | jq -r '.[] | .name')
                rm -f "$MPV_SOCKET_PREFIX"*.sock
                local landscape
                landscape=$(video_is_landscape "$video_path")
                for monitor in $monitors; do
                    mpvpaper $MPVPAPER_FLAGS -o "$(mpv_opts_for_monitor "$monitor" "$landscape") input-ipc-server=$MPV_SOCKET_PREFIX$monitor.sock" "$monitor" "$video_path" &
                    sleep 0.1
                done
            fi

            thumbnail="$THUMBNAIL_DIR/$(basename "$imgpath").jpg"
            ffmpeg -y -i "$imgpath" -vframes 1 "$thumbnail" 2>/dev/null

            if [[ -z "$colors_only_flag" ]]; then
                set_thumbnail_path "$thumbnail"
            fi

            if [ -f "$thumbnail" ]; then
                matugen_args+=(image "$thumbnail")
                generate_colors_material_args=(--path "$thumbnail")
                if [[ -z "$colors_only_flag" ]]; then
                    create_restore_script "$video_path"
                fi
            else
                echo "Cannot create image to colorgen"
                if [[ -z "$colors_only_flag" ]]; then
                    remove_restore
                fi
                exit 1
            fi
        else
            matugen_args+=(image "$imgpath")
            generate_colors_material_args=(--path "$imgpath")
            if [[ -z "$colors_only_flag" ]]; then
                set_wallpaper_path "$imgpath"
                remove_restore
            fi
        fi
    fi

    if [[ -z "$mode_flag" ]]; then
        current_mode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
        if [[ "$current_mode" == "prefer-dark" ]]; then
            mode_flag="dark"
        else
            mode_flag="light"
        fi
    fi

    if [[ -n "$mode_flag" ]]; then
        matugen_args+=(--mode "$mode_flag")
        if [[ $(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode' "$SHELL_CONFIG_FILE") == "true" ]]; then
            generate_colors_material_args+=(--mode "dark")
        else
            generate_colors_material_args+=(--mode "$mode_flag")
        fi
    fi
    [[ -n "$type_flag" ]] && matugen_args+=(--type "$type_flag") && generate_colors_material_args+=(--scheme "$type_flag")
    generate_colors_material_args+=(--termscheme "$terminalscheme" --blend_bg_fg)
    generate_colors_material_args+=(--cache "$STATE_DIR/user/generated/color.txt")

    if [[ -n "$named_scheme" && -z "$noswitch_flag" && -z "$colors_lock_flag" ]]; then
        return
    fi

    pre_process "$mode_flag"

    if [ -f "$SHELL_CONFIG_FILE" ]; then
        enable_apps_shell=$(jq -r '.appearance.wallpaperTheming.enableAppsAndShell' "$SHELL_CONFIG_FILE")
        if [ "$enable_apps_shell" == "false" ]; then
            echo "App and shell theming disabled, skipping matugen and color generation"
            return
        fi
    fi

    if [ -f "$SHELL_CONFIG_FILE" ]; then
        harmony=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.harmony' "$SHELL_CONFIG_FILE")
        harmonize_threshold=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold' "$SHELL_CONFIG_FILE")
        term_fg_boost=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost' "$SHELL_CONFIG_FILE")
        [[ "$harmony" != "null" && -n "$harmony" ]] && generate_colors_material_args+=(--harmony "$harmony")
        [[ "$harmonize_threshold" != "null" && -n "$harmonize_threshold" ]] && generate_colors_material_args+=(--harmonize_threshold "$harmonize_threshold")
        [[ "$term_fg_boost" != "null" && -n "$term_fg_boost" ]] && generate_colors_material_args+=(--term_fg_boost "$term_fg_boost")
    fi

    colors_json_path="$STATE_DIR/user/generated/colors.json"
    if [[ -n "$named_scheme" && -z "$colors_lock_flag" ]]; then
        apply_named_scheme "$mode_flag" "$imgpath"
        return
    fi

    colors_lock_json_path="$STATE_DIR/user/generated/colors-lock.json"
    colors_lock_watch_paths=(
        "$colors_json_path"
        "$XDG_CONFIG_HOME/gtk-3.0/gtk.css"
        "$XDG_CONFIG_HOME/gtk-4.0/gtk.css"
    )
    colors_lock_backups=()
    if [[ -n "$colors_lock_flag" ]]; then
        for i in "${!colors_lock_watch_paths[@]}"; do
            watch_path="${colors_lock_watch_paths[$i]}"
            if [[ -f "$watch_path" ]]; then
                backup_path="$(mktemp)"
                cp "$watch_path" "$backup_path"
                colors_lock_backups[$i]="$backup_path"
            fi
        done
    fi

    matugen "${matugen_args[@]}"

    if [[ -n "$colors_lock_flag" ]]; then
        if [[ -f "$colors_json_path" ]]; then
            cp "$colors_json_path" "$colors_lock_json_path"
        fi
        for i in "${!colors_lock_watch_paths[@]}"; do
            watch_path="${colors_lock_watch_paths[$i]}"
            backup_path="${colors_lock_backups[$i]:-}"
            if [[ -n "$backup_path" ]]; then
                mv "$backup_path" "$watch_path"
            fi
        done
    fi

    source "$(eval echo $TAMS_DESKTOP_VENV)/bin/activate"

    if [[ -n "$colors_lock_flag" ]]; then
        output_scss="$STATE_DIR/user/generated/material_colors_lock.scss"
    else
        output_scss="$STATE_DIR/user/generated/material_colors.scss"
    fi

    python3 "$SCRIPT_DIR/generate_colors_material.py" "${generate_colors_material_args[@]}" \
        > "$output_scss"
    deactivate

    if [[ -z "$colors_lock_flag" ]]; then
        "$SCRIPT_DIR"/applycolor.sh
    fi

    max_width_desired="$(hyprctl monitors -j | jq '([.[].width] | min)' | xargs)"
    max_height_desired="$(hyprctl monitors -j | jq '([.[].height] | min)' | xargs)"
    post_process "$max_width_desired" "$max_height_desired" "$imgpath" "$colors_lock_flag"
}

main() {
    imgpath=""
    mode_flag=""
    type_flag=""
    color_flag=""
    color=""
    noswitch_flag=""
    colors_only_flag=""
    colors_lock_flag=""
    explicit_image=""
    start_dir_flag=""

    get_type_from_config() {
        jq -r '.appearance.palette.type' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "auto"
    }
    get_named_scheme_from_config() {
        jq -r '.appearance.palette.namedScheme // ""' "$SHELL_CONFIG_FILE" 2>/dev/null || echo ""
    }
    set_named_scheme() {
        local previous
        previous="$(get_named_scheme_from_config)"
        if [[ "$previous" != "$1" ]]; then
            config_json_update "$SHELL_CONFIG_FILE" --arg name "$1" \
                '.appearance.palette.namedScheme = $name | .appearance.palette.namedSchemePrimary = "" | .appearance.palette.namedSchemeSecondary = ""'
        fi
    }
    set_named_accent() {
        local slot="$1" value="$2"
        [[ "$value" == "clear" ]] && value=""
        config_json_update "$SHELL_CONFIG_FILE" --arg slot "$slot" --arg value "$value" \
            '.appearance.palette["namedScheme" + $slot] = $value'
    }
    get_named_accent_from_config() {
        jq -r --arg key "namedScheme$1" '.appearance.palette[$key] // ""' "$SHELL_CONFIG_FILE" 2>/dev/null || echo ""
    }
    get_accent_color_from_config() {
        jq -r '.appearance.palette.accentColor' "$SHELL_CONFIG_FILE" 2>/dev/null || echo ""
    }
    set_accent_color() {
        local color="$1"
        config_json_update "$SHELL_CONFIG_FILE" --arg color "$color" '.appearance.palette.accentColor = $color'
    }

    detect_scheme_type_from_image() {
        local img="$1"
        source "$(eval echo $TAMS_DESKTOP_VENV)/bin/activate"
        "$SCRIPT_DIR"/scheme_for_image.py "$img" 2>/dev/null | tr -d '\n'
        deactivate
    }

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mode)
                mode_flag="$2"
                shift 2
                ;;
            --type)
                type_flag="$2"
                shift 2
                ;;
            --color)
                if [[ "$2" =~ ^#?[A-Fa-f0-9]{6}$ ]]; then
                    set_accent_color "$2"
                    shift 2
                elif [[ "$2" == "clear" ]]; then
                    set_accent_color ""
                    shift 2
                else
                    set_accent_color $(hyprpicker --no-fancy)
                    shift
                fi
                ;;
            --scheme-name)
                if [[ "$2" == "clear" ]]; then
                    set_named_scheme ""
                else
                    set_named_scheme "$2"
                fi
                shift 2
                ;;
            --scheme-primary)
                set_named_accent Primary "$2"
                shift 2
                ;;
            --scheme-secondary)
                set_named_accent Secondary "$2"
                shift 2
                ;;
            --image)
                imgpath="$2"
                explicit_image="1"
                shift 2
                ;;
            --start-dir)
                start_dir_flag="$2"
                shift 2
                ;;
            --noswitch)
                noswitch_flag="1"
                if [[ -z "$imgpath" ]]; then
                    imgpath=$(jq -r '.background.wallpaperPath' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "")
                fi
                shift
                ;;
            --colors_lock)
                colors_lock_flag="1"
                colors_only_flag="1"
                noswitch_flag="1"
                if [[ -z "$imgpath" ]]; then
                    imgpath=$(jq -r '.background.wallpaperPath' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "")
                fi
                shift
                ;;
            *)
                if [[ -z "$imgpath" ]]; then
                    imgpath="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -n "$noswitch_flag" && -n "$explicit_image" ]]; then
        colors_only_flag="1"
    fi

    named_scheme="$(get_named_scheme_from_config)"
    if [[ -n "$named_scheme" && ! -f "$SCRIPT_DIR/schemes/$named_scheme.json" && ! -f "$(dirname "$SHELL_CONFIG_FILE")/schemes/$named_scheme.json" ]]; then
        echo "[switchwall.sh] Warning: Unknown named scheme '$named_scheme', ignoring" >&2
        named_scheme=""
    fi

    named_primary="$(get_named_accent_from_config Primary)"
    named_secondary="$(get_named_accent_from_config Secondary)"

    config_color="$(get_accent_color_from_config)"
    if [[ "$config_color" =~ ^#?[A-Fa-f0-9]{6}$ ]]; then
        color_flag="1"
        color="$config_color"
    fi

    if [[ -z "$type_flag" ]]; then
        type_flag="$(get_type_from_config)"
    fi

    allowed_types=(scheme-content scheme-expressive scheme-fidelity scheme-fruit-salad scheme-monochrome scheme-neutral scheme-rainbow scheme-tonal-spot auto)
    valid_type=0
    for t in "${allowed_types[@]}"; do
        if [[ "$type_flag" == "$t" ]]; then
            valid_type=1
            break
        fi
    done
    if [[ $valid_type -eq 0 ]]; then
        echo "[switchwall.sh] Warning: Invalid type '$type_flag', defaulting to 'auto'" >&2
        type_flag="auto"
    fi

    # Only prompt for wallpaper if not using --color and not using --noswitch and no imgpath set
    if [[ -z "$imgpath" && -z "$color_flag" && -z "$noswitch_flag" ]]; then
        if [[ -n "$start_dir_flag" && -d "$start_dir_flag" ]]; then
            cd "$start_dir_flag" || return 1
        else
            cd "$(xdg-user-dir PICTURES)/Wallpapers/showcase" 2>/dev/null || cd "$(xdg-user-dir PICTURES)/Wallpapers" 2>/dev/null || cd "$(xdg-user-dir PICTURES)" || return 1
        fi
        imgpath="$(kdialog --getopenfilename . --title 'Choose wallpaper')"
    fi

    if [[ -n "$imgpath" && -z "$noswitch_flag" ]]; then
        set_accent_color ""
        color_flag=""
        color=""
    fi

    if [[ "$type_flag" == "auto" ]]; then
        if [[ -n "$imgpath" && -f "$imgpath" ]]; then
            detected_type="$(detect_scheme_type_from_image "$imgpath")"
            valid_detected=0
            for t in "${allowed_types[@]}"; do
                if [[ "$detected_type" == "$t" && "$detected_type" != "auto" ]]; then
                    valid_detected=1
                    break
                fi
            done
            if [[ $valid_detected -eq 1 ]]; then
                type_flag="$detected_type"
            else
                echo "[switchwall] Warning: Could not auto-detect a valid scheme, defaulting to 'scheme-tonal-spot'" >&2
                type_flag="scheme-tonal-spot"
            fi
        else
            echo "[switchwall] Warning: No image to auto-detect scheme from, defaulting to 'scheme-tonal-spot'" >&2
            type_flag="scheme-tonal-spot"
        fi
    fi

    if [[ "$mode_flag" == "dark" || "$mode_flag" == "light" ]]; then
        local imgdir="$(dirname "$imgpath")"
        local imgbase="$(basename "$imgpath")"
        local imgname="${imgbase%.*}"
        local imgext="${imgbase##*.}"

        local stripped_name="${imgname%-dark}"
        stripped_name="${stripped_name%-light}"

        local new_imgpath="${imgdir}/${stripped_name}-${mode_flag}.${imgext}"
        local new_stripped_imgpath="${imgdir}/${stripped_name}.${imgext}"

        if [[ -f "$new_imgpath" ]]; then
            imgpath="$new_imgpath"
        elif [[ -f "$new_stripped_imgpath" ]]; then
            imgpath="$new_stripped_imgpath"
        fi
    fi

    switch "$imgpath" "$mode_flag" "$type_flag" "$color_flag" "$color" "$colors_only_flag" "$colors_lock_flag"
}

main "$@"