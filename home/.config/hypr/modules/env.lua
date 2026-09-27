-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │                                                                          │
-- │   E N V                                                                  │
-- │   environment variables                                                  │
-- │                                                                          │
-- │   github.com/andreumassanet/impasto                                      │
-- │                                                                          │
-- ╰──────────────────────────────────────────────────────────────────────────╯

hl.env("XCURSOR_SIZE",    "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- · cursor theme: a vector hyprcursor so shake-to-find (input.lua) magnifies
-- · it cleanly. The shell rebuilds it in the chosen colour; Bibata is the
-- · XCursor fallback. `./setup cursors` fetches both.
hl.env("HYPRCURSOR_THEME", "impasto-cursor")
hl.env("XCURSOR_THEME",    "Bibata-Modern-Classic")

-- · Qt platform theme; the palette push writes qt6ct's colour scheme.
-- · Quickshell draws from its own Theme.qml and is unaffected.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- · graphics card. Settings → Displays writes the chosen mode to gpu.tsv, and
-- · the devices behind it are resolved there; here it becomes the environment
-- · Aquamarine opens the DRM cards in. It opens them once, at startup, so a
-- · change applies on the next login and `hyprctl reload` cannot pick it up.
-- · "igpu" is the absence of a choice, and what a machine with no state file
-- · gets. IMPASTO_GPU_MODE tells the shell what this session was opened with.
local function gpu_state()
    local state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
    local values = {}
    local file = io.open(state .. "/quickshell/gpu.tsv")
    if not file then
        return values
    end
    for line in file:lines() do
        local key, value = line:match("^([^#\t][^\t]*)\t(%S+)$")
        if key then
            values[key] = value
        end
    end
    file:close()
    return values
end

local gpu = gpu_state()

hl.env("IMPASTO_GPU_MODE", gpu.mode or "igpu")

if gpu.mode == "hybrid" and gpu.render then
    -- · the desktop stays on the integrated card and the discrete one is left
    -- · out of Aquamarine's hands; single applications reach it themselves
    -- · through the PRIME variables `gpu.py offload` sets.
    hl.env("AQ_DRM_DEVICES", gpu.render)
elseif gpu.mode == "nvidia" and gpu.render then
    -- · `render` first: Aquamarine draws on the first device and scans out on
    -- · the rest. The discrete card is often a 3D controller with no outputs
    -- · of its own, which is what the second device is for.
    hl.env("AQ_DRM_DEVICES", gpu.accel and (gpu.render .. ":" .. gpu.accel) or gpu.render)
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("GBM_BACKEND", "nvidia-drm")
    hl.env("NVD_BACKEND", "direct")
    -- · video decoding is left where it was: the picture is scanned out on the
    -- · other card either way, and the integrated decoder is the one that
    -- · keeps working without libva-nvidia-driver.
    -- · the Nvidia cursor plane is not reliable under Aquamarine; draw the
    -- · cursor in software instead. `input.lua` owns the rest of the block.
    hl.config({ cursor = { no_hardware_cursors = true } })
end

-- · user folders from user-dirs.dirs, since their names are localised. Parsed
-- · directly because `xdg-user-dir` returns $HOME for an unset key.
local home   = os.getenv("HOME")
local config = os.getenv("XDG_CONFIG_HOME") or home .. "/.config"

local function user_dirs()
    local dirs = {}
    local file = io.open(config .. "/user-dirs.dirs")
    if not file then return dirs end
    for line in file:lines() do
        local name, value = line:match('^XDG_(%u+)_DIR="(.*)"$')
        if name then
            local rest = value:match("^%$HOME(.*)$")
            dirs[name] = (rest and home .. rest or value):gsub("\\(.)", "%1")
        end
    end
    file:close()
    return dirs
end

-- · capture folders, shared by the shell and hyprshot. XDG_SCREENSHOTS_DIR
-- · and XDG_SCREENCASTS_DIR in user-dirs.dirs override the defaults.
local dirs       = user_dirs()
local captures   = dirs.SCREENSHOTS or (dirs.PICTURES or home) .. "/Screenshots"
local recordings = dirs.SCREENCASTS or (dirs.VIDEOS or home) .. "/Screencasts"
hl.env("IMPASTO_CAPTURES",   captures)
hl.env("HYPRSHOT_DIR",       captures)
hl.env("IMPASTO_RECORDINGS", recordings)
