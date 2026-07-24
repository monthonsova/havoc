--[[
    HAVOC — Internal (Potassium / standard executor)
    Cascade UI · Drawing ESP · extraction shooter toolkit
    Vector version: Havoc/Vector.lua
]]

print("[HAVOC] chunk loaded")

-- Re-loadable: tear down previous instance in background (never block boot on Destroy/HttpGet).
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

local H = {}

local HAVOC_CONNS = {}
H.trackConn = function(c)
    if c then HAVOC_CONNS[#HAVOC_CONNS + 1] = c end
    return c
end

local BRAND = "voidw0rld"
local BRAND_ICON = "rbxassetid://111627748770819"
local BRAND_DISCORD = "discord.gg/voidw0rld"

local CFG = {
    entityEnabled = true,
    entityBox = true,
    entityName = true,
    entityDistance = true,
    entityHeldItem = true,
    entityHealthBar = true,
    entityHealthText = true,
    entitySkeleton = false,
    entityHideDead = true,
    entityMaxDist = 3000,

    playerEnabled = true,
    playerBox = true,
    playerName = true,
    playerDistance = true,
    playerHeldItem = true,
    playerHealthBar = true,
    playerSkeleton = true,
    playerMaxDist = 2500,

    lootEnabled = true,
    lootDistance = true,
    lootMarker = true,
    lootFilter = 1,
    lootMaxDist = 5000,
    lootTextSize = 14,

    exfilEnabled = true,
    exfilTimer = true,
    exfilNearestLine = false,
    exfilMaxDist = 4000,

    dropsEnabled = true,
    dropsMaxDist = 800,
    dropsTextSize = 14,
    dropsMarker = true,
    dropsShowValue = true,
    dropsMinValue = 0,
    -- PriceDB (itemData tier/sell + category tags)
    dropsShowTag = true,
    dropsShowTier = true,
    dropsColorByTier = true,
    dropsShowBuyPrice = false,
    dropsMinTier = 1,
    dropsFilterQuest = true,
    dropsFilterAmmo = true,
    dropsFilterMed = true,
    dropsFilterArmor = true,
    dropsFilterOther = true,

    questMarkerEnabled = true,
    questMaxDist = 5000,

    espVisibleCheck = true,
    espHiddenTint = true,
    espHideOccluded = false,
    entityTracer = false,
    playerTracer = false,

    timeMode = 1, -- 1=Auto 2=Force Day 3=Force Night 4=Custom
    customClockTime = 14,
    brightnessBoost = 50,

    hudEnabled = true,
    hudRaidTimer = true,
    hudCombat = true,
    hudLootSecured = true,
    hudExfilCount = true,
    hudAmmo = true,

    crosshair = false,

    radarEnabled = true,
    radarRadius = 90,
    radarMaxDist = 600,
    threatBehind = true,
    threatAiming = true,
    threatSound = false,
    threatMaxDist = 300,

    npcAimEnabled = false,
    npcAimBone = 1,
    npcAimFov = 150,
    npcAimSmooth = 4,
    npcAimMaxDist = 3000,
    npcAimDrawFov = true,
    npcAimTargetLine = false,
    npcAimTargetType = 1,
    npcAimPrediction = true,

    aimVisibleCheck = true,

    playerAimEnabled = false,
    playerAimBone = 1,
    playerAimFov = 150,
    playerAimSmooth = 3,
    playerAimMaxDist = 2000,
    playerAimPrediction = true,
    playerAimDrawFov = true,
    playerAimTargetLine = true,

    -- PvP: rewrite Network fire packet dir (camera stays free). Does NOT move camera.
    -- Works alongside aimbot (aimbot = move cam, silent = rewrite bullet). Use either or both.
    silentAim = false,
    silentAimFov = 220,
    silentAimMaxDist = 2000,
    silentAimBone = 1, -- 1=Head
    silentAimPrediction = true,
    silentAimRequireRmb = false,
    silentAimWallbang = false,
    -- Hipfire: game lerps barrel→camera by aimAlpha; ADS raises it. Force 1 = hipfire hits where you look.
    hipfireAccurate = false,

    featureHud = true,

    noRecoil = false,
    noSpread = false,
    trueNoSpread = false,
    noSway = false,
    fastVel = false,
    instantAds = false,
    noAimSway = false,

    playerInvPeek = true,
    playerInvMinValue = 0,

    owSprint = false,
    noWeightSpeed = false,
    infStamina = false,
    autoLockpick = false,
    autoSelfRevive = false,
    autoFinisher = false,
    noFall = false,
    noDrown = false,
}

local LOOT_TYPES = {
    { key = "medium_crate", match = "Medium Wooden Crate", display = "Medium Wooden Crate", enabled = true, color = Color3.fromRGB(210, 140, 70) },
    { key = "complex_crate", match = "Complex Crate", display = "Complex Crate", enabled = true, color = Color3.fromRGB(170, 120, 255) },
    { key = "military_crate", match = "Military Crate", display = "Military Crate", enabled = true, color = Color3.fromRGB(70, 200, 90) },
    { key = "wooden_crate", match = "Wooden Crate", display = "Wooden Crate", enabled = true, color = Color3.fromRGB(190, 130, 70) },
    { key = "weapon_locker", match = "Weapon Locker", display = "Weapon Locker", enabled = true, color = Color3.fromRGB(255, 110, 50) },
    { key = "weapon_box", match = { "Weapon Box", "XWeapon Box", "WeaponBox" }, display = "Weapon Box", enabled = true, color = Color3.fromRGB(255, 85, 55) },
    { key = "rifle_case", match = "Rifle Case", display = "Rifle Case", enabled = true, color = Color3.fromRGB(255, 150, 60) },
    { key = "pistol_case", match = "Pistol Case", display = "Pistol Case", enabled = true, color = Color3.fromRGB(255, 130, 70) },
    { key = "small_case", match = "Small Case", display = "Small Case", enabled = true, color = Color3.fromRGB(255, 175, 100) },
    { key = "ammunition_box", match = "Ammunition Box", display = "Ammunition Box", enabled = true, color = Color3.fromRGB(60, 190, 255) },
    { key = "technical_shelf", match = "Technical Shelf", display = "Technical Shelf", enabled = true, color = Color3.fromRGB(80, 200, 240) },
    { key = "tool_shelf", match = "Tool Shelf", display = "Tool Shelf", enabled = true, color = Color3.fromRGB(100, 185, 235) },
    { key = "toolbox", match = "Toolbox", display = "Toolbox", enabled = true, color = Color3.fromRGB(90, 175, 230) },
    { key = "medical_box", match = "Medical Box", display = "Medical Box", enabled = true, color = Color3.fromRGB(255, 70, 90) },
    { key = "safe", match = "Safe", display = "Safe", enabled = true, color = Color3.fromRGB(255, 220, 60) },
    { key = "cabinet", match = "Cabinet", display = "Cabinet", enabled = true, color = Color3.fromRGB(240, 190, 80) },
    { key = "cash_register", match = "Cash Register", display = "Cash Register", enabled = true, color = Color3.fromRGB(255, 210, 40) },
    { key = "duffel_bag", match = "Duffel Bag", display = "Duffel Bag", enabled = true, color = Color3.fromRGB(220, 170, 90) },
    { key = "backpack", match = "backpack", display = "Backpack", enabled = true, color = Color3.fromRGB(200, 155, 85) },
    { key = "closet", match = "Closet", display = "Closet", enabled = true, color = Color3.fromRGB(170, 170, 185) },
    { key = "computer", match = "Computer", display = "Computer", enabled = true, color = Color3.fromRGB(70, 240, 240) },
    { key = "server_unit", match = "Server Unit", display = "Server Unit", enabled = true, color = Color3.fromRGB(55, 220, 255) },
    { key = "powerbox", match = "PowerBox", display = "Power Box", enabled = true, color = Color3.fromRGB(255, 230, 70) },
    { key = "standing_atm", match = "StandingATM", display = "ATM", enabled = true, color = Color3.fromRGB(60, 255, 140) },
    { key = "locker", match = "Locker", display = "Locker", enabled = true, color = Color3.fromRGB(150, 160, 175) },
    { key = "tall_fridge", match = "Tall Fridge", display = "Tall Fridge", enabled = true, color = Color3.fromRGB(170, 220, 245) },
    { key = "fridge", match = "Fridge", display = "Fridge", enabled = true, color = Color3.fromRGB(185, 230, 250) },
    { key = "stove", match = "Stove", display = "Stove", enabled = true, color = Color3.fromRGB(150, 150, 155) },
    { key = "washing_machine", match = "Washing Machine", display = "Washing Machine", enabled = true, color = Color3.fromRGB(165, 195, 225) },
    { key = "dishwasher", match = "Dishwasher", display = "Dishwasher", enabled = true, color = Color3.fromRGB(155, 185, 215) },
    { key = "envelope", match = "Envelope", display = "Envelope", enabled = true, color = Color3.fromRGB(245, 225, 180) },
    { key = "explosive_barrel", match = "ExplosiveBarrel", display = "Explosive Barrel", enabled = true, color = Color3.fromRGB(255, 60, 20) },
    { key = "door", match = { "WoodenDoor", "DoubleGlassDoor", "DoubleMetalDoor", "MetalDoor", "GarageDoorLock" }, display = "Locked Door", enabled = true, color = Color3.fromRGB(160, 120, 90) },
    { key = "stash", match = { "Wooden Stash Box", "Stash" }, display = "Stash", enabled = true, color = Color3.fromRGB(180, 130, 75) },
    { key = "other", match = nil, display = "Other Loot", enabled = true, color = Color3.fromRGB(220, 220, 225) },
    { key = "body_bag", match = "__body_bag__", display = "Body Bag", enabled = true, color = Color3.fromRGB(120, 120, 130) },
}

for i = 1, #LOOT_TYPES do
    CFG["loot_" .. LOOT_TYPES[i].key] = LOOT_TYPES[i].enabled
end

local LOOT_TYPE_ID = {
    ["weapon.box"] = "weapon_box",
    ["weapon.locker"] = "weapon_locker",
    ["military.crate"] = "military_crate",
    ["complex.crate"] = "complex_crate",
    ["wooden.crate"] = "wooden_crate",
    ["medium.crate"] = "medium_crate",
    ["ammunition.box"] = "ammunition_box",
    ["medical.box"] = "medical_box",
    ["rifle.case"] = "rifle_case",
    ["pistol.case"] = "pistol_case",
}
for i = 1, #LOOT_TYPES do
    LOOT_TYPE_ID[LOOT_TYPES[i].key:gsub("_", ".")] = LOOT_TYPES[i].key
end

local LOOT_DRAW_PRIORITY = {
    weapon_box = 1,
    weapon_locker = 2,
    rifle_case = 3,
    pistol_case = 4,
    military_crate = 5,
    complex_crate = 6,
    safe = 7,
    ammunition_box = 8,
    medical_box = 9,
}

local CONFIG_DIR = "Nonny Services/Settings"
local CONFIG_PATH = CONFIG_DIR .. "/HAVOC_Settings.json"

H.configFsReady = function()
    return readfile and writefile and isfile and isfolder and makefolder
end

H.ensureConfigDir = function()
    if not H.configFsReady() then return false end
    if not isfolder("Nonny Services") then makefolder("Nonny Services") end
    if not isfolder(CONFIG_DIR) then makefolder(CONFIG_DIR) end
    return true
end

H.SaveConfig = function()
    if not H.ensureConfigDir() then return false end

    local payload = {}
    for k, v in pairs(CFG) do
        local t = type(v)
        if t == "boolean" or t == "number" or t == "string" then
            payload[k] = v
        end
    end

    local ok = pcall(function()
        writefile(CONFIG_PATH, SVC.HttpService:JSONEncode(payload))
    end)
    if ok then
        print("[HAVOC] Settings saved")
    else
        warn("[HAVOC] Settings save failed")
    end
    return ok
end

H.LoadConfig = function()
    if not H.ensureConfigDir() then return false end

    if not isfile(CONFIG_PATH) then
        H.SaveConfig()
        return false
    end

    local ok, decoded = pcall(function()
        return SVC.HttpService:JSONDecode(readfile(CONFIG_PATH))
    end)
    if not (ok and type(decoded) == "table") then
        warn("[HAVOC] Settings load failed")
        return false
    end

    for k, v in pairs(decoded) do
        if CFG[k] ~= nil then
            local dt = type(CFG[k])
            if dt == "boolean" then
                CFG[k] = v == true
            elseif dt == "number" then
                local n = tonumber(v)
                if n then CFG[k] = n end
            elseif dt == "string" and type(v) == "string" then
                CFG[k] = v
            end
        end
    end

    if CFG.timeMode then
        CFG.timeMode = math.clamp(math.floor(CFG.timeMode + 0.5), 1, 4)
    end

    -- Force-disable removed hitchy feature (saved configs may still have it on)
    CFG.noAimSway = false
    if CFG.radarRadius and CFG.radarRadius > 140 then
        CFG.radarRadius = 90
    end

    -- old bad default was 300 — migrate back to Vector-style 5000
    if tonumber(decoded.lootMaxDist) == 300 then
        CFG.lootMaxDist = 5000
        task.defer(H.SaveConfig)
    end

    print("[HAVOC] Settings loaded")
    return true
end

local configLoaded = false
pcall(function() configLoaded = H.LoadConfig() == true end)

pcall(function()
    game:BindToClose(function()
        H.SaveConfig()
    end)
end)

local BONE_NAMES = {
    "Head", "Torso", "UpperTorso", "LowerTorso",
    "Left Arm", "Right Arm", "Left Leg", "Right Leg",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
}
local SKELETON_R15 = {
    { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" }, { "UpperTorso", "RightUpperArm" },
    { "LeftUpperArm", "LeftLowerArm" }, { "RightUpperArm", "RightLowerArm" },
    { "LeftLowerArm", "LeftHand" }, { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" }, { "LowerTorso", "RightUpperLeg" },
    { "LeftUpperLeg", "LeftLowerLeg" }, { "RightUpperLeg", "RightLowerLeg" },
    { "LeftLowerLeg", "LeftFoot" }, { "RightLowerLeg", "RightFoot" },
}
local SKELETON_R6 = {
    { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
    { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

local HEAD_OFFSET = 2.6
local FOOT_OFFSET = 3.2
local PLAYER_MATCH_DIST = 5.0

local LOOT_SCAN_INTERVAL = 15
local loot_by_model = {}
local CACHE = { entity = {}, player = {}, loot = {}, exfil = {}, drops = {}, quest = {} }
local TSTAMP = { entity = 0, player = 0, playerInv = 0, loot = 0, exfil = 0, drops = 0, quest = 0 }
local characters_folder, buildings_folder = nil, nil
local hud_state = {}

local DrawPool = { texts = {}, lines = {}, squares = {}, circles = {} }
local usedDraw = { texts = {}, lines = {}, squares = {}, circles = {} }
local DRAW_USED = { text = "texts", line = "lines", square = "squares", circle = "circles" }
local ESP_INTERVAL = 1 / 20
local LOOT_LIVE_BATCH = 12
local loot_live_cursor = 1
local inv_price_cursor = 0
local DRAW_POOL_MAX = 350
local espAccum = 0

local CACHE_TICK = 0.2
local ENTITY_PRUNE_INTERVAL = 1.5
local ENTITY_RESCAN_INTERVAL = 5
local EXFIL_RESCAN_INTERVAL = 6
local PLAYER_RESCAN_INTERVAL = 1.5
local PLAYER_INV_RESCAN_INTERVAL = 4.0
local DROPS_RESCAN_INTERVAL = 4.5
local QUEST_RESCAN_INTERVAL = 4
local INV_PRICE_BATCH = 2
local QUEST_PLACEHOLDER = Vector3.new(10000, 10000, 10000)
local ENTITY_NODES_PER_TICK = 35
local cacheAccum = 0
local entityPruneStamp = 0
local entityRescanStamp = -5

H.beginDrawFrame = function()
    table.clear(usedDraw.texts)
    table.clear(usedDraw.lines)
    table.clear(usedDraw.squares)
    table.clear(usedDraw.circles)
end

H.finishDrawFrame = function()
    local pairsList = {
        { usedDraw.texts, DrawPool.texts },
        { usedDraw.lines, DrawPool.lines },
        { usedDraw.squares, DrawPool.squares },
        { usedDraw.circles, DrawPool.circles },
    }
    for i = 1, #pairsList do
        local used, pool = pairsList[i][1], pairsList[i][2]
        for key, d in pairs(pool) do
            if not used[key] then
                pcall(function() d.Visible = false end)
            end
        end
        local count = 0
        for _ in pairs(pool) do count = count + 1 end
        if count > DRAW_POOL_MAX then
            for key, d in pairs(pool) do
                if not used[key] then
                    pcall(function() d:Remove() end)
                    pool[key] = nil
                end
            end
        end
    end
end

H.instKey = function(inst)
    if not inst then return "nil" end
    return tostring(inst):gsub("%W", "_")
end

H.entDrawKey = function(prefix, ent)
    if ent.model then
        local plr = SVC.Players:GetPlayerFromCharacter(ent.model)
        if plr then return prefix .. plr.UserId end
    end
    return prefix .. H.instKey(ent.model)
end

H.safeDrawKey = function(key)
    return tostring(key):gsub("%W", "_")
end

H.posKey = function(pos)
    return string.format("%x_%x_%x", math.floor(pos.X * 0.1), math.floor(pos.Y * 0.1), math.floor(pos.Z * 0.1))
end

local CascadeApp = nil
local CascadeWindow = nil
local CascadeGui = nil
local cascadeNotifyFn = nil
local cascadeUiSync = nil

H.notify = function(title, content, _icon)
    if type(cascadeNotifyFn) == "function" then
        pcall(cascadeNotifyFn, title, content, 4)
        return
    end
    if CascadeApp and CascadeApp.Notification then
        pcall(function()
            CascadeApp:Notification({
                App = "HAVOC",
                Title = title or "HAVOC",
                Subtitle = content or "",
                Duration = 4,
            })
        end)
    end
end

H.syncMenuFromCfg = function()
    if type(cascadeUiSync) == "function" then
        pcall(cascadeUiSync)
    end
end

H.w2s = function(pos)
    local cam = workspace.CurrentCamera
    if not cam then return nil, false end
    local v = cam:WorldToViewportPoint(pos)
    if v.Z <= 0 then return nil, false end
    return Vector2.new(v.X, v.Y), true
end

H.camPos = function()
    local cam = workspace.CurrentCamera
    return cam and cam.CFrame.Position or Vector3.zero
end

H.screenCenter = function()
    local cam = workspace.CurrentCamera
    if not cam then return Vector2.new(960, 540) end
    local vs = cam.ViewportSize
    return Vector2.new(vs.X * 0.5, vs.Y * 0.5)
end

H.getDraw = function(kind, pool, key, factory)
    key = H.safeDrawKey(key)
    local usedBucket = DRAW_USED[kind]
    if usedBucket and usedDraw[usedBucket] then
        usedDraw[usedBucket][key] = true
    end
    local bucket = pool[key]
    if not bucket then
        bucket = factory()
        pool[key] = bucket
    end
    return bucket
end

H.drawText = function(key, pos, text, color, size, centered)
    if not Drawing or not Drawing.new then return end
    local d = H.getDraw("text", DrawPool.texts, key, function()
        local t = Drawing.new("Text")
        t.Center = true
        t.Outline = true
        return t
    end)
    d.Text = text
    d.Position = pos
    d.Color = color
    d.Size = size or 14
    d.Center = centered ~= false
    d.Visible = true
end

H.drawLine = function(key, a, b, color, thickness)
    if not Drawing or not Drawing.new then return end
    local d = H.getDraw("line", DrawPool.lines, key, function()
        local l = Drawing.new("Line")
        l.Thickness = 1
        return l
    end)
    d.From = a
    d.To = b
    d.Color = color
    d.Thickness = thickness or 1
    d.Visible = true
end

H.drawSquare = function(key, pos, size, color, filled, transparency)
    if not Drawing or not Drawing.new then return end
    local d = H.getDraw("square", DrawPool.squares, key, function()
        local s = Drawing.new("Square")
        s.Filled = false
        s.Thickness = 1
        return s
    end)
    d.Position = pos
    d.Size = size
    d.Color = color
    d.Filled = filled == true
    d.Transparency = transparency or 1
    d.Visible = true
end

H.drawCircle = function(key, center, radius, color, filled)
    if not Drawing or not Drawing.new then return end
    local d = H.getDraw("circle", DrawPool.circles, key, function()
        local c = Drawing.new("Circle")
        c.NumSides = 24
        c.Thickness = 1
        c.Filled = false
        return c
    end)
    d.Position = center
    d.Radius = radius
    d.Color = color
    d.Filled = filled == true
    d.Visible = true
end

H.nameMatches = function(name, pattern)
    if type(pattern) == "table" then
        for i = 1, #pattern do
            if string.find(name, pattern[i], 1, true) then return true end
        end
        return false
    end
    return pattern and string.find(name, pattern, 1, true) ~= nil
end

H.lootTypeEntry = function(lootTypeId)
    if not lootTypeId then return nil end
    local key = LOOT_TYPE_ID[lootTypeId]
    if not key then return nil end
    for i = 1, #LOOT_TYPES do
        if LOOT_TYPES[i].key == key then return LOOT_TYPES[i] end
    end
    return nil
end

H.categorizeLoot = function(name, lootTypeId)
    local byType = H.lootTypeEntry(lootTypeId)
    if byType then return byType end
    for i = 1, #LOOT_TYPES do
        local e = LOOT_TYPES[i]
        if e.match and e.match ~= "__body_bag__" and H.nameMatches(name, e.match) then
            return e
        end
    end
    return LOOT_TYPES[#LOOT_TYPES - 1]
end

H.getLootRoot = function(model)
    local pp = model.PrimaryPart
    if pp and pp:IsA("BasePart") then return pp end
    for _, partName in ipairs({ "Base", "Bottom", "Handle" }) do
        local part = model:FindFirstChild(partName)
        if part and part:IsA("BasePart") then return part end
    end
    return model:FindFirstChildWhichIsA("BasePart")
end

H.collectBodyParts = function(model)
    local parts, sizes = {}, {}
    for j = 1, #BONE_NAMES do
        local name = BONE_NAMES[j]
        local p = model:FindFirstChild(name, true)
        if p and p:IsA("BasePart") then
            parts[name] = p
            sizes[name] = p.Size
        end
    end
    return parts, sizes
end

H.resolveCharactersFolder = function()
    if characters_folder and characters_folder.Parent then return characters_folder end
    if shared and shared.charactersFolderName then
        characters_folder = workspace:FindFirstChild(shared.charactersFolderName)
        if characters_folder then return characters_folder end
    end
    characters_folder = workspace:FindFirstChild("Characters")
    if characters_folder then return characters_folder end
    for _, p in ipairs(SVC.Players:GetPlayers()) do
        if p.Character and p.Character.Parent and p.Character.Parent ~= workspace then
            characters_folder = p.Character.Parent
            return characters_folder
        end
    end
    return nil
end

H.isPlayerCharacter = function(model, root)
    for _, p in ipairs(SVC.Players:GetPlayers()) do
        if p.Character == model then return true end
        local pr = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if pr and (pr.Position - root.Position).Magnitude < PLAYER_MATCH_DIST then return true end
    end
    return false
end

-- ── Visibility / line-of-sight ───────────────────────────────────────
local visParams = RaycastParams.new()
visParams.FilterType = Enum.RaycastFilterType.Exclude
visParams.IgnoreWater = true
local visIgnore = {}
local visIgnoreStamp = 0

H.refreshVisIgnore = function()
    local now = tick()
    if now - visIgnoreStamp < 1 and #visIgnore > 0 then return end
    visIgnoreStamp = now
    local list = {}
    local function add(inst)
        if inst then list[#list + 1] = inst end
    end
    -- our own body must never block the ray
    add(LP.Character)
    -- every character (players + NPCs) is ignored so ONLY world geometry can occlude
    add(H.resolveCharactersFolder())
    for _, p in ipairs(SVC.Players:GetPlayers()) do
        add(p.Character)
    end
    -- effects / temp / dropped weld objects
    add(workspace:FindFirstChild("Ignored"))
    add(workspace:FindFirstChild("_weldobjects.temp.others"))
    add(workspace:FindFirstChild("_weldobjects.temp"))
    -- THE bug: the FPS viewmodel (arms/gun) + lockpick model live under the camera,
    -- they sit right in front of the ray origin and marked every target as occluded.
    add(workspace.CurrentCamera)
    visIgnore = list
    visParams.FilterDescendantsInstances = list
end

-- true = clear line of sight from fromPos to targetPos (world geometry only)
H.isVisible = function(targetPos, fromPos, ignoreModel)
    fromPos = fromPos or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position) or Vector3.zero
    H.refreshVisIgnore()
    local dir = targetPos - fromPos
    local mag = dir.Magnitude
    if mag < 4 then return true end
    local ok, res = pcall(workspace.Raycast, workspace, fromPos, dir, visParams)
    if not ok then return true end
    -- nothing between camera and target (all chars ignored) → clear line of sight
    if res == nil then return true end
    -- ray self-hit the target model (edge case: target not inside an ignored folder) → visible
    if ignoreModel and res.Instance and res.Instance:IsDescendantOf(ignoreModel) then return true end
    -- world geometry hit before reaching the target → occluded
    return false
end

-- ============================================================
--  Game feature hooks (module + network, no fragile input sim)
-- ============================================================
local scriptAlive = true

-- ---- characterSkills + stamina hooks ----
--   carry_speed penalty: applyWeightPenalty() subtracts getModifiedValue("carry_speed", penalty)
--   sprint drain:        u62.current -= getModifiedValue("stamina_consumption_rate", drainRate)
--   misc drains:         shared.staminaFunction("drain", amount)
-- DO NOT touch maximum_stamina — setting it huge breaks the stamina bar (current/max ≈ 0).
local skillsTbl, origIsUnlocked, origGetModified, origStaminaFn
H.installSkillHooks = function()
    if skillsTbl and origStaminaFn then return true end
    local ok, skills = pcall(function()
        local st = SVC.RS:WaitForChild("Storage", 10)
        local mods = st and st:WaitForChild("Modules", 10)
        local lib = mods and mods:WaitForChild("Library", 10)
        local cs = lib and lib:WaitForChild("characterSkills", 10)
        return cs and require(cs)
    end)
    if not ok or type(skills) ~= "table" then return false end
    if not skillsTbl then
        skillsTbl = skills
        if type(skills.isUnlocked) == "function" then
            origIsUnlocked = skills.isUnlocked
            skills.isUnlocked = function(plr, skill, ...)
                if scriptAlive and CFG.owSprint and skill == "iron_back" and plr == LP then
                    return true
                end
                return origIsUnlocked(plr, skill, ...)
            end
        end
        if type(skills.getModifiedValue) == "function" then
            origGetModified = skills.getModifiedValue
            skills.getModifiedValue = function(plr, key, base, ...)
                if scriptAlive and plr == LP then
                    if CFG.noWeightSpeed and key == "carry_speed" then return 0 end
                    if CFG.infStamina then
                        if key == "stamina_consumption_rate" then return 0 end
                        if key == "jump_stamina_cost" then return 0 end
                    end
                end
                return origGetModified(plr, key, base, ...)
            end
        end
    end
    if not origStaminaFn and shared and type(shared.staminaFunction) == "function" then
        origStaminaFn = shared.staminaFunction
        shared.staminaFunction = function(action, ...)
            if scriptAlive and CFG.infStamina and action == "drain" then return end
            return origStaminaFn(action, ...)
        end
    end
    return skillsTbl ~= nil
end
H.restoreSkillHooks = function()
    if skillsTbl then
        if origIsUnlocked then pcall(function() skillsTbl.isUnlocked = origIsUnlocked end) end
        if origGetModified then pcall(function() skillsTbl.getModifiedValue = origGetModified end) end
        skillsTbl, origIsUnlocked, origGetModified = nil, nil, nil
    end
    if origStaminaFn and shared then
        pcall(function() shared.staminaFunction = origStaminaFn end)
        origStaminaFn = nil
    end
end

-- ---- Auto Lockpick (instant, network) ----
-- Game flow: InvokeServer("interact",..., shared.lockpick) → {data, pattern, tool, session}
-- On legit success → FireServer("vars","lockpick",{lockType, data[, session]}).
-- Must have shared.lockpick=true + Lockpick tool equipped for server to return pattern.
local netTbl, origInvoke, pendingLockpick
H.hasLockpickTool = function()
    local bp = LP:FindFirstChild("Backpack")
    local ch = LP.Character
    return (bp and bp:FindFirstChild("Lockpick")) or (ch and ch:FindFirstChild("Lockpick"))
end
H.tryCompleteLockpick = function(force)
    local p = pendingLockpick
    if not p or not netTbl then return end
    if not force and tick() - p.t < 0.25 then return end
    pendingLockpick = nil
    pcall(function()
        local payload = { lockType = p.lockType, data = p.data }
        if p.session then payload.session = p.session end
        netTbl:FireServer("vars", "lockpick", payload)
    end)
    task.delay(0.15, function()
        pcall(function() shared.lockpicking = false end)
    end)
end
H.lockTypeOf = function(d)
    if typeof(d) ~= "Instance" then return nil end
    local function under(path)
        local node = workspace
        for seg in string.gmatch(path, "[^.]+") do
            node = node and node:FindFirstChild(seg)
        end
        return node and d:IsDescendantOf(node)
    end
    if under("Buildings.Loots.Doors") then return "door" end
    if under("Buildings.Loots.Loots.Crates") then return "loot" end
    if under("Buildings.Loots.Interactable.GarageDoors") then return "garageDoor" end
    return nil
end
local netTbl2, origFire
H.installNetHooks = function()
    if netTbl and origInvoke and origFire then return true end
    local net = shared and shared.Network
    if type(net) ~= "table" or type(net.InvokeServer) ~= "function" or type(net.FireServer) ~= "function" then
        return false
    end
    if not netTbl then netTbl, netTbl2 = net, net end
    if not origInvoke then
        origInvoke = net.InvokeServer
        net.InvokeServer = function(self, evName, ...)
            if scriptAlive and CFG.autoLockpick and evName == "interact" and H.hasLockpickTool() then
                shared.lockpick = true
            end
            local rets = table.pack(origInvoke(self, evName, ...))
            if scriptAlive and CFG.autoLockpick and evName == "interact" then
                local info = rets[2]
                if type(info) == "table" and typeof(info.data) == "Instance" and info.pattern then
                    local okLt, lt = pcall(H.lockTypeOf, info.data)
                    if okLt and lt then
                        pendingLockpick = {
                            lockType = lt,
                            data = info.data,
                            session = info.session,
                            t = tick(),
                        }
                        task.delay(0.35, function() H.tryCompleteLockpick(true) end)
                        task.delay(1.2, function() H.tryCompleteLockpick(true) end)
                    end
                end
            end
            return table.unpack(rets, 1, rets.n)
        end
    end
    if not origFire then
        origFire = net.FireServer
        net.FireServer = function(self, evName, a, b, c, ...)
            if scriptAlive and evName == "fire" then
                local origin, dir = b, c
                local nOrigin, nDir = H.applySilentFire(origin, dir)
                if nOrigin ~= nil or nDir ~= nil then
                    return origFire(self, evName, a, nOrigin or origin, nDir or dir, ...)
                end
                return origFire(self, evName, a, b, c, ...)
            end
            if scriptAlive and evName == "vars" then
                if CFG.noFall and a == "fall" then return end
                if CFG.noDrown and a == "drown" then return end
            end
            return origFire(self, evName, a, b, c, ...)
        end
    end
    return true
end
H.restoreNetHooks = function()
    if netTbl then
        if origInvoke then pcall(function() netTbl.InvokeServer = origInvoke end) end
        if origFire then pcall(function() netTbl2.FireServer = origFire end) end
        netTbl, netTbl2, origInvoke, origFire = nil, nil, nil, nil
    end
end

-- ---- Auto Self-Revive + Instant Finisher (network actions) ----
local INHALER_NAME = "RV11: Emergency Resuscitator Inhaler"
local selfReviving = false
H.localHumanoid = function()
    local char = LP.Character
    return char and char:FindFirstChildOfClass("Humanoid"), char
end
H.hasInhaler = function(char)
    local bp = LP:FindFirstChild("Backpack")
    return (bp and bp:FindFirstChild(INHALER_NAME)) or (char and char:FindFirstChild(INHALER_NAME))
end
H.tryAutoSelfRevive = function()
    if selfReviving or not netTbl then return end
    local hum, char = H.localHumanoid()
    if not (hum and hum:GetAttribute("Downed")) then return end
    if not H.hasInhaler(char) then return end
    selfReviving = true
    task.spawn(function()
        pcall(function() netTbl:InvokeServer("varsFunction", "selfRevive", { state = true }) end)
        local t = tick()
        while scriptAlive and CFG.autoSelfRevive and tick() - t < 15 do
            local h = H.localHumanoid()
            if not (h and h:GetAttribute("Downed")) then break end
            task.wait(0.3)
        end
        selfReviving = false
    end)
end
local finisherBusy = false
H.tryInstantFinisher = function(entities)
    if finisherBusy or not netTbl then return end
    local hum, char = H.localHumanoid()
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (hum and root and hum.Health > 0) then return end
    for i = 1, #entities do
        local ent = entities[i]
        local eh = ent.humanoid
        local em = ent.model
        if eh and em and eh.Health > 0 and eh:GetAttribute("Downed")
            and not eh:GetAttribute("Ragdoll") and not eh:GetAttribute("SpecialFinish") then
            local er = em:FindFirstChild("HumanoidRootPart") or eh.RootPart
            if er and (er.Position - root.Position).Magnitude <= 12 then
                finisherBusy = true
                task.spawn(function()
                    pcall(function() netTbl:InvokeServer("varsFunction", "finish_special", { target = em }) end)
                    task.wait(0.5)
                    finisherBusy = false
                end)
                return
            end
        end
    end
end

-- ---- gear toggle actions (fire on demand; requires the gear equipped) ----
H.fireGearToggle = function(sub)
    if not netTbl then return end
    pcall(function() netTbl:FireServer("vars", sub) end)
end

-- install with retry (shared.Network / Storage may not be ready at load)
task.spawn(function()
    for _ = 1, 80 do
        if not scriptAlive then return end
        H.installSkillHooks()
        H.installNetHooks()
        if skillsTbl and netTbl and origInvoke then return end
        task.wait(0.5)
    end
    warn("[HAVOC] hooks not fully installed — some Player features may be inactive")
end)

H.getPlayersList = function()
    local out, seen = {}, {}

    local function addEntry(model, displayName)
        if not model or seen[model] then return end
        local hum = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChild("UpperTorso")
            or model:FindFirstChildWhichIsA("BasePart")
        if hum and root and hum.Health > 0 then
            seen[model] = true
            local parts, sizes = H.collectBodyParts(model)
            out[#out + 1] = {
                model = model,
                root = root,
                humanoid = hum,
                parts = parts,
                part_size = sizes,
                name = displayName or model.Name,
            }
        end
    end

    for _, p in ipairs(SVC.Players:GetPlayers()) do
        if p ~= LP and p.Character then
            addEntry(p.Character, p.DisplayName ~= "" and p.DisplayName or p.Name)
        end
    end

    local folder = H.resolveCharactersFolder()
    if folder then
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("Model") then
                local plr = SVC.Players:GetPlayerFromCharacter(child)
                if plr and plr ~= LP then
                    addEntry(child, plr.DisplayName ~= "" and plr.DisplayName or plr.Name)
                elseif child ~= LP.Character then
                    for _, p in ipairs(SVC.Players:GetPlayers()) do
                        if p ~= LP and (child.Name == p.Name or child.Name == p.DisplayName) then
                            addEntry(child, p.DisplayName ~= "" and p.DisplayName or p.Name)
                            break
                        end
                    end
                end
            end
        end
    end

    return out
end

H.collectEntities = function(container, out, depth)
    if depth > 6 or not container then return end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Model") or child:IsA("WorldModel") then
            local hum = child:FindFirstChildOfClass("Humanoid")
            if hum then
                local root = child:FindFirstChild("HumanoidRootPart")
                    or child:FindFirstChild("Torso")
                    or child:FindFirstChild("UpperTorso")
                    or child:FindFirstChildWhichIsA("BasePart")
                if root and not H.isPlayerCharacter(child, root) then
                    local parts, sizes = H.collectBodyParts(child)
                    out[#out + 1] = { model = child, root = root, humanoid = hum, parts = parts, part_size = sizes }
                end
            else
                H.collectEntities(child, out, depth + 1)
            end
        elseif child:IsA("Folder") then
            H.collectEntities(child, out, depth + 1)
        end
    end
end

local entityScan = { stack = {}, out = {}, active = false }

H.addEntityModel = function(child)
    local hum = child:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local root = child:FindFirstChild("HumanoidRootPart")
        or child:FindFirstChild("Torso")
        or child:FindFirstChild("UpperTorso")
        or child:FindFirstChildWhichIsA("BasePart")
    if not root or H.isPlayerCharacter(child, root) then return end
    local parts, sizes = H.collectBodyParts(child)
    entityScan.out[#entityScan.out + 1] = {
        model = child, root = root, humanoid = hum, parts = parts, part_size = sizes,
    }
end

H.pushEntityScanFrame = function(depth, children)
    entityScan.stack[#entityScan.stack + 1] = { depth = depth, i = 1, children = children }
end

H.processEntityScanChild = function(child, depth)
    if depth > 6 then return end
    if child:IsA("Model") or child:IsA("WorldModel") then
        if child:FindFirstChildOfClass("Humanoid") then
            H.addEntityModel(child)
        else
            H.pushEntityScanFrame(depth + 1, child:GetChildren())
        end
    elseif child:IsA("Folder") then
        H.pushEntityScanFrame(depth + 1, child:GetChildren())
    end
end

H.beginEntityRescan = function()
    if entityScan.active then return end
    local root = H.resolveCharactersFolder()
    if not root then
        CACHE.entity = {}
        return
    end
    entityScan.active = true
    entityScan.out = {}
    entityScan.stack = { { depth = 0, i = 1, children = root:GetChildren() } }
end

H.stepEntityRescan = function(budget)
    if not entityScan.active then return end
    local left = budget
    while left > 0 and #entityScan.stack > 0 do
        local frame = entityScan.stack[#entityScan.stack]
        if frame.i > #frame.children then
            table.remove(entityScan.stack)
        else
            local child = frame.children[frame.i]
            frame.i = frame.i + 1
            left = left - 1
            H.processEntityScanChild(child, frame.depth)
        end
    end
    if #entityScan.stack == 0 then
        CACHE.entity = entityScan.out
        entityScan.active = false
    end
end

H.pruneEntityCache = function()
    if #CACHE.entity == 0 then return end
    local out = {}
    for i = 1, #CACHE.entity do
        local ent = CACHE.entity[i]
        local model = ent.model
        if model and model.Parent and ent.humanoid and ent.humanoid.Health > 0 then
            out[#out + 1] = ent
        end
    end
    CACHE.entity = out
end

H.getLootInfo = function(model)
    local data = model:FindFirstChild("data")
    if not (data and data:IsA("Configuration")) then
        data = model:FindFirstChild("data", true)
    end
    if not data or not data:IsA("Configuration") then return nil end
    local is_open = data:FindFirstChild("isOpen")
    local is_locked = data:FindFirstChild("isLocked")
    if not (is_open and is_locked) then return nil end
    local loot_type = data:FindFirstChild("lootType")
    return is_open, is_locked, loot_type and loot_type.Value or nil
end

local BODY_BAG_CATEGORY = nil
for i = 1, #LOOT_TYPES do
    if LOOT_TYPES[i].key == "body_bag" then
        BODY_BAG_CATEGORY = LOOT_TYPES[i]
        break
    end
end

H.getOrCreateLootEntry = function(model, root, category, is_open_inst, is_locked_inst)
    local entry = loot_by_model[model]
    if entry then
        entry.root = root
        entry.pos = root.Position
        return entry
    end
    entry = {
        model = model,
        root = root,
        pos = root.Position,
        category = category,
        is_open_inst = is_open_inst,
        is_locked_inst = is_locked_inst,
        is_open = is_open_inst and is_open_inst.Value or nil,
        is_locked = is_locked_inst and is_locked_inst.Value or nil,
    }
    loot_by_model[model] = entry
    return entry
end

H.collectLoot = function(container, out, depth, seen)
    if depth > 8 or not container then return end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Model") then
            if not seen[child] then
                local is_open, is_locked, loot_type = H.getLootInfo(child)
                if is_open then
                    local root = H.getLootRoot(child)
                    if root then
                        seen[child] = true
                        out[#out + 1] = H.getOrCreateLootEntry(child, root, H.categorizeLoot(child.Name, loot_type), is_open, is_locked)
                    end
                else
                    H.collectLoot(child, out, depth + 1, seen)
                end
            end
        elseif child:IsA("Folder") or child:IsA("WorldModel") then
            H.collectLoot(child, out, depth + 1, seen)
        end
    end
end

H.collectLootDeep = function(root, out, seen)
    if not root then return end
    local ok, descendants = pcall(function() return root:GetDescendants() end)
    if not ok or not descendants then return end
    for i = 1, #descendants do
        local inst = descendants[i]
        if inst:IsA("Model") and not seen[inst] then
            local is_open, is_locked, loot_type = H.getLootInfo(inst)
            if is_open then
                local partRoot = H.getLootRoot(inst)
                if partRoot then
                    seen[inst] = true
                    out[#out + 1] = H.getOrCreateLootEntry(inst, partRoot, H.categorizeLoot(inst.Name, loot_type), is_open, is_locked)
                end
            end
        end
        if i % 100 == 0 then task.wait() end
    end
end

H.collectBodyBags = function(buildings, out, seen)
    local loots1 = buildings:FindFirstChild("Loots")
    if not loots1 then return end
    local loots2 = loots1:FindFirstChild("Loots")
    if not loots2 then return end
    local characters = loots2:FindFirstChild("Characters")
    if not characters then return end

    for _, child in ipairs(characters:GetChildren()) do
        if child:IsA("Model") and not seen[child] then
            local root = child:FindFirstChildWhichIsA("BasePart")
            if root then
                seen[child] = true
                out[#out + 1] = H.getOrCreateLootEntry(child, root, BODY_BAG_CATEGORY or LOOT_TYPES[#LOOT_TYPES], nil, nil)
            end
        end
    end
end

-- Ground drops live in workspace.Ignored["_weldobjects.temp"] (literal name with dots).
H.getWeldTempFolder = function()
    local ignored = workspace:FindFirstChild("Ignored")
    return ignored and ignored:FindFirstChild("_weldobjects.temp")
end

H.resolveDropName = function(inst)
    local data = inst:FindFirstChild("_data") or inst:FindFirstChild("data")
    if data then
        for _, key in ipairs({ "displayName", "name", "itemName" }) do
            local nm = data:FindFirstChild(key)
            if nm and nm.Value ~= nil and tostring(nm.Value) ~= "" then
                return tostring(nm.Value)
            end
        end
    end
    return inst.Name
end

local priceFn
local itemDataMod -- Library.itemData (menu/raid shared)

H.TIER_ESP_COLORS = {
    common = Color3.fromRGB(190, 190, 190),
    uncommon = Color3.fromRGB(70, 210, 190),
    rare = Color3.fromRGB(190, 110, 255),
    contraband = Color3.fromRGB(220, 200, 70),
    mythic = Color3.fromRGB(255, 70, 70),
    usable = Color3.fromRGB(110, 220, 130),
    keys = Color3.fromRGB(230, 195, 70),
    cash = Color3.fromRGB(90, 255, 110),
}
H.TIER_LEVEL_COLORS = {
    [0] = Color3.fromRGB(90, 255, 110),
    [1] = Color3.fromRGB(190, 190, 190),
    [2] = Color3.fromRGB(70, 210, 190),
    [3] = Color3.fromRGB(190, 110, 255),
    [4] = Color3.fromRGB(255, 150, 210),
    [5] = Color3.fromRGB(255, 70, 70),
}
H.CAT_TAG = {
    ammo = "AMMO",
    mags = "AMMO",
    medical = "MED",
    armor = "ARMOR",
    helmet = "ARMOR",
    lower_armor = "ARMOR",
    mask = "ARMOR",
    backpack = "ARMOR",
}
H.DEFAULT_DROP_COL = Color3.fromRGB(255, 210, 80)

H.ensurePriceFn = function()
    if priceFn ~= nil then return priceFn ~= false end
    local ok, fn = pcall(function()
        if not shared.cachedModules then shared.cachedModules = {} end
        local storage = SVC.RS:WaitForChild("Storage", 8)
        return require(storage.Modules.Helper.getTotalPrice)
    end)
    priceFn = ok and fn or false
    return priceFn ~= false
end

H.ensureItemData = function()
    if itemDataMod ~= nil then return itemDataMod ~= false end
    local ok, mod = pcall(function()
        local storage = SVC.RS:WaitForChild("Storage", 8)
        return require(storage.Modules.Library.itemData)
    end)
    itemDataMod = (ok and type(mod) == "table" and mod) or false
    return itemDataMod ~= false
end

H.formatMoney = function(n)
    n = math.floor((n or 0) + 0.5)
    local s = tostring(math.abs(n))
    local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return n < 0 and "-" .. formatted or formatted
end

H.getDropValue = function(inst)
    if not inst or not H.ensurePriceFn() then return nil end
    local ok, val = pcall(priceFn, inst, 0, 0)
    if ok and type(val) == "number" then return math.floor(val + 0.5) end
    return nil
end

-- itemData.price is already trader sell value (buyPrice * sellMult), built in Library.itemData
H.lookupItemMeta = function(itemName)
    if not itemName or not H.ensureItemData() then return nil end
    local items = itemDataMod.items
    if type(items) ~= "table" then return nil end
    local def = items[itemName]
    if type(def) ~= "table" then return nil end

    local tier = def.tierData
    local tierType = (tier and tier.type) or "common"
    local tierLevel = (tier and tier.tierLevel) or 1
    local sellMult = (tier and tier.sellMult) or 0.27
    local cat = def.itemCategory
    local base = def.baseData
    local quest = (base and base.questItem == true) or false
    local tag = nil
    if quest then
        tag = "QUEST"
    elseif cat and H.CAT_TAG[cat] then
        tag = H.CAT_TAG[cat]
    end

    local col = H.TIER_ESP_COLORS[tierType] or H.TIER_LEVEL_COLORS[tierLevel] or H.DEFAULT_DROP_COL
    local sell = tonumber(def.price)
    local buy = tonumber(def.buyPrice)

    return {
        category = cat,
        tag = tag,
        quest = quest,
        tierType = tierType,
        tierLevel = tierLevel,
        sellMult = sellMult,
        sellPrice = sell and math.floor(sell + 0.5) or nil,
        buyPrice = buy and math.floor(buy + 0.5) or nil,
        color = col,
    }
end

H.dropPassesFilters = function(entry)
    if not entry then return false end
    local minVal = CFG.dropsMinValue or 0
    local val = entry.value
    if minVal > 0 then
        if val == nil or val < minVal then return false end
    end

    local meta = entry.meta
    local tierLevel = (meta and meta.tierLevel) or 1
    if tierLevel < (CFG.dropsMinTier or 1) then return false end

    local tag = meta and meta.tag
    if tag == "QUEST" then
        return CFG.dropsFilterQuest ~= false
    elseif tag == "AMMO" then
        return CFG.dropsFilterAmmo ~= false
    elseif tag == "MED" then
        return CFG.dropsFilterMed ~= false
    elseif tag == "ARMOR" then
        return CFG.dropsFilterArmor ~= false
    end
    return CFG.dropsFilterOther ~= false
end

H.enrichDropEntry = function(entry, child)
    if not entry then return end
    local name = entry.name or (child and child.Name)
    local meta = H.lookupItemMeta(name)
    if not meta and child and child.Name ~= name then
        meta = H.lookupItemMeta(child.Name)
    end
    entry.meta = meta

    if CFG.dropsShowValue then
        local cached = child and child:GetAttribute("_havocPrice")
        if typeof(cached) == "number" then
            entry.value = cached
        else
            local val = H.getDropValue(child)
            if val == nil and meta and meta.sellPrice then
                val = meta.sellPrice
            end
            entry.value = val
            if val and child then
                pcall(function() child:SetAttribute("_havocPrice", val) end)
            end
        end
    elseif meta and meta.sellPrice then
        entry.value = meta.sellPrice
    end
end

H.resolveObjectivePos = function(child)
    if child:IsA("Vector3Value") then return child.Value end
    if child:IsA("ObjectValue") and child.Value then
        local v = child.Value
        if typeof(v) == "Vector3" then return v end
        if typeof(v) == "Instance" then
            if v:IsA("BasePart") then return v.Position end
            if v:IsA("Model") then return v:GetPivot().Position end
        end
    end
    return nil
end

H.isValidObjectivePos = function(pos)
    if typeof(pos) ~= "Vector3" then return false end
    return (pos - QUEST_PLACEHOLDER).Magnitude > 100
end

H.parseObjectiveLabel = function(name)
    local s = name:gsub("-point$", "")
    local _, obj = s:match("^(.-)%-(.+)$")
    if obj then return obj:gsub("_", " ") end
    return s:gsub("_", " ")
end

H.getEquippedAmmo = function()
    local char = LP.Character
    if not char then return nil end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            local data = child:FindFirstChild("_data") or child:FindFirstChild("data")
            if data then
                local cur = data:FindFirstChild("ammoCurrent")
                local sz = data:FindFirstChild("ammoSize")
                if cur and sz then
                    local mag = data:FindFirstChild("magAttached")
                    if mag and mag.Value == "" then
                        return { name = child.Name, text = "EMPTY", empty = true }
                    end
                    return {
                        name = child.Name,
                        current = cur.Value,
                        max = sz.Value,
                        text = string.format("%d/%d", cur.Value, sz.Value),
                    }
                end
                local amount = data:FindFirstChild("amount")
                local maxAmount = data:FindFirstChild("maxAmount")
                if amount and maxAmount then
                    return {
                        name = child.Name,
                        text = string.format("%d/%d", amount.Value, maxAmount.Value),
                        consumable = true,
                    }
                end
            end
        end
    end
    return nil
end

H.resolveDropPart = function(inst)
    local cwm = inst:FindFirstChild("currentWeldModel")
    if cwm and cwm:IsA("ObjectValue") and cwm.Value then
        local m = cwm.Value
        if m:IsA("BasePart") then return m end
        if m:IsA("Model") then
            return m.PrimaryPart or m:FindFirstChild("Handle") or m:FindFirstChildWhichIsA("BasePart")
        end
    end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") or inst:IsA("Tool") then
        return inst.PrimaryPart or inst:FindFirstChild("Handle") or inst:FindFirstChildWhichIsA("BasePart", true)
    end
    return inst:FindFirstChildWhichIsA("BasePart", true)
end

H.isDropInstance = function(inst)
    if not inst or not inst.Parent then return false end
    if inst.Name == "Cash" then return false end
    if string.find(inst.Name, "-Holsters", 1, true) then return false end
    if inst:FindFirstChild("_data") or inst:FindFirstChild("data") then return true end
    if inst:FindFirstChild("currentWeldModel") then return true end
    if inst:IsA("Tool") then return true end
    -- Avoid recursive FindFirstChildWhichIsA here — too expensive on big folders
    if inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChild("Handle")) then return true end
    return false
end

H.collectGroundDrops = function(out, seen)
    local roots = {}
    local weldTemp = H.getWeldTempFolder()
    if weldTemp then roots[#roots + 1] = weldTemp end
    local others = workspace:FindFirstChild("_weldobjects.temp.others")
    if others then roots[#roots + 1] = others end

    for r = 1, #roots do
        local root = roots[r]
        for _, child in ipairs(root:GetChildren()) do
            if not seen[child] and H.isDropInstance(child) then
                local part = H.resolveDropPart(child)
                if part and part:IsDescendantOf(game) then
                    seen[child] = true
                    local entry = {
                        name = H.resolveDropName(child),
                        pos = part.Position,
                        root = part,
                        inst = child,
                    }
                    H.enrichDropEntry(entry, child)
                    out[#out + 1] = entry
                end
            end
        end
    end
end

-- watch weld temp folder (Ignored loads async in raid)
task.spawn(function()
    local linked
    while scriptAlive do
        local f = H.getWeldTempFolder()
        if f and f ~= linked then
            linked = f
            TSTAMP.drops = 0
            H.trackConn(f.ChildAdded:Connect(function()
                if CFG.dropsEnabled then TSTAMP.drops = 0 end
            end))
            H.trackConn(f.ChildRemoved:Connect(function()
                if CFG.dropsEnabled then TSTAMP.drops = 0 end
            end))
        end
        task.wait(2)
    end
end)

task.spawn(function()
    while scriptAlive do
        local ignored = workspace:FindFirstChild("Ignored")
        local points = ignored and ignored:FindFirstChild("ObjectivePoints")
        if points then
            H.trackConn(points.ChildAdded:Connect(function()
                if CFG.questMarkerEnabled then TSTAMP.quest = 0 end
            end))
            H.trackConn(points.ChildRemoved:Connect(function()
                if CFG.questMarkerEnabled then TSTAMP.quest = 0 end
            end))
            -- watch value updates on existing points
            for _, child in ipairs(points:GetChildren()) do
                if child:IsA("Vector3Value") then
                    H.trackConn(child:GetPropertyChangedSignal("Value"):Connect(function()
                        if CFG.questMarkerEnabled then TSTAMP.quest = 0 end
                    end))
                end
            end
            break
        end
        task.wait(2)
    end
end)

H.tickWorldCaches = function(dt)
    cacheAccum = cacheAccum + (typeof(dt) == "number" and dt or 0)
    if cacheAccum < CACHE_TICK then return end
    cacheAccum = 0

    H.stepEntityRescan(ENTITY_NODES_PER_TICK)

    local now = tick()
    if now - entityPruneStamp >= ENTITY_PRUNE_INTERVAL then
        entityPruneStamp = now
        H.pruneEntityCache()
    end
    if now - entityRescanStamp >= ENTITY_RESCAN_INTERVAL and not entityScan.active then
        entityRescanStamp = now
        H.beginEntityRescan()
    end

    H.refreshCaches(now)
end

H.refreshLootCache = function()
    if not buildings_folder then buildings_folder = workspace:FindFirstChild("Buildings") end
    local out = {}
    local seen = {}

    if buildings_folder then
        for _, b in ipairs(buildings_folder:GetChildren()) do
            if b.Name == "Loots" then
                H.collectLoot(b, out, 0, seen)
            else
                local loots = b:FindFirstChild("Loots")
                if loots then H.collectLoot(loots, out, 0, seen) end
            end
        end

        local topLoots = buildings_folder:FindFirstChild("Loots")
        if topLoots then
            local inner = topLoots:FindFirstChild("Loots")
            if inner then
                H.collectLoot(inner, out, 0, seen)
                local crates = inner:FindFirstChild("Crates")
                if crates then H.collectLoot(crates, out, 0, seen) end
            end
            local objects = topLoots:FindFirstChild("Objects")
            if objects then H.collectLoot(objects, out, 0, seen) end
        end

        H.collectLootDeep(buildings_folder, out, seen)
        H.collectBodyBags(buildings_folder, out, seen)
    end

    if #out > 0 then
        local new_by_model = {}
        for i = 1, #out do
            new_by_model[out[i].model] = out[i]
        end
        loot_by_model = new_by_model
        CACHE.loot = out
    end
    TSTAMP.loot = tick()
end

H.formatMMSS = function(sec)
    if not sec or sec < 0 then return "--:--" end
    local t = math.floor(sec + 0.5)
    return string.format("%02d:%02d", math.floor(t / 60), t % 60)
end

H.getHeldItem = function(ent)
    for _, child in ipairs(ent.model:GetChildren()) do
        if child:IsA("Tool") then return child.Name end
    end
    for _, part in pairs(ent.parts) do
        for _, child in ipairs(part:GetChildren()) do
            if child:IsA("Model") and child:FindFirstChild("Handle") then return child.Name end
        end
    end
    return nil
end

H.getHeldTool = function(model)
    if not model then return nil end
    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("Tool") then return child end
    end
    return nil
end

H.isPricableItem = function(inst)
    if not inst or not inst.Parent then return false end
    if inst:FindFirstChild("_data") or inst:FindFirstChild("data") then return true end
    if inst:IsA("Tool") then return true end
    return false
end

-- Visible/replicated gear only — full backpack of other players is usually NOT replicated.
H.scanCharacterInventory = function(model)
    local total, count, heldName, heldValue = 0, 0, nil, nil
    if not model then return total, count, heldName, heldValue end

    local held = H.getHeldTool(model)
    if held then
        heldName = held.Name
        heldValue = H.getDropValue(held)
        if heldValue then
            total = total + heldValue
            count = count + 1
        end
    end

    local seen = {}
    if held then seen[held] = true end

    local function consider(inst)
        if not inst or seen[inst] or not H.isPricableItem(inst) then return end
        -- skip body parts / character mesh junk
        if inst:IsA("BasePart") or inst:IsA("Humanoid") or inst:IsA("Accoutrement") then return end
        if inst.Name == "Handle" or inst.Name == "HumanoidRootPart" then return end
        seen[inst] = true
        local val = H.getDropValue(inst)
        if val and val > 0 then
            total = total + val
            count = count + 1
        end
    end

    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("Tool") or child:IsA("Model") or child:IsA("Folder") then
            consider(child)
            if child:IsA("Folder") or child:IsA("Model") then
                for _, nested in ipairs(child:GetChildren()) do
                    consider(nested)
                end
            end
        end
    end

    return total, count, heldName, heldValue
end

H.refreshPlayerInventoryCache = function(budget)
    if not CFG.playerInvPeek then return end
    H.ensurePriceFn()
    H.ensureItemData()
    budget = budget or INV_PRICE_BATCH
    local n = #CACHE.player
    if n == 0 then return end

    inv_price_cursor = (inv_price_cursor or 0)
    local done = 0
    while done < budget and done < n do
        inv_price_cursor = inv_price_cursor + 1
        if inv_price_cursor > n then inv_price_cursor = 1 end
        local ent = CACHE.player[inv_price_cursor]
        if ent and ent.model and ent.model.Parent then
            local total, count, heldName, heldValue = H.scanCharacterInventory(ent.model)
            ent.invTotal = total
            ent.invCount = count
            ent.heldName = heldName
            ent.heldValue = heldValue
        end
        done = done + 1
    end
end

H.refreshCaches = function(now)
    now = now or tick()

    if now - TSTAMP.player >= PLAYER_RESCAN_INTERVAL then
        TSTAMP.player = now
        CACHE.player = H.getPlayersList()
    end

    -- Stagger inventory pricing — never price everyone in one hitch
    if CFG.playerInvPeek and now - TSTAMP.playerInv >= 0.35 then
        TSTAMP.playerInv = now
        pcall(H.refreshPlayerInventoryCache, INV_PRICE_BATCH)
    end

    for i = 1, math.min(LOOT_LIVE_BATCH, #CACHE.loot) do
        local idx = loot_live_cursor
        loot_live_cursor = loot_live_cursor + 1
        if loot_live_cursor > #CACHE.loot then loot_live_cursor = 1 end
        local loot = CACHE.loot[idx]
        if loot then
            if loot.root and loot.root.Parent then
                loot.pos = loot.root.Position
            end
            if loot.is_open_inst then
                pcall(function()
                    loot.is_open = loot.is_open_inst.Value
                    loot.is_locked = loot.is_locked_inst.Value
                end)
            end
        end
    end

    if (CFG.exfilEnabled or CFG.exfilNearestLine or CFG.hudExfilCount) and now - TSTAMP.exfil >= EXFIL_RESCAN_INTERVAL then
        TSTAMP.exfil = now
        local out = {}
        pcall(function()
            local pd = LP:FindFirstChild("playerData")
            local zones = pd and pd:FindFirstChild("availableExtractionZones")
            if not zones then return end
            local ignored = workspace:FindFirstChild("Ignored")
            local exfils = ignored and ignored:FindFirstChild("Exfils")
            for _, z in ipairs(zones:GetChildren()) do
                local pos = z:GetAttribute("position")
                if typeof(pos) ~= "Vector3" and exfils then
                    local folder = exfils:FindFirstChild(z.Name)
                    if folder then
                        local flare = folder:FindFirstChild("__flare")
                        if flare and flare:IsA("BasePart") then pos = flare.Position end
                    end
                end
                if typeof(pos) == "Vector3" then
                    out[#out + 1] = {
                        name = z.Name,
                        pos = pos,
                        locked = z:GetAttribute("locked"),
                        timer = z:GetAttribute("timer"),
                    }
                end
            end
        end)
        CACHE.exfil = out
    end

    if CFG.dropsEnabled and now - TSTAMP.drops >= DROPS_RESCAN_INTERVAL then
        TSTAMP.drops = now
        local out, seen = {}, {}
        H.collectGroundDrops(out, seen)
        CACHE.drops = out
    end

    if CFG.questMarkerEnabled and now - TSTAMP.quest >= QUEST_RESCAN_INTERVAL then
        TSTAMP.quest = now
        local out = {}
        pcall(function()
            local ignored = workspace:FindFirstChild("Ignored")
            local points = ignored and ignored:FindFirstChild("ObjectivePoints")
            if not points then return end
            for _, child in ipairs(points:GetChildren()) do
                local pos = H.resolveObjectivePos(child)
                if H.isValidObjectivePos(pos) then
                    out[#out + 1] = {
                        name = H.parseObjectiveLabel(child.Name),
                        pos = pos,
                        id = child.Name,
                    }
                end
            end
        end)
        CACHE.quest = out
    end

    hud_state.raid_time, hud_state.combat_time, hud_state.loot_secured, hud_state.open_exfils = nil, nil, nil, 0
    pcall(function()
        local rs = SVC.RS:FindFirstChild("__server")
        if rs then
            local rt = rs:FindFirstChild("RaidTimer")
            if rt then hud_state.raid_time = rt.Value end
        end
        local pd = LP:FindFirstChild("playerData")
        if pd then
            local cs = pd:FindFirstChild("combat_state")
            if cs and cs.Value then hud_state.combat_time = cs:GetAttribute("currentTime") end
            local ls = pd:FindFirstChild("lootSecured") or pd:FindFirstChild("LootSecured")
            if ls then hud_state.loot_secured = ls.Value end
        end
        for i = 1, #CACHE.exfil do
            if CACHE.exfil[i].locked ~= true then
                hud_state.open_exfils = hud_state.open_exfils + 1
            end
        end
    end)
end

local TIME_MODES = { "Auto", "Force Day", "Force Night", "Custom Time" }
local timeLockBound = false

H.pinLighting = function(clockTime, ambient, outdoor, brightness)
    local Lighting = SVC.Lighting
    Lighting.ClockTime = clockTime
    Lighting.Brightness = brightness
    Lighting.Ambient = ambient
    Lighting.OutdoorAmbient = outdoor
end

H.pinForcedTime = function()
    shared.freezeCycle = true
    pcall(function() workspace:SetAttribute("LockCycle", true) end)

    if shared._HAVOC_DN_cycle == nil then
        shared._HAVOC_DN_cycle = shared.DN_cycle
    end
    shared.DN_cycle = false

    local mode = CFG.timeMode or 1
    local boost = math.clamp((CFG.brightnessBoost or 0) / 100, 0, 1)

    if mode == 2 then
        H.pinLighting(14,
            Color3.fromRGB(128, 128, 140),
            Color3.fromRGB(140, 140, 155),
            2 + boost * 2)
    elseif mode == 3 then
        H.pinLighting(2.5,
            Color3.fromRGB(55, 60, 80):Lerp(Color3.fromRGB(175, 180, 205), boost),
            Color3.fromRGB(45, 50, 70):Lerp(Color3.fromRGB(155, 165, 190), boost),
            1.2 + boost * 4)
    else
        local t = CFG.customClockTime or 14
        local isNight = t < 6 or t > 18
        if isNight then
            H.pinLighting(t,
                Color3.fromRGB(60, 65, 85):Lerp(Color3.fromRGB(170, 175, 200), boost),
                Color3.fromRGB(50, 55, 75):Lerp(Color3.fromRGB(150, 160, 185), boost),
                1.5 + boost * 3)
        else
            H.pinLighting(t,
                Color3.fromRGB(120, 125, 135):Lerp(Color3.fromRGB(185, 190, 200), boost * 0.5),
                Color3.fromRGB(130, 135, 145):Lerp(Color3.fromRGB(195, 200, 210), boost * 0.5),
                1.5 + boost * 3)
        end
    end
end

H.syncTimeLockBinding = function()
    local active = (CFG.timeMode or 1) > 1
    if active and not timeLockBound then
        timeLockBound = true
        pcall(function()
            SVC.RunService:BindToRenderStep("HAVOC_TIME", Enum.RenderPriority.Camera.Value + 2, H.pinForcedTime)
        end)
    elseif not active and timeLockBound then
        timeLockBound = false
        pcall(function() SVC.RunService:UnbindFromRenderStep("HAVOC_TIME") end)
    end
end

H.applyTimeOfDay = function()
    local mode = CFG.timeMode or 1
    if mode == 1 then
        shared.freezeCycle = false
        pcall(function() workspace:SetAttribute("LockCycle", nil) end)
        if shared._HAVOC_DN_cycle ~= nil then
            shared.DN_cycle = shared._HAVOC_DN_cycle
            shared._HAVOC_DN_cycle = nil
        end
        H.syncTimeLockBinding()
        return
    end

    H.pinForcedTime()
    H.syncTimeLockBinding()
end

task.defer(function()
    if CFG.timeMode and CFG.timeMode > 1 then H.applyTimeOfDay() end
end)

H.getBounds = function(root, parts)
    local top, topOk = H.w2s(root.Position + Vector3.new(0, HEAD_OFFSET, 0))
    local bot, botOk = H.w2s(root.Position - Vector3.new(0, FOOT_OFFSET, 0))
    if not (topOk and botOk) then return nil end
    local h = math.max(math.abs(bot.Y - top.Y), 1)
    local w = h * 0.5
    return Vector2.new(top.X - w * 0.5, top.Y), Vector2.new(w, h)
end

H.drawCornerBox = function(key, pos, size, color)
    local x, y, w, h = pos.X, pos.Y, size.X, size.Y
    local lx, ly = w * 0.25, h * 0.25
    H.drawLine(key .. "_1", Vector2.new(x, y), Vector2.new(x + lx, y), color, 1.5)
    H.drawLine(key .. "_2", Vector2.new(x, y), Vector2.new(x, y + ly), color, 1.5)
    H.drawLine(key .. "_3", Vector2.new(x + w, y), Vector2.new(x + w - lx, y), color, 1.5)
    H.drawLine(key .. "_4", Vector2.new(x + w, y), Vector2.new(x + w, y + ly), color, 1.5)
    H.drawLine(key .. "_5", Vector2.new(x, y + h), Vector2.new(x + lx, y + h), color, 1.5)
    H.drawLine(key .. "_6", Vector2.new(x, y + h), Vector2.new(x, y + h - ly), color, 1.5)
    H.drawLine(key .. "_7", Vector2.new(x + w, y + h), Vector2.new(x + w - lx, y + h), color, 1.5)
    H.drawLine(key .. "_8", Vector2.new(x + w, y + h), Vector2.new(x + w, y + h - ly), color, 1.5)
end

H.drawSkeleton = function(key, parts, color)
    local bones = parts["UpperTorso"] and SKELETON_R15 or SKELETON_R6
    for i = 1, #bones do
        local p1, p2 = parts[bones[i][1]], parts[bones[i][2]]
        if p1 and p2 then
            local a, ok1 = H.w2s(p1.Position)
            local b, ok2 = H.w2s(p2.Position)
            if ok1 and ok2 then H.drawLine(key .. "_" .. i, a, b, color, 1.5) end
        end
    end
end

local HIDDEN_COLOR = Color3.fromRGB(150, 150, 155)

H.drawEntityEsp = function(prefix, ent, opts, maxDist, cpos)
    local root = ent.root
    if not root then return end
    local dist = (root.Position - cpos).Magnitude
    if dist > maxDist then return end
    if opts.hideDead and ent.humanoid.Health <= 0 then return end

    local visible = true
    if opts.visibleCheck then
        visible = H.isVisible(root.Position, cpos, ent.model)
        if not visible and opts.hideOccluded then return end
    end
    local col = (not visible and opts.tint) and HIDDEN_COLOR or opts.color

    local pos, size = H.getBounds(root, ent.parts)
    if not pos then return end

    if opts.tracer and opts.tracerFrom then
        H.drawLine(prefix .. "_trace", opts.tracerFrom, Vector2.new(pos.X + size.X * 0.5, pos.Y + size.Y), col, 1.3)
    end
    if opts.box then H.drawCornerBox(prefix .. "_box", pos, size, col) end
    if opts.healthBar then
        local hp = math.clamp(ent.humanoid.Health / math.max(ent.humanoid.MaxHealth, 1), 0, 1)
        H.drawSquare(prefix .. "_hpbg", Vector2.new(pos.X - 5, pos.Y), Vector2.new(3, size.Y), Color3.new(0, 0, 0), true, 0.4)
        H.drawSquare(prefix .. "_hp", Vector2.new(pos.X - 5, pos.Y + size.Y * (1 - hp)), Vector2.new(3, size.Y * hp), Color3.fromRGB(80, 220, 100), true, 0.2)
    end
    if opts.skeleton then H.drawSkeleton(prefix .. "_skel", ent.parts, col) end

    local textY = pos.Y - 4
    if opts.name then
        local label = ent.name or ent.model.Name
        if opts.healthText then
            label = string.format("%s [%d/%d]", label, math.floor(ent.humanoid.Health), math.floor(ent.humanoid.MaxHealth))
        end
        H.drawText(prefix .. "_name", Vector2.new(pos.X + size.X * 0.5, textY), label, col, 14)
        textY = textY - 16
    end
    if opts.heldItem then
        local held = ent.heldName or H.getHeldItem(ent)
        local heldVal = ent.heldValue
        if held then
            local label = held:gsub("_", " ")
            if opts.invPeek and heldVal and heldVal > 0 then
                label = label .. " [$" .. H.formatMoney(heldVal) .. "]"
            end
            H.drawText(prefix .. "_held", Vector2.new(pos.X + size.X * 0.5, pos.Y + size.Y + 14), label, Color3.fromRGB(255, 200, 100), 13)
        end
    end
    local below = (opts.heldItem and 30 or 14)
    if opts.invPeek then
        local total = ent.invTotal or 0
        local minV = CFG.playerInvMinValue or 0
        if total >= minV and total > 0 then
            local invCol = total >= 50000 and Color3.fromRGB(255, 80, 80)
                or total >= 15000 and Color3.fromRGB(255, 170, 60)
                or Color3.fromRGB(120, 255, 140)
            H.drawText(prefix .. "_inv", Vector2.new(pos.X + size.X * 0.5, pos.Y + size.Y + below),
                "INV $" .. H.formatMoney(total), invCol, 13)
            below = below + 16
        end
    end
    if opts.distance then
        H.drawText(prefix .. "_dist", Vector2.new(pos.X + size.X * 0.5, pos.Y + size.Y + below),
            string.format("%dm", math.floor(dist)), Color3.fromRGB(170, 170, 170), 13)
    end
end

H.lootPassesFilter = function(idx, is_open, is_locked)
    if idx == 2 then return is_locked == true end
    if idx == 3 then return is_locked ~= true end
    if idx == 4 then return is_open == true end
    if idx == 5 then return is_open ~= true end
    return true
end

local aimState = {
    npcLocked = nil, playerLocked = nil,
    npcPrev = nil, playerPrev = nil,
    npcLockUntil = 0, playerLockUntil = 0,
    silentHit = nil, silentUntil = 0,
}
local AIM_LOCK_TIME = 0.35

H.isRightMouseDown = function()
    local ok, down = pcall(function()
        return SVC.UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end)
    return ok and down
end

H.aimCrosshairPos = function()
    if H.isRightMouseDown() then
        return H.screenCenter()
    end
    local mb = SVC.UIS.MouseBehavior
    if mb == Enum.MouseBehavior.LockCenter or mb == Enum.MouseBehavior.LockCurrentPosition then
        return H.screenCenter()
    end
    local ok, mp = pcall(function() return SVC.UIS:GetMouseLocation() end)
    if ok and mp then return mp end
    return H.screenCenter()
end

H.getAimPart = function(ent, boneIdx)
    if not ent or not ent.model then return nil end
    if boneIdx == 1 then
        return ent.parts.Head
            or ent.model:FindFirstChild("Head", true)
            or ent.root
            or ent.model:FindFirstChild("HumanoidRootPart", true)
    end
    return ent.parts.UpperTorso or ent.parts.Torso or ent.root
        or ent.model:FindFirstChild("UpperTorso", true)
        or ent.model:FindFirstChild("Torso", true)
        or ent.model:FindFirstChild("HumanoidRootPart", true)
end

local genv = (getgenv and getgenv()) or _G
local moveMouseRel = mousemoverel or mouse_move_rel
    or genv.mousemoverel or genv.mouse_move_rel
    or (syn and syn.mousemoverel)
    or (fluxus and fluxus.mousemove)
    or (input and input.MouseMove)
    or (Input and Input.MouseMove)
    or (KRNL_LOADED and mousemoverel)

local baseCameraCache = nil
local aimLastDt = 1 / 60
local aimUseBaseCamera = false
local aimErrStamp = 0
local espErrStamp = 0

H.getBaseCamera = function()
    if baseCameraCache and type(baseCameraCache._dx) == "number" then
        return baseCameraCache
    end

    local function tryRequire(mod)
        if not mod or not mod:IsA("ModuleScript") then return nil end
        local ok, bc = pcall(require, mod)
        if ok and type(bc) == "table" and type(bc._dx) == "number" and type(bc._update) == "function" then
            baseCameraCache = bc
            return bc
        end
        return nil
    end

    pcall(function()
        local ps = LP:FindFirstChild("PlayerScripts")
        if not ps then return end
        local camScript = ps:FindFirstChild("Camera")
        if camScript then
            local bcMod = camScript:FindFirstChild("BaseCamera")
            if bcMod then tryRequire(bcMod) end
        end
        if not baseCameraCache then
            for _, desc in ipairs(ps:GetDescendants()) do
                if desc:IsA("ModuleScript") and desc.Name == "BaseCamera" then
                    if tryRequire(desc) then break end
                end
            end
        end
    end)

    return baseCameraCache
end

task.defer(function()
    task.wait(2)
    pcall(H.getBaseCamera)
end)

H.getAimPivotPos = function(bc)
    local char = LP.Character
    if not char then return nil end
    local cam = workspace.CurrentCamera
    local fps = cam and cam:GetAttribute("FPS")
    if (bc._inFirstPerson or fps) and not (shared and shared.finisherCam) then
        local head = char:FindFirstChild("Head")
        if head then return head.CFrame.Position end
    end
    local rootName = bc.ROOT or "HumanoidRootPart"
    local root = char:FindFirstChild(rootName)
    return root and root.Position
end

H.lookDirToCameraAngles = function(dir)
    local lx, ly, lz = dir.X, dir.Y, dir.Z
    local horiz = math.sqrt(lx * lx + lz * lz)
    if horiz < 1e-4 then
        return 0, ly > 0 and -87 or 87
    end
    return math.deg(math.atan2(-lx, -lz)), math.deg(math.atan2(ly, horiz))
end

H.lerpAngleDeg = function(a, b, t)
    local d = (b - a) % 360
    if d > 180 then d = d - 360 end
    return a + d * t
end

H.getAdsMouseBoost = function()
    local boost = H.isRightMouseDown() and 6 or 1
    pcall(function()
        if shared and shared.aim then boost = math.max(boost, 6) end
        local sens = SVC.UIS.MouseDeltaSensitivity
        if type(sens) == "number" and sens > 0 and sens < 0.35 then
            boost = math.max(boost, math.clamp(0.22 / sens, 4, 20))
        end
    end)
    return boost
end

H.injectMouseDelta = function(dx, dy)
    local rdx, rdy = math.round(dx), math.round(dy)
    if rdx == 0 and rdy == 0 then
        if math.abs(dx) >= 0.25 or math.abs(dy) >= 0.25 then
            rdx = dx > 0 and 1 or (dx < 0 and -1 or 0)
            rdy = dy > 0 and 1 or (dy < 0 and -1 or 0)
        else
            return false
        end
    end
    if moveMouseRel then
        local ok = pcall(moveMouseRel, rdx, rdy)
        if ok then return true end
    end
    pcall(function()
        SVC.VIM:SendMouseMoveEvent(SVC.UIS:GetMouseLocation().X + rdx, SVC.UIS:GetMouseLocation().Y + rdy, game)
    end)
    return true
end

H.predictPos = function(part, fromPos, usePrediction)
    if not usePrediction or not part then return part and part.Position end
    local vel = part.AssemblyLinearVelocity
    local dist = (part.Position - fromPos).Magnitude
    local t = dist / 1000
    return part.Position + vel * t
end

H.pickTarget = function(list, boneIdx, fov, maxDist, prevModel, cpos, cross, usePrediction, targetType, skipVis)
    local best, bestScore, bestEnt = nil, math.huge, nil
    local doVis = (not skipVis) and (CFG.aimVisibleCheck == true)
    for i = 1, #list do
        local ent = list[i]
        if ent.humanoid and ent.humanoid.Health > 0 then
            local part = H.getAimPart(ent, boneIdx)
            if part then
                local pos = H.predictPos(part, cpos, usePrediction)
                local dist = (pos - cpos).Magnitude
                if maxDist <= 0 or dist <= maxDist then
                    local sp, ok = H.w2s(pos)
                    if ok then
                        local px = (sp - cross).Magnitude
                        local effFov = (ent.model == prevModel) and (fov * 1.2) or fov
                        if px <= effFov and (not doVis or H.isVisible(part.Position, cpos, ent.model)) then
                            local score = (targetType == 2) and dist or px
                            if ent.model == prevModel then score = score * 0.75 end
                            if score < bestScore then
                                bestScore = score
                                best = pos
                                bestEnt = ent
                            end
                        end
                    end
                end
            end
        end
    end
    return best, bestEnt
end

H.pickTargetSticky = function(list, boneIdx, fov, maxDist, lockKey, untilKey, prevModel, cpos, cross, usePrediction, targetType)
    local now = tick()
    local locked = aimState[lockKey]
    if locked and now < aimState[untilKey] then
        local part = H.getAimPart(locked, boneIdx)
        if part and locked.humanoid and locked.humanoid.Health > 0 then
            local pos = H.predictPos(part, cpos, usePrediction)
            local sp, ok = H.w2s(pos)
            if ok and (sp - cross).Magnitude <= fov * 1.25 then
                return pos, locked
            end
        end
    end

    local pos, ent = H.pickTarget(list, boneIdx, fov, maxDist, prevModel, cpos, cross, usePrediction, targetType)
    if ent then
        aimState[lockKey] = ent
        aimState[untilKey] = now + AIM_LOCK_TIME
    else
        aimState[lockKey] = nil
    end
    return pos, ent
end

H.smoothAimBaseCamera = function(bc, targetPos, smooth)
    local pivot = H.getAimPivotPos(bc)
    if not pivot then return false end

    local dir = targetPos - pivot
    local mag = dir.Magnitude
    if mag < 0.01 then return false end
    dir = dir / mag

    local tDx, tDy = H.lookDirToCameraAngles(dir)
    if bc._angleY then
        tDy = math.clamp(tDy, bc._angleY.Min, bc._angleY.Max)
    end

    local sm = math.clamp(smooth, 1, 25)
    local alpha = math.clamp(1 / sm, 0.18, 1)

    bc._dx = H.lerpAngleDeg(bc._dx, tDx, alpha)
    bc._dy = bc._dy + (tDy - bc._dy) * alpha
    return true
end

H.smoothAimMouse = function(targetPos, smooth)
    local cam = workspace.CurrentCamera
    if not cam then return false end

    local vp = cam:WorldToViewportPoint(targetPos)
    if vp.Z <= 0 then return false end

    local mp = H.aimCrosshairPos()
    local dx, dy = vp.X - mp.X, vp.Y - mp.Y
    if dx * dx + dy * dy < 0.25 then return false end

    local sm = math.clamp(smooth, 1, 25)
    local step = math.clamp(1 / sm, 0.15, 1) * H.getAdsMouseBoost()
    H.injectMouseDelta(dx * step, dy * step)
    return true
end

H.smoothAim = function(targetPos, smooth)
    local bc = H.getBaseCamera()
    if bc then
        aimUseBaseCamera = H.smoothAimBaseCamera(bc, targetPos, smooth)
        if aimUseBaseCamera then return end
    end
    aimUseBaseCamera = false
    H.smoothAimMouse(targetPos, smooth)
end

-- Silent aim: game does FireServer("fire", weapon, origin, dir) from getHitPos.
-- Rewrite dir (and optionally origin) so bullets go to target without moving camera.
H.getSilentTargetPos = function(origin)
    if not CFG.silentAim then return nil, nil end
    if CFG.silentAimRequireRmb and not H.isRightMouseDown() then return nil, nil end

    local cam = workspace.CurrentCamera
    if not cam then return nil, nil end
    local cpos = cam.CFrame.Position
    local cross = H.aimCrosshairPos()
    local bone = CFG.silentAimBone or CFG.playerAimBone or 1
    local fov = CFG.silentAimFov or 220
    local maxDist = CFG.silentAimMaxDist or 2000
    local pred = CFG.silentAimPrediction ~= false
    local needVis = (CFG.aimVisibleCheck == true) and (CFG.silentAimWallbang ~= true)

    local function fromEnt(ent)
        if not (ent and ent.humanoid and ent.humanoid.Health > 0) then return nil end
        local part = H.getAimPart(ent, bone)
        if not part then return nil end
        if needVis and not H.isVisible(part.Position, cpos, ent.model) then return nil end
        local from = (typeof(origin) == "Vector3") and origin or cpos
        return H.predictPos(part, from, pred), ent
    end

    -- Prefer sticky lock from player aimbot if live (shared lock, not a conflict)
    local locked = aimState.playerLocked
    if locked then
        local pos = fromEnt(locked)
        if pos then return pos, locked end
    end

    local pos, ent = H.pickTarget(
        CACHE.player, bone, fov, maxDist,
        aimState.playerPrev, cpos, cross, pred, 1,
        CFG.silentAimWallbang == true
    )
    if pos and ent then
        local muzzlePos = fromEnt(ent)
        return muzzlePos or pos, ent
    end
    return nil, nil
end

-- Only rewrites direction. Origin stays real muzzle (no magic spoof).
H.applySilentFire = function(origin, _dir)
    if not CFG.silentAim then return nil, nil end
    local targetPos, ent = H.getSilentTargetPos(origin)
    if not targetPos or typeof(origin) ~= "Vector3" then return nil, nil end
    local delta = targetPos - origin
    if delta.Magnitude < 0.05 then return nil, nil end
    aimState.silentHit = ent
    aimState.silentUntil = tick() + 0.35
    return nil, delta.Unit -- keep origin, replace dir only
end

local FEATURE_STATUS = {
    { cfg = "silentAim", label = "Silent Aim", color = Color3.fromRGB(255, 80, 120) },
    { cfg = "hipfireAccurate", label = "Hipfire Acc", color = Color3.fromRGB(255, 180, 90) },
    { cfg = "playerAimEnabled", label = "Aim Player", color = Color3.fromRGB(80, 200, 255) },
    { cfg = "npcAimEnabled", label = "Aim Entity", color = Color3.fromRGB(255, 120, 120) },
    { cfg = "lootEnabled", label = "Loot ESP", color = Color3.fromRGB(255, 200, 90) },
    { cfg = "exfilEnabled", label = "Exfil ESP", color = Color3.fromRGB(90, 255, 120) },
    { cfg = "radarEnabled", label = "Radar", color = Color3.fromRGB(120, 200, 255) },
}

-- Bottom-left status strip — clears game top bars (standing / extraction toast)
H.drawFeatureHud = function(cam)
    if not CFG.featureHud then return end
    local vs = cam and cam.ViewportSize
    if not vs then return end
    local x, y = 14, vs.Y - 118
    H.drawText("fh_title", Vector2.new(x, y), "HAVOC", Color3.fromRGB(220, 220, 230), 13, false)
    y = y + 15

    for i = 1, #FEATURE_STATUS do
        local entry = FEATURE_STATUS[i]
        local on = CFG[entry.cfg] == true
        H.drawText("fh_" .. i, Vector2.new(x, y),
            (on and "[ON]  " or "[OFF] ") .. entry.label,
            on and entry.color or Color3.fromRGB(120, 120, 130), 12, false)
        y = y + 14
    end

    if CFG.playerAimEnabled or CFG.npcAimEnabled or CFG.silentAim then
        local locking = H.isRightMouseDown()
        local silentLive = aimState.silentUntil and tick() < aimState.silentUntil
        local hint
        if silentLive then
            hint = "SILENT → TARGET"
        elseif CFG.silentAim then
            hint = "Silent: shoot when enemy in FOV"
        else
            hint = locking and "RMB LOCKING" or "RMB hold aim"
        end
        H.drawText("fh_rmb", Vector2.new(x, y), hint,
            silentLive and Color3.fromRGB(255, 80, 120)
                or (locking and Color3.fromRGB(90, 255, 120) or Color3.fromRGB(150, 150, 160)),
            11, false)
    end
end

H.drawAimVisuals = function(cpos, cross)
    if not H.isRightMouseDown() then return end

    if CFG.playerAimEnabled and CFG.playerAimDrawFov then
        H.drawCircle("plr_fov", cross, CFG.playerAimFov, Color3.fromRGB(80, 200, 255), false)
    end
    if CFG.npcAimEnabled and CFG.npcAimDrawFov then
        H.drawCircle("npc_fov", cross, CFG.npcAimFov, Color3.new(1, 1, 1), false)
    end

    if CFG.playerAimEnabled then
        local pos, ent = H.pickTarget(CACHE.player, CFG.playerAimBone, CFG.playerAimFov, CFG.playerAimMaxDist,
            aimState.playerPrev, cpos, cross, CFG.playerAimPrediction, 1)
        aimState.playerLocked = ent
        aimState.playerPrev = ent and ent.model
        if pos then
            if CFG.playerAimTargetLine then
                local sp, ok = H.w2s(pos)
                if ok then H.drawLine("plr_aim_line", cross, sp, Color3.fromRGB(80, 200, 255), 1.5) end
            end
            return
        end
        H.drawText("plr_aim_miss", cross + Vector2.new(0, 44), "PLAYER AIM: no target in FOV", Color3.fromRGB(120, 200, 255), 13)
    end

    if CFG.npcAimEnabled then
        local pos, ent = H.pickTarget(CACHE.entity, CFG.npcAimBone, CFG.npcAimFov, CFG.npcAimMaxDist,
            aimState.npcPrev, cpos, cross, CFG.npcAimPrediction, CFG.npcAimTargetType)
        aimState.npcLocked = ent
        aimState.npcPrev = ent and ent.model
        if pos then
            if CFG.npcAimTargetLine then
                local sp, ok = H.w2s(pos)
                if ok then H.drawLine("npc_aim_line", cross, sp, Color3.fromRGB(255, 80, 80), 1.5) end
            end
        else
            H.drawText("npc_aim_miss", cross + Vector2.new(0, 28), "ENTITY AIM: no target in FOV", Color3.fromRGB(255, 120, 120), 13)
        end
    end
end

H.runAimLock = function(cpos, cross)
    if not H.isRightMouseDown() then
        aimState.npcLocked = nil
        aimState.playerLocked = nil
        return
    end

    local substeps = 1
    for _ = 1, substeps do
        if CFG.playerAimEnabled then
            local pos, ent = H.pickTargetSticky(CACHE.player, CFG.playerAimBone, CFG.playerAimFov, CFG.playerAimMaxDist,
                "playerLocked", "playerLockUntil", aimState.playerPrev, cpos, cross, CFG.playerAimPrediction, 1)
            aimState.playerPrev = ent and ent.model
            if pos then
                H.smoothAim(pos, CFG.playerAimSmooth)
                return
            end
            aimState.playerLocked = nil
        end

        if CFG.npcAimEnabled then
            local pos, ent = H.pickTargetSticky(CACHE.entity, CFG.npcAimBone, CFG.npcAimFov, CFG.npcAimMaxDist,
                "npcLocked", "npcLockUntil", aimState.npcPrev, cpos, cross, CFG.npcAimPrediction, CFG.npcAimTargetType)
            aimState.npcPrev = ent and ent.model
            if pos then
                H.smoothAim(pos, CFG.npcAimSmooth)
                return
            end
            aimState.npcLocked = nil
        end
    end
end

H.safeRawGet = function(tbl, key)
    if type(tbl) ~= "table" then return nil end
    local ok, val = pcall(rawget, tbl, key)
    return ok and val or nil
end

H.isWeaponModule = function(tbl)
    if type(tbl) ~= "table" or typeof(tbl) == "Instance" then return false end
    local recoil = H.safeRawGet(tbl, "recoil")
    if type(recoil) ~= "table" then return false end
    if type(H.safeRawGet(recoil, "vPunchBase")) ~= "number" then return false end
    local gunType = H.safeRawGet(tbl, "gunType")
    if gunType == nil and H.safeRawGet(tbl, "damage") == nil then return false end
    return true
end

H.getEquippedWeapon = function()
    local char = LP.Character
    if not char then return nil, nil, nil end
    for _, child in ipairs(char:GetChildren()) do
        local handle = child:FindFirstChild("Handle")
        if handle and (child:IsA("Tool") or child:IsA("Model")) then
            local name = child.Name
            local mod = shared and shared.cachedModules and shared.cachedModules[name]
            if mod and H.isWeaponModule(mod) then
                return mod, name, child
            end
        end
    end
    return nil, nil, nil
end

H.zeroSpreadAxis = function(axis)
    if type(axis) ~= "table" then return end
    axis[1], axis[2], axis[3] = 0, 0, 1
end

H.patchWeaponTable = function(tbl)
    if type(tbl) ~= "table" or not H.isWeaponModule(tbl) then return end

    local recoil = H.safeRawGet(tbl, "recoil")
    if CFG.noRecoil and type(recoil) == "table" then
        pcall(function()
            recoil.vPunchBase = 0
            recoil.hPunchBase = 0
            recoil.dPunchBase = 0
            recoil.vRecoil = { 0, 0 }
            recoil.hRecoil = { 0, 0 }
            recoil.vStep = { 0, 0 }
            recoil.hStep = { 0, 0 }
            recoil.recoilPunch = 0
            recoil.rMain = 0
            recoil.tStep = 0
        end)
    end

    -- Soft no-spread: tighten crosshair / heat only
    if CFG.noSpread and not CFG.trueNoSpread then
        pcall(function()
            if type(tbl.spreadReduce) == "number" and tbl.spreadReduce > 0.05 then
                tbl.spreadReduce = 0.05
            end
            if type(tbl.crosshairRadius) == "number" then
                tbl.crosshairRadius = math.min(tbl.crosshairRadius, 8)
            end
            if type(tbl.crosshairShoveSize) == "number" then
                tbl.crosshairShoveSize = math.min(tbl.crosshairShoveSize, 0.5)
            end
        end)
    end

    -- True no-spread: zero cone tables + shove + force camera-aligned fire via aimAlpha runtime
    if CFG.trueNoSpread then
        pcall(function()
            local spread = H.safeRawGet(tbl, "spread")
            if type(spread) == "table" then
                H.zeroSpreadAxis(spread.x)
                H.zeroSpreadAxis(spread.y)
                H.zeroSpreadAxis(spread.z)
            end
            if type(tbl.spreadReduce) == "number" then tbl.spreadReduce = 100 end
            if type(tbl.crosshairRadius) == "number" then tbl.crosshairRadius = 0 end
            if type(tbl.crosshairShoveSize) == "number" then tbl.crosshairShoveSize = 0 end
            if type(tbl.aimAccuracy) == "number" then tbl.aimAccuracy = 0 end
        end)
    end

    -- Hitscan feel: weapon.vel is bullet m/s (NOT character move speed)
    if CFG.fastVel then
        pcall(function()
            if type(tbl.vel) == "number" then tbl.vel = 100000 end
        end)
    end

    if CFG.instantAds then
        pcall(function()
            local ads = H.safeRawGet(tbl, "ads_config")
            if type(ads) == "table" then
                ads.tweenInfoIn = TweenInfo.new(0.01, Enum.EasingStyle.Linear)
                ads.tweenInfoOut = TweenInfo.new(0.01, Enum.EasingStyle.Linear)
            end
            -- keep weights healthy so FireDir stays synced
            if type(tbl.aimWeight) == "number" and tbl.aimWeight < 1 then tbl.aimWeight = 1 end
            if type(tbl.unAimWeight) == "number" and tbl.unAimWeight < 1 then tbl.unAimWeight = 1 end
        end)
    end

    -- aimWeight=0 breaks fire anim weight → FireDir desyncs from camera → no server damage
    if CFG.noSway then
        pcall(function()
            if type(tbl.aimWeight) == "number" and tbl.aimWeight <= 0 then tbl.aimWeight = 1 end
            if type(tbl.unAimWeight) == "number" and tbl.unAimWeight <= 0 then tbl.unAimWeight = 1 end
            if type(tbl.weight) == "number" and tbl.weight <= 0 then tbl.weight = 1 end
        end)
    end
end

H.patchEquippedWeaponRuntime = function(inst)
    if not inst then return end
    if CFG.noSpread or CFG.trueNoSpread then
        pcall(function()
            if inst:GetAttribute("RateHeat") ~= nil then
                inst:SetAttribute("RateHeat", 0)
            end
        end)
    end
end

H.tickWeaponRuntime = function()
    if not (CFG.trueNoSpread or CFG.instantAds or CFG.noSpread or CFG.fastVel or CFG.hipfireAccurate or CFG.silentAim) then
        return
    end
    if shared then
        -- aimAlpha 1 = hipfire uses camera ray (game normally needs ADS hold)
        if CFG.trueNoSpread or CFG.hipfireAccurate or CFG.silentAim then
            shared.aimAlpha = 1
        elseif CFG.instantAds and shared.aim then
            shared.aimAlpha = 1
        end
    end
    local now = tick()
    if now - (weaponRuntimeStamp or 0) < 0.2 then return end
    weaponRuntimeStamp = now
    local _, _, inst = H.getEquippedWeapon()
    H.patchEquippedWeaponRuntime(inst)
end

local weaponRuntimeStamp = 0

-- REMOVED: getgc(true) sway wipe — caused periodic frame hitches.
-- Use Instant ADS + Fix Sway Weights instead.
H.applyCachedSwayZero = function() end
H.zeroAimSwayTables = function() end

local weaponModStamp = 0

H.anyWeaponModEnabled = function()
    return CFG.noRecoil or CFG.noSpread or CFG.trueNoSpread or CFG.noSway
        or CFG.fastVel or CFG.instantAds
end

H.applyWeaponMods = function()
    if not H.anyWeaponModEnabled() then return end

    local now = tick()
    if now - weaponModStamp < 2 then return end
    weaponModStamp = now

    local mod, name, inst = H.getEquippedWeapon()
    if mod then
        pcall(H.patchWeaponTable, mod)
        if name and shared and shared.cachedModules and shared.cachedModules[name] and shared.cachedModules[name] ~= mod then
            pcall(H.patchWeaponTable, shared.cachedModules[name])
        end
        H.patchEquippedWeaponRuntime(inst)
    end
end

H.setupWeaponModHooks = function()
    local function hookChar(char)
        H.trackConn(char.ChildAdded:Connect(function(child)
            if child:FindFirstChild("Handle") then
                task.defer(H.applyWeaponMods)
            end
        end))
    end
    if LP.Character then hookChar(LP.Character) end
    H.trackConn(LP.CharacterAdded:Connect(hookChar))
end

local threatSound = nil
local threatBeepStamp = 0

H.playThreatBeep = function()
    if not CFG.threatSound then return end
    local now = tick()
    if now - threatBeepStamp < 0.8 then return end
    threatBeepStamp = now
    if not threatSound then
        local ok = pcall(function()
            threatSound = Instance.new("Sound")
            threatSound.SoundId = "rbxassetid://3779045779"
            threatSound.Volume = 1.2
            threatSound.Parent = game:GetService("SoundService")
        end)
        if not ok then return end
    end
    pcall(function() threatSound:Play() end)
end

-- Circular radar (always draws ring when enabled) + off-screen chevrons + threat text
H.drawThreatRadar = function(cpos)
    if not (CFG.radarEnabled or CFG.threatBehind or CFG.threatAiming) then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vs = cam.ViewportSize
    local center = Vector2.new(vs.X * 0.5, vs.Y * 0.5)
    local camCF = cam.CFrame
    local camLook = camCF.LookVector
    local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
    if flatLook.Magnitude < 0.05 then flatLook = Vector3.new(0, 0, -1) else flatLook = flatLook.Unit end
    local flatRight = Vector3.new(-flatLook.Z, 0, flatLook.X)

    local myChar = LP.Character
    local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Head"))
    local myPos = myRoot and myRoot.Position or cpos

    -- Radar disc sits mid-right, clear of hotbar / ammo / top bars
    local radarR = math.clamp(CFG.radarRadius or 90, 50, 140)
    local radarC = Vector2.new(vs.X - radarR - 28, vs.Y * 0.42)
    local maxDist = math.max(CFG.radarMaxDist or 600, 50)

    local aimingName, behindCount = nil, 0

    if CFG.radarEnabled then
        H.drawCircle("radar_ring", radarC, radarR, Color3.fromRGB(70, 90, 110), false)
        H.drawCircle("radar_ring2", radarC, radarR * 0.5, Color3.fromRGB(50, 65, 80), false)
        H.drawLine("radar_n", radarC, radarC + Vector2.new(0, -radarR), Color3.fromRGB(90, 110, 130), 1)
        H.drawCircle("radar_me", radarC, 3, Color3.fromRGB(255, 255, 255), true)
        H.drawText("radar_lbl", Vector2.new(radarC.X, radarC.Y + radarR + 12), "RADAR", Color3.fromRGB(140, 160, 180), 11, true)
    end

    local function plotBlip(key, worldPos, col, isPlayer)
        local delta = worldPos - myPos
        local dist = delta.Magnitude
        if dist > maxDist or dist < 0.5 then return dist end

        local flat = Vector3.new(delta.X, 0, delta.Z)
        local fx = flat:Dot(flatRight)
        local fz = flat:Dot(flatLook)
        -- screen: +X right, +Y down; forward = up on radar
        local scale = (radarR - 6) / maxDist
        local rx = fx * scale
        local ry = -fz * scale
        local len = math.sqrt(rx * rx + ry * ry)
        if len > radarR - 6 then
            local s = (radarR - 6) / len
            rx, ry = rx * s, ry * s
        end
        local bp = Vector2.new(radarC.X + rx, radarC.Y + ry)
        if CFG.radarEnabled then
            H.drawCircle(key, bp, isPlayer and 4 or 3, col, true)
        end
        return dist
    end

    for i = 1, #CACHE.player do
        local ent = CACHE.player[i]
        local root = ent.root
        if root and ent.humanoid and ent.humanoid.Health > 0 then
            local ppos = root.Position
            local dist = (ppos - myPos).Magnitude
            if dist <= maxDist then
                local toEnt = ppos - cpos
                local behind = toEnt.Magnitude > 1 and camLook:Dot(toEnt.Unit) < -0.15

                local aiming = false
                if CFG.threatAiming and dist <= CFG.threatMaxDist then
                    local head = ent.parts and ent.parts.Head or root
                    local toMe = (myPos - ppos)
                    if toMe.Magnitude > 0.5 and head.CFrame.LookVector:Dot(toMe.Unit) > 0.94 then
                        aiming = true
                        aimingName = ent.name or ent.model.Name
                    end
                end
                if behind then behindCount = behindCount + 1 end

                local col = aiming and Color3.fromRGB(255, 50, 50)
                    or (behind and Color3.fromRGB(255, 160, 50) or Color3.fromRGB(80, 200, 255))
                plotBlip("rad_p_" .. i, ppos, col, true)

                if CFG.radarEnabled then
                    local vp = cam:WorldToViewportPoint(ppos)
                    local onScreen = vp.Z > 0 and vp.X >= 0 and vp.X <= vs.X and vp.Y >= 0 and vp.Y <= vs.Y
                    if not onScreen then
                        local sx, sy = vp.X - center.X, vp.Y - center.Y
                        if vp.Z < 0 then sx, sy = -sx, -sy end
                        local ang = math.atan2(sy, sx)
                        local dirv = Vector2.new(math.cos(ang), math.sin(ang))
                        local perp = Vector2.new(-dirv.Y, dirv.X)
                        local ap = center + dirv * math.min(CFG.radarRadius or 120, math.min(vs.X, vs.Y) * 0.28)
                        local tip = ap + dirv * 10
                        local base = ap - dirv * 3
                        H.drawLine("rad_arr_" .. i .. "a", tip, base + perp * 8, col, 2)
                        H.drawLine("rad_arr_" .. i .. "b", tip, base - perp * 8, col, 2)
                    end
                end
            end
        end
    end

    -- NPCs also on radar so it isn't empty in PvE
    if CFG.radarEnabled then
        local npcCol = Color3.fromRGB(255, 90, 90)
        local limit = math.min(#CACHE.entity, 40)
        for i = 1, limit do
            local ent = CACHE.entity[i]
            local root = ent and ent.root
            if root and ent.humanoid and ent.humanoid.Health > 0 then
                plotBlip("rad_e_" .. i, root.Position, npcCol, false)
            end
        end
    end

    if CFG.threatAiming and aimingName then
        H.drawText("threat_aim", Vector2.new(center.X, vs.Y * 0.18), "TARGETED BY " .. aimingName, Color3.fromRGB(255, 50, 50), 16, true)
        H.playThreatBeep()
    end
    if CFG.threatBehind and behindCount > 0 then
        H.drawText("threat_behind", Vector2.new(center.X, vs.Y * 0.18 + 22), behindCount .. " ENEMY BEHIND", Color3.fromRGB(255, 150, 40), 14, true)
    end
end

H.renderEsp = function(dt)
    if not Drawing or not Drawing.new then return end

    espAccum = espAccum + (typeof(dt) == "number" and dt or 0)
    if espAccum < ESP_INTERVAL then return end
    espAccum = 0

    H.beginDrawFrame()

    local ok, err = pcall(function()
    local cpos = H.camPos()
    local cross = H.aimCrosshairPos()
    local cam = workspace.CurrentCamera
    local tracerFrom = cam and Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y) or nil

    if CFG.entityEnabled then
        for i = 1, #CACHE.entity do
            local ent = CACHE.entity[i]
            H.drawEntityEsp("ent_" .. H.instKey(ent.model), ent, {
                box = CFG.entityBox,
                name = CFG.entityName,
                distance = CFG.entityDistance,
                heldItem = CFG.entityHeldItem,
                healthBar = CFG.entityHealthBar,
                healthText = CFG.entityHealthText,
                skeleton = CFG.entitySkeleton,
                hideDead = CFG.entityHideDead,
                color = Color3.fromRGB(255, 80, 80),
                visibleCheck = CFG.espVisibleCheck,
                tint = CFG.espHiddenTint,
                hideOccluded = CFG.espHideOccluded,
                tracer = CFG.entityTracer,
                tracerFrom = tracerFrom,
            }, CFG.entityMaxDist, cpos)
        end
    end

    if CFG.playerEnabled then
        for i = 1, #CACHE.player do
            local ent = CACHE.player[i]
            H.drawEntityEsp(H.entDrawKey("plr_", ent), ent, {
                box = CFG.playerBox,
                name = CFG.playerName,
                distance = CFG.playerDistance,
                heldItem = CFG.playerHeldItem,
                invPeek = CFG.playerInvPeek,
                healthBar = CFG.playerHealthBar,
                healthText = false,
                skeleton = CFG.playerSkeleton,
                hideDead = true,
                color = Color3.fromRGB(80, 200, 255),
                visibleCheck = CFG.espVisibleCheck,
                tint = CFG.espHiddenTint,
                hideOccluded = CFG.espHideOccluded,
                tracer = CFG.playerTracer,
                tracerFrom = tracerFrom,
            }, CFG.playerMaxDist, cpos)
        end
    end

    if CFG.lootEnabled then
        for i = 1, #CACHE.loot do
            local loot = CACHE.loot[i]
            if loot.pos and loot.category and CFG["loot_" .. loot.category.key] then
                if loot.root and loot.root.Parent then
                    loot.pos = loot.root.Position
                end
                local is_open = loot.is_open_inst and loot.is_open_inst.Value or loot.is_open
                local is_locked = loot.is_locked_inst and loot.is_locked_inst.Value or loot.is_locked
                if H.lootPassesFilter(CFG.lootFilter, is_open, is_locked) then
                    local dist = (loot.pos - cpos).Magnitude
                    if dist <= CFG.lootMaxDist then
                        local sp, ok = H.w2s(loot.pos)
                        if ok then
                            local col = loot.category.color or Color3.fromRGB(220, 180, 120)
                            local label = loot.category.display
                            if is_locked then label = label .. " [Locked]" end
                            if CFG.lootDistance then label = label .. string.format(" [%dm]", math.floor(dist)) end
                            local lk = loot.model and H.instKey(loot.model) or H.posKey(loot.pos)
                            H.drawText("loot_" .. lk, sp, label, col, CFG.lootTextSize)
                            if CFG.lootMarker then
                                H.drawCircle("loot_mk_" .. lk, sp, 5, col, true)
                            end
                        end
                    end
                end
            end
        end
    end

    local nearestExfilPos = nil
    local nearestDist = math.huge
    if CFG.exfilEnabled or CFG.exfilNearestLine then
        for i = 1, #CACHE.exfil do
            local ex = CACHE.exfil[i]
            if ex.pos then
                local dist = (ex.pos - cpos).Magnitude
                if dist <= CFG.exfilMaxDist then
                    local sp, ok = H.w2s(ex.pos)
                    if ok then
                        if CFG.exfilEnabled then
                            local label = ex.name
                            if CFG.exfilTimer then
                                if ex.locked == true then label = label .. " [CLOSED]"
                                elseif ex.timer then label = label .. " [" .. H.formatMMSS(ex.timer) .. "]"
                                else label = label .. " [OPEN]" end
                                label = label .. string.format(" [%dm]", math.floor(dist))
                            end
                            local col = ex.locked == true and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(90, 255, 120)
                            H.drawText("exfil_" .. (ex.name or H.posKey(ex.pos)), sp, label, col, 13)
                        end
                        if ex.locked ~= true and dist < nearestDist then
                            nearestDist = dist
                            nearestExfilPos = ex.pos
                        end
                    end
                end
            end
        end
    end

    if CFG.exfilNearestLine and nearestExfilPos then
        local sp, ok = H.w2s(nearestExfilPos)
        if ok then
            H.drawLine("exfil_line", cross, sp, Color3.fromRGB(90, 255, 120), 1.5)
        end
    end

    if CFG.dropsEnabled then
        local minVal = CFG.dropsMinValue or 0
        for i = 1, #CACHE.drops do
            local drop = CACHE.drops[i]
            if drop.root and drop.root.Parent then drop.pos = drop.root.Position end
            if H.dropPassesFilters(drop) then
                local dist = (drop.pos - cpos).Magnitude
                if dist <= CFG.dropsMaxDist then
                    local sp, ok = H.w2s(drop.pos)
                    if ok then
                        local meta = drop.meta
                        local dropCol = H.DEFAULT_DROP_COL
                        if CFG.dropsColorByTier ~= false and meta and meta.color then
                            dropCol = meta.color
                        end

                        local label = drop.name
                        if CFG.dropsShowTag ~= false and meta and meta.tag then
                            label = label .. " [" .. meta.tag .. "]"
                        end
                        if CFG.dropsShowTier ~= false and meta and meta.tierLevel then
                            local tname = meta.tierType and string.upper(tostring(meta.tierType)):sub(1, 4) or "T"
                            label = label .. string.format(" [%s%d]", tname, meta.tierLevel)
                        end
                        if CFG.dropsShowValue and drop.value and drop.value >= minVal then
                            label = label .. " [$" .. H.formatMoney(drop.value) .. "]"
                        end
                        if CFG.dropsShowBuyPrice and meta and meta.buyPrice then
                            label = label .. " [buy $" .. H.formatMoney(meta.buyPrice) .. "]"
                        end
                        label = label .. string.format(" [%dm]", math.floor(dist))

                        local dk = "drop_" .. i
                        H.drawText(dk, sp, label, dropCol, CFG.dropsTextSize)
                        if CFG.dropsMarker then
                            H.drawCircle(dk .. "_mk", sp, 4, dropCol, true)
                        end
                    end
                end
            end
        end
    end

    if CFG.questMarkerEnabled then
        local questCol = Color3.fromRGB(180, 120, 255)
        for i = 1, #CACHE.quest do
            local q = CACHE.quest[i]
            if q.pos then
                local dist = (q.pos - cpos).Magnitude
                if dist <= CFG.questMaxDist then
                    local sp, ok = H.w2s(q.pos)
                    if ok then
                        local label = "[QUEST] " .. q.name .. string.format(" [%dm]", math.floor(dist))
                        H.drawText("quest_" .. (q.id or i), sp, label, questCol, 13)
                        H.drawCircle("quest_mk_" .. (q.id or i), sp, 6, questCol, true)
                    end
                end
            end
        end
    end

    if CFG.hudEnabled then
        -- Below game top bars (standing / compass), left gutter
        local y = 108
        if CFG.hudRaidTimer and hud_state.raid_time then
            H.drawText("hud_raid", Vector2.new(14, y), "RAID " .. H.formatMMSS(hud_state.raid_time), Color3.fromRGB(255, 220, 80), 13, false)
            y = y + 16
        end
        if CFG.hudCombat and hud_state.combat_time then
            H.drawText("hud_combat", Vector2.new(14, y), "COMBAT " .. H.formatMMSS(hud_state.combat_time), Color3.fromRGB(255, 90, 90), 13, false)
            y = y + 16
        end
        if CFG.hudLootSecured and hud_state.loot_secured ~= nil then
            local secured = hud_state.loot_secured == true
            H.drawText("hud_loot", Vector2.new(14, y), secured and "LOOT SECURED" or "LOOT AT RISK",
                secured and Color3.fromRGB(90, 255, 120) or Color3.fromRGB(255, 150, 60), 13, false)
            y = y + 16
        end
        if CFG.hudExfilCount then
            H.drawText("hud_exfil", Vector2.new(14, y), "OPEN EXFILS: " .. tostring(hud_state.open_exfils or 0), Color3.fromRGB(90, 255, 120), 13, false)
        end
    end

    if CFG.hudEnabled and CFG.hudAmmo then
        local ammo = H.getEquippedAmmo()
        if ammo and cam then
            local sx, sy = cam.ViewportSize.X, cam.ViewportSize.Y
            -- Above game weapon HUD (bottom-right)
            local ax, ay = sx - 160, sy - 118
            local ammoCol = ammo.empty and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 255, 255)
            if ammo.current and ammo.max then
                local ratio = math.clamp(ammo.current / math.max(ammo.max, 1), 0, 1)
                ammoCol = Color3.fromRGB(170, 0, 0):Lerp(Color3.fromRGB(255, 255, 255), ratio)
            end
            H.drawText("hud_ammo", Vector2.new(ax, ay), ammo.text, ammoCol, 16, false)
            H.drawText("hud_ammo_name", Vector2.new(ax, ay - 16), (ammo.name or ""):gsub("_", " "), Color3.fromRGB(160, 165, 180), 11, false)
        end
    end

    if CFG.crosshair then
        H.drawLine("ch_h", Vector2.new(cross.X - 6, cross.Y), Vector2.new(cross.X + 6, cross.Y), Color3.new(1, 1, 1), 1.5)
        H.drawLine("ch_v", Vector2.new(cross.X, cross.Y - 6), Vector2.new(cross.X, cross.Y + 6), Color3.new(1, 1, 1), 1.5)
    end

    H.drawThreatRadar(cpos)
    H.drawFeatureHud(workspace.CurrentCamera)
    H.drawAimVisuals(cpos, cross)

    end)

    H.finishDrawFrame()

    if not ok then
        local now = tick()
        if now - espErrStamp > 3 then
            espErrStamp = now
            warn("[HAVOC ESP]", err)
        end
    end
end

H.aimStep = function(dt)
    aimLastDt = (type(dt) == "number" and dt > 0) and dt or aimLastDt
    local ok, err = pcall(function()
        H.runAimLock(H.camPos(), H.aimCrosshairPos())
    end)
    if not ok then
        local now = tick()
        if now - aimErrStamp > 3 then
            aimErrStamp = now
            warn("[HAVOC AIM]", err)
        end
    end
end

-- numpad toggles (work even when typing in chat / menu)
H.trackConn(SVC.UIS.InputBegan:Connect(function(io, gpe)
    local changed = false
    if io.KeyCode == Enum.KeyCode.KeypadOne then CFG.playerAimEnabled = not CFG.playerAimEnabled; changed = true
    elseif io.KeyCode == Enum.KeyCode.KeypadTwo then CFG.npcAimEnabled = not CFG.npcAimEnabled; changed = true
    elseif io.KeyCode == Enum.KeyCode.KeypadThree then CFG.lootEnabled = not CFG.lootEnabled; changed = true
    elseif io.KeyCode == Enum.KeyCode.KeypadFour then CFG.exfilEnabled = not CFG.exfilEnabled; changed = true
    end
    if changed then
        H.SaveConfig()
        H.syncMenuFromCfg()
    end
    if gpe then return end
end))

task.spawn(function()
    task.wait(1)
    pcall(H.refreshLootCache)
    while true do
        task.wait(LOOT_SCAN_INTERVAL)
        pcall(H.refreshLootCache)
    end
end)

task.spawn(function()
    while true do
        if H.anyWeaponModEnabled() then
            H.applyWeaponMods()
        end
        task.wait(2)
    end
end)

H.trackConn(SVC.RunService.RenderStepped:Connect(function()
    if not scriptAlive then return end
    pcall(H.tickWeaponRuntime)
end))

H.setupWeaponModHooks()

H.trackConn(SVC.RunService.Heartbeat:Connect(function(dt)
    pcall(H.tickWorldCaches, dt)
end))
H.trackConn(SVC.RunService.Heartbeat:Connect(H.renderEsp))

-- player feature watcher (throttled ~6Hz)
do
    local acc = 0
    H.trackConn(SVC.RunService.Heartbeat:Connect(function(dt)
        if not scriptAlive then return end
        acc = acc + dt
        if acc < 0.16 then return end
        acc = 0
        if CFG.autoLockpick and H.hasLockpickTool() and shared then
            shared.lockpick = true
        end
        if pendingLockpick and shared and shared.lockpicking then
            H.tryCompleteLockpick(true)
        end
        if not netTbl or not origInvoke then pcall(H.installNetHooks) end
        if not skillsTbl or not origStaminaFn then pcall(H.installSkillHooks) end
        if CFG.autoSelfRevive then pcall(H.tryAutoSelfRevive) end
        if CFG.autoFinisher then
            pcall(H.tryInstantFinisher, CACHE.player)
            pcall(H.tryInstantFinisher, CACHE.entity)
        end
    end))
end
pcall(function() SVC.RunService:UnbindFromRenderStep("HAVOC_AIM") end)
SVC.RunService:BindToRenderStep("HAVOC_AIM", Enum.RenderPriority.Camera.Value + 1, H.aimStep)

task.defer(function()
    local bc = H.getBaseCamera()
    if bc then
        print("[HAVOC] Aimbot ready (BaseCamera) | Num1/2 toggle | RMB hold to lock")
    elseif moveMouseRel then
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
    if H.ensureItemData() then
        local n = 0
        local items = itemDataMod and itemDataMod.items
        if type(items) == "table" then
            for _ in pairs(items) do n = n + 1 end
        end
        print("[HAVOC] PriceDB ready | itemData entries:", n)
    else
        warn("[HAVOC] PriceDB: itemData require failed — drop tags/tiers limited")
    end
end)

-- Register teardown early (Cascade loads in background; must work even if HttpGet hangs).
if getgenv then
    getgenv().HAVOC_INTERNAL = getgenv().HAVOC_INTERNAL or {}
    getgenv().HAVOC_INTERNAL.cleanup = function()
        scriptAlive = false
        pcall(H.restoreSkillHooks)
        pcall(H.restoreNetHooks)
        for i = 1, #HAVOC_CONNS do pcall(function() HAVOC_CONNS[i]:Disconnect() end) end
        pcall(function() SVC.RunService:UnbindFromRenderStep("HAVOC_AIM") end)
        pcall(function() SVC.RunService:UnbindFromRenderStep("HAVOC_TIME") end)
        for _, pool in pairs(DrawPool) do
            for _, d in pairs(pool) do pcall(function() d:Remove() end) end
        end
        task.defer(function()
            pcall(function()
                if CascadeGui and CascadeGui.Destroy then
                    CascadeGui:Destroy()
                elseif CascadeWindow and CascadeWindow.Destroy then
                    CascadeWindow:Destroy()
                end
            end)
            CascadeApp, CascadeWindow, CascadeGui, cascadeNotifyFn, cascadeUiSync = nil, nil, nil, nil, nil
        end)
    end
end

local MENU_EMBED = [=[
-- HAVOC Cascade menu (separate chunk — keeps Main.lua under Luau 200-local limit)
-- Cascade: https://github.com/cascadeui/Cascade (pinned v1.4.0)
return function(api)
    local CFG = api.CFG
    local SaveConfig = api.SaveConfig
    local LP = api.LP
    local SVC = api.SVC
    local BRAND = api.BRAND
    local BRAND_ICON = api.BRAND_ICON
    local BRAND_DISCORD = api.BRAND_DISCORD
    local TIME_MODES = api.TIME_MODES
    local configLoaded = api.configLoaded
    local applyTimeOfDay = api.applyTimeOfDay
    local applyWeaponMods = api.applyWeaponMods
    local installSkillHooks = api.installSkillHooks
    local installNetHooks = api.installNetHooks
    local fireGearToggle = api.fireGearToggle

    -- Pin version: avoid silent API breaks from "latest"
    local CASCADE_VERSION = "v1.4.0"
    local CASCADE_FILE = "dist.luau"
    local CASCADE_URL = ("https://github.com/cascadeui/Cascade/releases/download/%s/%s"):format(
        CASCADE_VERSION,
        CASCADE_FILE
    )
    local CASCADE_CACHE = ".cache/cascade-" .. CASCADE_VERSION .. "-" .. CASCADE_FILE

    local function httpGet(url)
        if type(game.HttpGetAsync) == "function" then
            return game:HttpGetAsync(url)
        end
        return game:HttpGet(url)
    end

    local function loadCascade()
        local compile = loadstring or load
        if not compile then
            return nil, "no loadstring"
        end

        local src
        if isfile and readfile and isfile(CASCADE_CACHE) then
            local ok, body = pcall(readfile, CASCADE_CACHE)
            if ok and type(body) == "string" and #body > 1000 and body:sub(1, 1) ~= "<" then
                src = body
                print("[HAVOC] Cascade cache hit:", CASCADE_CACHE)
            end
        end

        if not src then
            local ok, body = pcall(httpGet, CASCADE_URL)
            if not ok or type(body) ~= "string" or #body < 1000 or body:sub(1, 1) == "<" then
                return nil, "HttpGet failed: " .. tostring(body)
            end
            src = body
            if writefile and makefolder then
                pcall(function()
                    if isfolder and not isfolder(".cache") then
                        makefolder(".cache")
                    end
                    writefile(CASCADE_CACHE, src)
                end)
            end
            print("[HAVOC] Cascade downloaded:", CASCADE_VERSION)
        end

        local chunk, err = compile(src, "@Cascade-" .. CASCADE_VERSION)
        if not chunk then
            return nil, "compile: " .. tostring(err)
        end

        local ok, lib = pcall(chunk)
        if not ok then
            return nil, "exec: " .. tostring(lib)
        end
        if type(lib) ~= "table" or type(lib.New) ~= "function" then
            return nil, "invalid cascade export"
        end
        return lib
    end

    -- Executor polyfills Cascade ProtectUI may need
    if getgenv then
        getgenv().gethui = getgenv().gethui or function()
            local pg = LP:FindFirstChildOfClass("PlayerGui")
            if pg then return pg end
            return LP:WaitForChild("PlayerGui", 10)
        end
        if type(cloneref) ~= "function" then
            getgenv().cloneref = function(obj) return obj end
        end
    end

    local cascade, loadErr = loadCascade()
    if not cascade then
        warn("[HAVOC] Cascade unavailable:", loadErr, "| core still active | Num1-4 | RMB")
        return
    end

    local theme = cascade.Themes and (cascade.Themes.Dark or cascade.Themes.Light)
    local accent = cascade.Accents and (cascade.Accents.Blue or cascade.Accents.Purple)
    if not theme then
        warn("[HAVOC] Cascade Themes missing")
        return
    end

    local function sym(name)
        local s = cascade.Symbols
        if type(s) == "table" and type(s[name]) == "string" then
            return s[name]
        end
        return nil
    end

    local okApp, app = pcall(function()
        return cascade.New({
            Theme = theme,
            Accent = accent,
        })
    end)
    if not okApp or not app then
        warn("[HAVOC] Cascade.New failed:", app)
        return
    end

    local okWin, window = pcall(function()
        return app:Window({
            Title = BRAND or "voidw0rld",
            Subtitle = "HAVOC Internal · " .. (BRAND_DISCORD or ""),
            Searching = true,
            Draggable = true,
            Resizable = true,
            CanExit = false,
            CanMinimize = true,
            CanZoom = true,
            Dropshadow = true,
            UIBlur = false,
            Minimized = false,
        })
    end)
    if not okWin or not window then
        warn("[HAVOC] Cascade Window failed:", window)
        return
    end

    local screenGui = nil
    pcall(function()
        if typeof(app.__container) == "Instance" then
            screenGui = app.__container
        elseif app.__instance and typeof(app.__instance) == "Instance" then
            screenGui = app.__instance
        end
    end)
    if not screenGui then
        pcall(function()
            local gethui = rawget(getfenv(), "gethui") or (getgenv and getgenv().gethui)
            local root = gethui and gethui()
            if root then
                screenGui = root:FindFirstChild("Cascade")
            end
            if not screenGui and LP then
                local pg = LP:FindFirstChildOfClass("PlayerGui")
                screenGui = pg and pg:FindFirstChild("Cascade")
            end
        end)
    end

    if api.setWindow then
        api.setWindow(app, window, screenGui)
    end

    local function pushNotify(title, subtitle, duration)
        pcall(function()
            app:Notification({
                App = "HAVOC",
                AppIcon = BRAND_ICON,
                Title = title or "HAVOC",
                Subtitle = subtitle or "",
                Duration = duration or 4,
            })
        end)
    end

    if api.setNotify then
        api.setNotify(pushNotify)
    end

    -- Hotkey → menu visual sync (Num1/2/3/4 etc). suppress avoids ValueChanged feedback loops.
    local toggleRefs = {}
    local suppressUiSync = false

    local function addToggle(form, title, subtitle, key, cb)
        local row = form:Row({ SearchIndex = title })
        row:Left():TitleStack({
            Title = title,
            Subtitle = subtitle,
        })
        local toggle = row:Right():Toggle({
            Value = CFG[key] == true,
            ValueChanged = function(_, value)
                if suppressUiSync then return end
                CFG[key] = value and true or false
                if cb then
                    pcall(cb, CFG[key])
                end
                pcall(SaveConfig)
            end,
        })
        toggleRefs[key] = toggle
    end

    local function addSlider(form, title, subtitle, key, min, max, cb)
        local cur = tonumber(CFG[key]) or min
        cur = math.clamp(math.floor(cur + 0.5), min, max)
        CFG[key] = cur

        local function labelFor(v)
            return string.format("%s (%d)", title, v)
        end

        local row = form:Row({ SearchIndex = title })
        local titleStack = row:Left():TitleStack({
            Title = labelFor(cur),
            Subtitle = subtitle,
        })
        local slider = row:Right():Slider({
            Minimum = min,
            Maximum = max,
            Value = cur,
            ValueChanged = function(_, value)
                if suppressUiSync then return end
                local n = math.clamp(math.floor((tonumber(value) or cur) + 0.5), min, max)
                CFG[key] = n
                pcall(function()
                    titleStack.Title = labelFor(n)
                end)
                if cb then
                    pcall(cb, n)
                end
                pcall(SaveConfig)
            end,
        })
        return slider
    end

    local function addDropdown(form, title, subtitle, keyValues, selectedIndex, onPick)
        local row = form:Row({ SearchIndex = title })
        row:Left():TitleStack({
            Title = title,
            Subtitle = subtitle,
        })
        local idx = math.clamp(tonumber(selectedIndex) or 1, 1, #keyValues)
        row:Right():PullDownButton({
            Label = keyValues[idx],
            Options = keyValues,
            Value = idx,
            ValueChanged = function(self, value)
                if suppressUiSync then return end
                local i = tonumber(value) or 1
                i = math.clamp(i, 1, #keyValues)
                if onPick then
                    pcall(onPick, i, keyValues[i])
                end
                pcall(function()
                    self.Label = keyValues[i]
                end)
                pcall(SaveConfig)
            end,
        })
    end

    local function addButton(form, title, subtitle, onPush)
        local row = form:Row({ SearchIndex = title })
        row:Left():TitleStack({
            Title = title,
            Subtitle = subtitle,
        })
        row:Right():Button({
            Label = "Run",
            State = "Secondary",
            Pushed = function()
                pcall(onPush)
            end,
        })
    end

    if api.setUiSync then
        api.setUiSync(function()
            suppressUiSync = true
            for key, toggle in pairs(toggleRefs) do
                local want = CFG[key] == true
                pcall(function()
                    if toggle.Value ~= want then
                        toggle.Value = want
                    end
                end)
            end
            suppressUiSync = false
        end)
    end

    local section = window:Section({ Title = "HAVOC", Disclosure = false })

    -- Combat
    do
        local tab = section:Tab({
            Selected = true,
            Title = "Combat",
            Icon = sym("scope") or sym("viewfinder"),
        })

        local npc = tab:PageSection({ Title = "NPC Aimbot" }):Form()
        addToggle(npc, "Aimbot Entity", "Num2 · hold RMB to lock", "npcAimEnabled")
        addToggle(npc, "NPC Prediction", "Lead moving targets", "npcAimPrediction")
        addToggle(npc, "NPC FOV Circle", nil, "npcAimDrawFov")
        addToggle(npc, "NPC Target Line", nil, "npcAimTargetLine")
        addSlider(npc, "NPC FOV", nil, "npcAimFov", 10, 500)
        addSlider(npc, "NPC Smooth", nil, "npcAimSmooth", 1, 25)
        addSlider(npc, "NPC Range", nil, "npcAimMaxDist", 100, 3000)

        local plr = tab:PageSection({ Title = "Player Aimbot" }):Form()
        addToggle(plr, "Aimbot Player", "Num1 · hold RMB to lock", "playerAimEnabled")
        addToggle(plr, "Player FOV Circle", nil, "playerAimDrawFov")
        addToggle(plr, "Player Target Line", nil, "playerAimTargetLine")
        addSlider(plr, "Player FOV", nil, "playerAimFov", 10, 500)
        addSlider(plr, "Player Smooth", nil, "playerAimSmooth", 1, 25)
        addToggle(plr, "Prediction", nil, "playerAimPrediction")

        local silent = tab:PageSection({ Title = "Silent Aim (PvP)" }):Form()
        addToggle(silent, "Silent Aim", "Bullet goes to enemy in FOV — camera free. No conflict with aimbot.", "silentAim", function(v)
            if v then task.spawn(installNetHooks) end
        end)
        addToggle(silent, "Hipfire Accurate", "No ADS needed — bullets follow look / silent", "hipfireAccurate")
        addToggle(silent, "Wallbang", "Silent ignores walls (LOS off)", "silentAimWallbang")
        addToggle(silent, "Silent Needs RMB", "Only while holding RMB", "silentAimRequireRmb")
        addToggle(silent, "Silent Prediction", "Lead moving targets", "silentAimPrediction")
        addSlider(silent, "Silent FOV", "Enemy must be in this screen FOV", "silentAimFov", 20, 800)
        addSlider(silent, "Silent Range", nil, "silentAimMaxDist", 50, 4000)

        local shared = tab:PageSection({ Title = "Shared" }):Form()
        addToggle(shared, "Visible Only", "LOS for aimbot + silent (unless Wallbang)", "aimVisibleCheck")
        addToggle(shared, "Feature Status HUD", "Bottom-left ON/OFF list", "featureHud")
    end

    -- ESP
    do
        local tab = section:Tab({
            Title = "ESP",
            Icon = sym("eye") or sym("binoculars"),
        })

        local ent = tab:PageSection({ Title = "NPC / Entity" }):Form()
        addToggle(ent, "Entity ESP", "NPC visuals", "entityEnabled")
        addToggle(ent, "Entity Box", nil, "entityBox")
        addToggle(ent, "Entity Name", nil, "entityName")
        addToggle(ent, "Entity Distance", nil, "entityDistance")
        addToggle(ent, "Held Item", nil, "entityHeldItem")
        addToggle(ent, "Health Bar", nil, "entityHealthBar")
        addToggle(ent, "Skeleton", nil, "entitySkeleton")
        addSlider(ent, "Entity Range", "Max render distance", "entityMaxDist", 100, 3000)

        local players = tab:PageSection({ Title = "Players" }):Form()
        addToggle(players, "Player ESP", nil, "playerEnabled")
        addToggle(players, "Player Box", nil, "playerBox")
        addToggle(players, "Player Name", nil, "playerName")
        addToggle(players, "Player Distance", nil, "playerDistance")
        addToggle(players, "Held Weapon", nil, "playerHeldItem")
        addToggle(players, "Inventory Peek", "Held + visible gear value", "playerInvPeek")
        addSlider(players, "Min Inv Value", "Hide INV below this", "playerInvMinValue", 0, 100000)
        addToggle(players, "Health Bar", nil, "playerHealthBar")
        addToggle(players, "Skeleton", nil, "playerSkeleton")
        addSlider(players, "Player Range", nil, "playerMaxDist", 100, 3000)

        local loot = tab:PageSection({ Title = "Loot" }):Form()
        addToggle(loot, "Loot ESP", "Num3 toggle", "lootEnabled")
        addToggle(loot, "Loot Distance", nil, "lootDistance")
        addToggle(loot, "Color Marker", nil, "lootMarker")
        addSlider(loot, "Loot Range", nil, "lootMaxDist", 100, 5000)
        addSlider(loot, "Loot Text Size", nil, "lootTextSize", 10, 20)

        local vis = tab:PageSection({ Title = "Visibility" }):Form()
        addToggle(vis, "Visibility Check", "Raycast LOS", "espVisibleCheck")
        addToggle(vis, "Tint Hidden", "Occluded drawn gray", "espHiddenTint")
        addToggle(vis, "Hide Occluded", "Skip behind walls", "espHideOccluded")
        addToggle(vis, "Entity Tracers", nil, "entityTracer")
        addToggle(vis, "Player Tracers", nil, "playerTracer")

        local radar = tab:PageSection({ Title = "Radar / Threat" }):Form()
        addToggle(radar, "Circular Radar", "Ring + player/NPC blips (mid-right)", "radarEnabled")
        addToggle(radar, "Behind Warning", nil, "threatBehind")
        addToggle(radar, "Targeted Warning", nil, "threatAiming")
        addToggle(radar, "Threat Beep", nil, "threatSound")
        addSlider(radar, "Radar Size", "Disc radius on screen", "radarRadius", 50, 140)
        addSlider(radar, "Radar Range", "World distance scale", "radarMaxDist", 100, 2000)
        addSlider(radar, "Targeted Range", nil, "threatMaxDist", 50, 800)

        local exfil = tab:PageSection({ Title = "Extraction & Drops" }):Form()
        addToggle(exfil, "Exfil ESP", "Num4 · available zones only", "exfilEnabled")
        addToggle(exfil, "Exfil Timer", nil, "exfilTimer")
        addToggle(exfil, "Line To Nearest", nil, "exfilNearestLine")
        addToggle(exfil, "Dropped Items", nil, "dropsEnabled")
        addToggle(exfil, "Drop Value", "Trader sell $ (itemData.price)", "dropsShowValue")
        addToggle(exfil, "Drop Buy Price", "Show vendor buyPrice", "dropsShowBuyPrice")
        addToggle(exfil, "Drop Tag", "QUEST / AMMO / MED / ARMOR", "dropsShowTag")
        addToggle(exfil, "Drop Tier", "Tier type + level", "dropsShowTier")
        addToggle(exfil, "Color By Tier", "ESP color from itemData tier", "dropsColorByTier")
        addToggle(exfil, "Drop Marker", nil, "dropsMarker")
        addSlider(exfil, "Drop Range", nil, "dropsMaxDist", 50, 3000)
        addSlider(exfil, "Min Drop Value", "Hide below trader sell $", "dropsMinValue", 0, 50000)
        addSlider(exfil, "Min Tier", "Hide below tierLevel", "dropsMinTier", 0, 5)

        local filters = tab:PageSection({ Title = "Drop Filters" }):Form()
        addToggle(filters, "Show Quest", nil, "dropsFilterQuest")
        addToggle(filters, "Show Ammo", "ammo + mags", "dropsFilterAmmo")
        addToggle(filters, "Show Meds", nil, "dropsFilterMed")
        addToggle(filters, "Show Armor", "armor/helmet/bag", "dropsFilterArmor")
        addToggle(filters, "Show Other", "junk / valuables / rest", "dropsFilterOther")

        local quest = tab:PageSection({ Title = "Quest Objectives" }):Form()
        addToggle(quest, "Quest Markers", nil, "questMarkerEnabled")
        addSlider(quest, "Quest Range", nil, "questMaxDist", 100, 8000)
    end

    -- Mods
    do
        local tab = section:Tab({
            Title = "Mods",
            Icon = sym("wrenchAdjustable") or sym("hammerFill") or sym("gearshape"),
        })

        local gun = tab:PageSection({ Title = "Weapon Mods" }):Form()
        addToggle(gun, "No Recoil", "Client camera punch", "noRecoil", function()
            applyWeaponMods()
        end)
        addToggle(gun, "No Spread (soft)", "Crosshair + RateHeat", "noSpread", function()
            applyWeaponMods()
        end)
        addToggle(gun, "True No Spread", "Zero cone + camera fire dir", "trueNoSpread", function()
            applyWeaponMods()
        end)
        addToggle(gun, "Fast Bullet / Hitscan", "weapon.vel boost", "fastVel", function()
            applyWeaponMods()
        end)
        addToggle(gun, "Instant ADS", "Snap aimAlpha + ads tween", "instantAds", function()
            applyWeaponMods()
        end)
        addToggle(gun, "Fix Sway Weights", "Repair aimWeight=0 desync", "noSway", function()
            applyWeaponMods()
        end)

        local tod = tab:PageSection({ Title = "Day / Night" }):Form()
        addDropdown(tod, "Time Mode", "Auto / Day / Night / Custom", TIME_MODES, CFG.timeMode or 1, function(i)
            CFG.timeMode = i
            applyTimeOfDay()
        end)
        addSlider(tod, "Custom Clock", "Hour 0-24 when Custom", "customClockTime", 0, 24, function()
            if CFG.timeMode == 4 then applyTimeOfDay() end
        end)
        addSlider(tod, "Brightness Boost", "Extra night visibility", "brightnessBoost", 0, 100, function()
            if CFG.timeMode and CFG.timeMode > 1 then applyTimeOfDay() end
        end)
    end

    -- Player
    do
        local tab = section:Tab({
            Title = "Player",
            Icon = sym("personFill") or sym("figureWalk"),
        })

        local move = tab:PageSection({ Title = "Movement" }):Form()
        addToggle(move, "Overweight Sprint", "Sprint while overweight", "owSprint", function(v)
            if v then task.spawn(installSkillHooks) end
        end)
        addToggle(move, "No Weight Slowdown", nil, "noWeightSpeed", function(v)
            if v then task.spawn(installSkillHooks) end
        end)
        addToggle(move, "Infinite Stamina", nil, "infStamina", function(v)
            if v then task.spawn(installSkillHooks) end
        end)

        local surv = tab:PageSection({ Title = "Survival" }):Form()
        addToggle(surv, "No Fall Damage", nil, "noFall")
        addToggle(surv, "No Drown", nil, "noDrown")
        addToggle(surv, "Auto Self-Revive", "RV11 on knock", "autoSelfRevive")

        local combat = tab:PageSection({ Title = "Combat Actions" }):Form()
        addToggle(combat, "Instant Finisher", "finish_special ≤12 studs", "autoFinisher")

        local interact = tab:PageSection({ Title = "Interact" }):Form()
        addToggle(interact, "Auto Lockpick", "Hold F on lock", "autoLockpick", function(v)
            if v then task.spawn(installNetHooks) end
        end)

        local gear = tab:PageSection({ Title = "Gear" }):Form()
        addButton(gear, "Toggle Headlamp", "Requires headlamp", function()
            fireGearToggle("lampToggle")
        end)
        addButton(gear, "Toggle Visor", "Requires helmet visor", function()
            fireGearToggle("visorToggle")
        end)
    end

    -- HUD
    do
        local tab = section:Tab({
            Title = "HUD",
            Icon = sym("squareStack3dUp") or sym("rectangleStack"),
        })
        local form = tab:PageSection({ Title = "Overlay" }):Form()
        addToggle(form, "Raid HUD", nil, "hudEnabled")
        addToggle(form, "Raid Timer", nil, "hudRaidTimer")
        addToggle(form, "Combat Timer", nil, "hudCombat")
        addToggle(form, "Loot Secured", nil, "hudLootSecured")
        addToggle(form, "Open Exfil Count", nil, "hudExfilCount")
        addToggle(form, "Ammo / Mag HUD", nil, "hudAmmo")
        addToggle(form, "Crosshair", nil, "crosshair")
    end

    -- Menu keybind (G) — minimize toggle, does not destroy
    do
        local tab = section:Tab({
            Title = "Menu",
            Icon = sym("gearshape") or sym("sidebarLeft"),
        })
        local form = tab:PageSection({ Title = "Window" }):Form()
        local row = form:Row({ SearchIndex = "Toggle Key" })
        row:Left():TitleStack({
            Title = "Toggle Key",
            Subtitle = "Minimize / restore menu",
        })
        row:Right():KeybindField({
            Value = Enum.KeyCode.G,
            Placeholder = "Press key…",
            BindPressed = function(_, _, inputComplete, gameProcessed)
                if not inputComplete or gameProcessed then
                    return
                end
                pcall(function()
                    window.Minimized = not window.Minimized
                end)
            end,
        })
    end

    print("[HAVOC] Cascade OK:", CASCADE_VERSION)
    pushNotify("HAVOC", "Internal ready — press G for menu", 5)
    if configLoaded then
        pushNotify("Settings", "Loaded from save", 3)
    end
end
]=]

local function findMenuSource()
    local paths = {
        getgenv and getgenv().HAVOC_MENU_PATH,
        "Havoc/Menu.lua",
        "scripts/Havoc/Menu.lua",
        "SinNatX/scripts/Havoc/Menu.lua",
        "MON/!routine/SinNatX/scripts/Havoc/Menu.lua",
        "Menu.lua",
    }
    if isfile and readfile then
        for _, path in ipairs(paths) do
            if type(path) == "string" and path ~= "" and isfile(path) then
                return readfile(path), path
            end
        end
        if listfiles then
            local function scan(dir, depth)
                if depth > 5 then return nil end
                local ok, entries = pcall(listfiles, dir)
                if not ok or type(entries) ~= "table" then return nil end
                for _, entry in ipairs(entries) do
                    if type(entry) == "string" then
                        if entry:sub(-8) == "Menu.lua" and isfile(entry) then
                            local body = readfile(entry)
                            if type(body) == "string" and body:find("HAVOC Cascade", 1, true) then
                                return body, entry
                            end
                        end
                        if isfolder and isfolder(entry) and not entry:find(".", 1, true) then
                            local found, p = scan(entry, depth + 1)
                            if found then return found, p end
                        end
                    end
                end
                return nil
            end
            for _, scanRoot in ipairs({ "", ".", "workspace", "scripts" }) do
                local found, p = scan(scanRoot, 0)
                if found then return found, p end
            end
        end
    end
    return MENU_EMBED, "embedded"
end

local function runHavocMenuBuild(build)
    local ok2, err2 = pcall(build, {
        CFG = CFG,
        SaveConfig = H.SaveConfig,
        LP = LP,
        SVC = SVC,
        BRAND = BRAND,
        BRAND_ICON = BRAND_ICON,
        BRAND_DISCORD = BRAND_DISCORD,
        TIME_MODES = TIME_MODES,
        configLoaded = configLoaded,
        notify = H.notify,
        applyTimeOfDay = H.applyTimeOfDay,
        applyWeaponMods = H.applyWeaponMods,
        installSkillHooks = H.installSkillHooks,
        installNetHooks = H.installNetHooks,
        fireGearToggle = H.fireGearToggle,
        setWindow = function(app, win, gui)
            CascadeApp = app
            CascadeWindow = win
            CascadeGui = gui
        end,
        setNotify = function(fn)
            cascadeNotifyFn = fn
        end,
        setUiSync = function(fn)
            cascadeUiSync = fn
        end,
    })
    if not ok2 then
        warn("[HAVOC] Menu build fail:", err2)
    else
        print("[HAVOC] Menu ready - press G")
    end
end

local function loadHavocMenu()
    local compile = loadstring or load
    if not compile then
        warn("[HAVOC] Menu: loadstring unavailable")
        return
    end
    local src, label = findMenuSource()
    if type(src) ~= "string" or #src < 32 then
        warn("[HAVOC] Menu source empty")
        return
    end
    print("[HAVOC] Menu source:", label)
    local chunk, err = compile(src, "@" .. tostring(label))
    if not chunk then
        warn("[HAVOC] Menu compile fail:", err)
        return
    end
    local ok, build = pcall(chunk)
    if not ok then
        warn("[HAVOC] Menu load fail:", build)
        return
    end
    if type(build) ~= "function" then
        warn("[HAVOC] Menu: expected return function")
        return
    end
    runHavocMenuBuild(build)
end

task.spawn(function()
    task.wait(0.5)
    loadHavocMenu()
end)

