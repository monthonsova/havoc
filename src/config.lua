return function(havoc)
    local SVC = havoc.SVC

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

        silentAim = false,
        silentAimFov = 220,
        silentAimMaxDist = 2000,
        silentAimBone = 1, -- 1=Head
        silentAimPrediction = true,
        silentAimRequireRmb = false,
        silentAimWallbang = false,
        hipfireAccurate = false,

        featureHud = true,

        noRecoil = false,
        noSpread = false,
        trueNoSpread = false,
        noSway = false,
        fastVel = false,
        magicBullet = false,
        zeroGravity = false,
        bulletSpeedBoost = 100000,
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

    local function configFsReady()
        return readfile and writefile and isfile and isfolder and makefolder
    end

    local function ensureConfigDir()
        if not configFsReady() then return false end
        if not isfolder("Nonny Services") then makefolder("Nonny Services") end
        if not isfolder(CONFIG_DIR) then makefolder(CONFIG_DIR) end
        return true
    end

    local function SaveConfig()
        if not ensureConfigDir() then return false end

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

    local function LoadConfig()
        if not ensureConfigDir() then return false end

        if not isfile(CONFIG_PATH) then
            SaveConfig()
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

        CFG.noAimSway = false
        if CFG.radarRadius and CFG.radarRadius > 140 then
            CFG.radarRadius = 90
        end

        if tonumber(decoded.lootMaxDist) == 300 then
            CFG.lootMaxDist = 5000
            task.defer(SaveConfig)
        end

        print("[HAVOC] Settings loaded")
        return true
    end

    local configLoaded = false
    pcall(function() configLoaded = LoadConfig() == true end)

    pcall(function()
        game:BindToClose(function()
            SaveConfig()
        end)
    end)

    -- Bind to shared havoc table
    havoc.CFG = CFG
    havoc.LOOT_TYPES = LOOT_TYPES
    havoc.LOOT_TYPE_ID = LOOT_TYPE_ID
    havoc.LOOT_DRAW_PRIORITY = LOOT_DRAW_PRIORITY
    havoc.SaveConfig = SaveConfig
    havoc.LoadConfig = LoadConfig
    havoc.configLoaded = configLoaded
end
