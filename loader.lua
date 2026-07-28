--[[
    HAVOC — Internal Bootstrapper (Modularized Version)
]]

print("[HAVOC] Bootstrapper loaded")

-- Re-loadable: tear down previous instance
if getgenv then
    local prev = getgenv().HAVOC_INTERNAL
    getgenv().HAVOC_INTERNAL = {}
    if type(prev) == "table" and type(prev.cleanup) == "function" then
        task.spawn(function()
            pcall(prev.cleanup)
        end)
    end
end

local HAVOC_PLACE_ID = 16530963934
if game.PlaceId ~= HAVOC_PLACE_ID then
    warn("[HAVOC] wrong place:", game.PlaceId, "need", HAVOC_PLACE_ID)
    return
end
print("[HAVOC] starting place", game.PlaceId)

local SVC = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    UIS = game:GetService("UserInputService"),
    RS = game:GetService("ReplicatedStorage"),
    MarketplaceService = game:GetService("MarketplaceService"),
    Lighting = game:GetService("Lighting"),
    HttpService = game:GetService("HttpService"),
    VIM = game:GetService("VirtualInputManager"),
}

if not game:IsLoaded() then game.Loaded:Wait() end

local LP = SVC.Players.LocalPlayer
if not LP then LP = SVC.Players.PlayerAdded:Wait() end

-- Shared context table initialized with default sub-tables to prevent nil index errors
local havoc = {
    scriptAlive = true,
    SVC = SVC,
    LP = LP,
    CFG = {},
    CACHE = { player = {}, entity = {}, loot = {}, exfil = {}, drops = {} },
    DrawPool = {},
    conns = {},
    BRAND = "monthonsova",
    BRAND_ICON = "rbxassetid://111627748770819",
    BRAND_DISCORD = "discord.gg/voidw0rld",
}

-- Loader helper that supports local testing (development) vs. GitHub loading (production)
local GITHUB_USER = "monthonsova"
local GITHUB_REPO = "havoc"
local GITHUB_BRANCH = "main"

local function loadModule(name)
    local compile = loadstring or load
    if not compile then
        error("[HAVOC] Environment missing loadstring/compile capabilities")
    end

    local src
    -- Check local file system first for rapid development/debugging
    if isfile and readfile then
        local localPath1 = "havoc/" .. name .. ".lua"
        local localPath2 = "havoc/src/" .. name .. ".lua"
        if isfile(localPath1) then
            src = readfile(localPath1)
        elseif isfile(localPath2) then
            src = readfile(localPath2)
        elseif isfile(name .. ".lua") then
            src = readfile(name .. ".lua")
        end
    end

    -- Fallback to GitHub raw files
    if not src then
        local pathPart = name
        if not pathPart:find("^src/") and name ~= "loader" then
            pathPart = "src/" .. name
        end
        local url = string.format("https://raw.githubusercontent.com/%s/%s/%s/%s.lua", GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH, pathPart)
        local ok, body = pcall(function()
            if type(game.HttpGetAsync) == "function" then
                return game:HttpGetAsync(url)
            end
            return game:HttpGet(url)
        end)
        if ok and type(body) == "string" and #body > 50 and body:sub(1, 1) ~= "<" then
            src = body
        else
            error(string.format("[HAVOC] Failed to load module %s from GitHub: %s", name, tostring(body)))
        end
    else
        print("[HAVOC] Loaded local file for module:", name)
    end

    local chunk, err = compile(src, "@havoc/" .. name)
    if not chunk then
        error(string.format("[HAVOC] Failed to compile module %s: %s", name, tostring(err)))
    end

    local ok, ret = pcall(chunk, havoc)
    if not ok then
        error(string.format("[HAVOC] Failed to run module %s: %s", name, tostring(ret)))
    end
    return ret
end

-- Import all modules safely
loadModule("src/config")
loadModule("src/utils")
loadModule("src/aimbot")
loadModule("src/mods")
loadModule("src/esp")
loadModule("src/menu")

-- ── Input and Keybind Connections ─────────────────────────────────────
local inputConn = SVC.UIS.InputBegan:Connect(function(io, gpe)
    local CFG = havoc.CFG or {}
    local changed = false
    if io.KeyCode == Enum.KeyCode.KeypadOne then CFG.playerAimEnabled = not CFG.playerAimEnabled; changed = true
    elseif io.KeyCode == Enum.KeyCode.KeypadTwo then CFG.npcAimEnabled = not CFG.npcAimEnabled; changed = true
    elseif io.KeyCode == Enum.KeyCode.KeypadThree then CFG.lootEnabled = not CFG.lootEnabled; changed = true
    elseif io.KeyCode == Enum.KeyCode.KeypadFour then CFG.exfilEnabled = not CFG.exfilEnabled; changed = true
    end
    if changed then
        if type(havoc.SaveConfig) == "function" then pcall(havoc.SaveConfig) end
        if type(havoc.cascadeUiSync) == "function" then
            pcall(havoc.cascadeUiSync)
        end
    end
    if gpe then return end
end)
table.insert(havoc.conns, inputConn)

-- ── Engine Loops and Task Spawns ──────────────────────────────────────
task.spawn(function()
    task.wait(1)
    if type(havoc.refreshLootCache) == "function" then pcall(havoc.refreshLootCache) end
    while havoc.scriptAlive do
        task.wait(15)
        if type(havoc.refreshLootCache) == "function" then pcall(havoc.refreshLootCache) end
    end
end)

