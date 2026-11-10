-- tams-dots: config utama Hyprland (format Lua). Memuat file di folder `hyprland`
-- (bawaan tams-dots) dan `custom` (punyamu). Taruh perubahanmu di file-file `custom/`,
-- karena folder `hyprland/` ditimpa saat update.

-- Internal --
require("hyprland/lib")
require("hyprland/services")

-- Environment variables --
require("hyprland/env")
require("hyprland/gpu") -- GPU utama otomatis untuk laptop dua GPU
if is_file_exists(HOME .. "/.config/hypr/custom/env.lua") then
    require("custom/env")
end

-- Default configurations --
require("hyprland/execs")
require("hyprland/general")
require("hyprland/rules")
require("hyprland/colors")
require("hyprland/keybinds")

-- Custom configurations --
if is_file_exists(HOME .. "/.config/hypr/custom/execs.lua") then
    require("custom/execs")
end
if is_file_exists(HOME .. "/.config/hypr/custom/general.lua") then
    require("custom/general")
end
if is_file_exists(HOME .. "/.config/hypr/custom/rules.lua") then
    require("custom/rules")
end
if is_file_exists(HOME .. "/.config/hypr/custom/keybinds.lua") then
    require("custom/keybinds")
end

-- nwg-displays support --
if is_file_exists(HOME .. "/.config/hypr/workspaces.lua") then
    require("workspaces")
end
if is_file_exists(HOME .. "/.config/hypr/monitors.lua") then
    require("monitors")
end
-- Mode tampilan ala Win+P (ditulis custom/scripts/display-mode.py), harus setelah monitors
if is_file_exists(HOME .. "/.config/hypr/custom/display-mode.lua") then
    require("custom/display-mode")
end

-- Shell overrides (ditulis oleh settings app tams-shell) --
if is_file_exists(HOME .. "/.config/hypr/hyprland/shellOverrides/animations.lua") then
    require("hyprland/shellOverrides/animations")
end
if is_file_exists(HOME .. "/.config/hypr/hyprland/shellOverrides/main.lua") then
    require("hyprland/shellOverrides/main")
end
