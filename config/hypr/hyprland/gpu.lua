-- GPU utama untuk laptop dengan dua GPU (mis. Intel + NVIDIA).
--
-- Output yang bukan milik GPU utama harus di-blit tiap frame lewat buffer perantara
-- (log aquamarine: "EGL (blit) ... allocating intermediate buffer"), akibatnya layar
-- patah-patah dan Hyprland boros CPU. Aturan di sini:
--   1. GPU dengan layar tersambung terbanyak jadi utama.
--   2. Seri → GPU yang memegang layar eksternal (bukan panel laptop/eDP).
--   3. Tidak ada yang tersambung → GPU yang punya konektor eDP.
-- Dilewati kalau AQ_DRM_DEVICES sudah diset dari luar (uwsm env, custom/env.lua, dsb).

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*l")
    f:close()
    return s
end

local function list_dir(path)
    local out = {}
    local p = io.popen('ls -1 "' .. path .. '" 2>/dev/null')
    if not p then return out end
    for name in p:lines() do out[#out + 1] = name end
    p:close()
    return out
end

local function pick_primary_gpu()
    if os.getenv("AQ_DRM_DEVICES") and os.getenv("AQ_DRM_DEVICES") ~= "" then return nil end

    local cards = {}   -- card -> { connected = n, edp = bool }
    local order = {}
    for _, name in ipairs(list_dir("/sys/class/drm")) do
        local card, conn = name:match("^(card%d+)%-(.+)$")
        if card and conn and is_file_exists("/dev/dri/" .. card) then
            if not cards[card] then
                cards[card] = { connected = 0, edp = false }
                order[#order + 1] = card
            end
            local st = read_file("/sys/class/drm/" .. name .. "/status")
            if st == "connected" then cards[card].connected = cards[card].connected + 1 end
            if conn:match("^eDP") or conn:match("^LVDS") or conn:match("^DSI") then cards[card].edp = true end
        end
    end
    if #order < 2 then return nil end

    table.sort(order, function(a, b)
        local A, B = cards[a], cards[b]
        if A.connected ~= B.connected then return A.connected > B.connected end
        local total = 0
        for _, c in pairs(cards) do total = total + c.connected end
        if total > 0 then
            if A.edp ~= B.edp then return not A.edp end   -- seri: pilih yang pegang layar eksternal
        else
            if A.edp ~= B.edp then return A.edp end       -- tak ada layar: pilih yang punya panel
        end
        return a < b
    end)

    local devs = {}
    for i, c in ipairs(order) do devs[i] = "/dev/dri/" .. c end
    return table.concat(devs, ":")
end

local ok, devices = pcall(pick_primary_gpu)
if ok and devices then
    hl.env("AQ_DRM_DEVICES", devices)
end