task.spawn(function()
    while havoc.scriptAlive do
        if type(havoc.anyWeaponModEnabled) == "function" and havoc.anyWeaponModEnabled() then
            pcall(havoc.applyWeaponMods)
        end
        task.wait(2)
    end
end)

local renderConn1 = SVC.RunService.RenderStepped:Connect(function()
    if not havoc.scriptAlive then return end
    if type(havoc.tickWeaponRuntime) == "function" then
        pcall(havoc.tickWeaponRuntime)
    end
end)
table.insert(havoc.conns, renderConn1)

if type(havoc.setupWeaponModHooks) == "function" then
    pcall(havoc.setupWeaponModHooks)
end

local heartConn1 = SVC.RunService.Heartbeat:Connect(function(dt)
    if type(havoc.tickWorldCaches) == "function" then
        pcall(havoc.tickWorldCaches, dt)
    end
end)
table.insert(havoc.conns, heartConn1)

local heartConn2 = SVC.RunService.Heartbeat:Connect(function(dt)
    if type(havoc.renderEsp) == "function" then
        pcall(havoc.renderEsp, dt)
    end
end)
table.insert(havoc.conns, heartConn2)

-- Player feature watcher (throttled ~6Hz)
task.spawn(function()
    local acc = 0
    while havoc.scriptAlive do
        local dt = SVC.RunService.Heartbeat:Wait()
        acc = acc + dt
        if acc >= 0.16 then
            acc = 0
            local CFG = havoc.CFG or {}
            if CFG.autoLockpick and type(havoc.hasLockpickTool) == "function" and havoc.hasLockpickTool() and shared then
                shared.lockpick = true
            end
            if shared and shared.lockpicking and type(havoc.tryCompleteLockpick) == "function" then
                havoc.tryCompleteLockpick(true)
            end
            if type(havoc.installNetHooks) == "function" then
                pcall(havoc.installNetHooks)
            end
            if type(havoc.installSkillHooks) == "function" then
                pcall(havoc.installSkillHooks)
            end
            if CFG.autoSelfRevive and type(havoc.tryAutoSelfRevive) == "function" then
                pcall(havoc.tryAutoSelfRevive)
            end
            if CFG.autoFinisher and type(havoc.tryInstantFinisher) == "function" then
                local cachePlr = (havoc.CACHE and havoc.CACHE.player) or {}
                local cacheEnt = (havoc.CACHE and havoc.CACHE.entity) or {}
                pcall(havoc.tryInstantFinisher, cachePlr)
                pcall(havoc.tryInstantFinisher, cacheEnt)
            end
        end
    end
end)

pcall(function() SVC.RunService:UnbindFromRenderStep("HAVOC_AIM") end)
SVC.RunService:BindToRenderStep("HAVOC_AIM", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if type(havoc.aimStep) == "function" then
        havoc.aimStep(dt)
    end
end)

task.defer(function()
    local bc = type(havoc.getBaseCamera) == "function" and havoc.getBaseCamera()
    if bc then
        print("[HAVOC] Aimbot ready (BaseCamera) | Num1/2 toggle | RMB hold to lock")
    elseif havoc.moveMouseRel then
        print("[HAVOC] Aimbot ready (mouse fallback) | Num1/2 toggle | RMB hold to lock")
    else
        warn("[HAVOC] BaseCamera + mousemoverel missing — aimbot may not move camera")
    end
end)

if not Drawing or not Drawing.new then
    warn("[HAVOC] Drawing API missing — ESP overlay disabled (aim/mods still work)")
else
    print("[HAVOC] Drawing OK")
end
print("[HAVOC] core online | Num1/2/3/4 toggles | RMB hold aim | G = menu")

task.spawn(function()
    if type(havoc.ensureItemData) == "function" and havoc.ensureItemData() then
        print("[HAVOC] PriceDB ready")
    else
        warn("[HAVOC] PriceDB: itemData require failed — drop tags/tiers limited")
    end
end)

-- Register teardown
if getgenv then
    getgenv().HAVOC_INTERNAL = getgenv().HAVOC_INTERNAL or {}
    getgenv().HAVOC_INTERNAL.cleanup = function()
        havoc.scriptAlive = false
        if type(havoc.restoreSkillHooks) == "function" then pcall(havoc.restoreSkillHooks) end
        if type(havoc.restoreNetHooks) == "function" then pcall(havoc.restoreNetHooks) end
        if type(havoc.conns) == "table" then
            for i = 1, #havoc.conns do
                pcall(function() havoc.conns[i]:Disconnect() end)
            end
        end
        pcall(function() SVC.RunService:UnbindFromRenderStep("HAVOC_AIM") end)
        pcall(function() SVC.RunService:UnbindFromRenderStep("HAVOC_TIME") end)
        if type(havoc.DrawPool) == "table" then
            for _, pool in pairs(havoc.DrawPool) do
                if type(pool) == "table" then
                    for _, d in pairs(pool) do pcall(function() d:Remove() end) end
                end
            end
        end
        task.defer(function()
            pcall(function()
                if havoc.VoidUIWindow and havoc.VoidUIWindow.Destroy then
                    havoc.VoidUIWindow:Destroy()
                elseif havoc.CascadeGui and havoc.CascadeGui.Destroy then
                    havoc.CascadeGui:Destroy()
                elseif havoc.CascadeWindow and havoc.CascadeWindow.Destroy then
                    havoc.CascadeWindow:Destroy()
                end
            end)
        end)
    end
end
