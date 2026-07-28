return function(havoc)
    local CFG = havoc.CFG
    local SaveConfig = havoc.SaveConfig
    local LP = havoc.LP
    local SVC = havoc.SVC
    local BRAND = havoc.BRAND or "voidw0rld"
    local BRAND_ICON = havoc.BRAND_ICON or "rbxassetid://111627748770819"
    local BRAND_DISCORD = havoc.BRAND_DISCORD or "discord.gg/voidw0rld"
    local TIME_MODES = havoc.TIME_MODES or { "Auto", "Force Day", "Force Night", "Custom Time" }
    local applyTimeOfDay = havoc.applyTimeOfDay
    local applyWeaponMods = havoc.applyWeaponMods
    local installSkillHooks = havoc.installSkillHooks
    local installNetHooks = havoc.installNetHooks
    local fireGearToggle = havoc.fireGearToggle

    local VOIDUI_URL = "https://raw.githubusercontent.com/monthonsova/VoidUI-main/main/VoidUI.lua"
    local VOIDUI_CACHE = ".cache/VoidUI-main.lua"

    local function httpGet(url)
        if type(game.HttpGetAsync) == "function" then
            return game:HttpGetAsync(url)
        end
        return game:HttpGet(url)
    end

    local function loadVoidUI()
        local compile = loadstring or load
        if not compile then
            return nil, "no loadstring"
        end

        local src
        -- Local dev cache check
        if isfile and readfile then
            if isfile(VOIDUI_CACHE) then
                local ok, body = pcall(readfile, VOIDUI_CACHE)
                if ok and type(body) == "string" and #body > 500 then
                    src = body
                end
            elseif isfile("VoidUI.lua") then
                local ok, body = pcall(readfile, "VoidUI.lua")
                if ok and type(body) == "string" and #body > 500 then
                    src = body
                end
            end
        end

        if not src then
            local ok, body = pcall(httpGet, VOIDUI_URL)
            if not ok or type(body) ~= "string" or #body < 500 or body:sub(1, 1) == "<" then
                return nil, "HttpGet failed: " .. tostring(body)
            end
            src = body
            if writefile and makefolder then
                pcall(function()
                    if isfolder and not isfolder(".cache") then
                        makefolder(".cache")
                    end
                    writefile(VOIDUI_CACHE, src)
                end)
            end
        end

        local chunk, err = compile(src, "@VoidUI")
        if not chunk then
            return nil, "compile: " .. tostring(err)
        end

        local ok, lib = pcall(chunk)
        if not ok then
            return nil, "exec: " .. tostring(lib)
        end
        if type(lib) ~= "table" or type(lib.CreateWindow) ~= "function" then
            return nil, "invalid VoidUI export"
        end
        return lib
    end

    local VoidUI, loadErr = loadVoidUI()
    if not VoidUI then
        warn("[HAVOC] VoidUI unavailable:", loadErr, "| core still active | Num1-4 | RMB")
        return
    end

    local Window
    local okWin, errWin = pcall(function()
        Window = VoidUI:CreateWindow({
            Title = BRAND,
            Author = "HAVOC Internal · " .. BRAND_DISCORD,
            Icon = BRAND_ICON,
            Accent = Color3.fromRGB(162, 89, 255),
            Size = UDim2.fromOffset(720, 560),
            Transparency = 0.14,
            Bloom = true,
            Search = true,
            OpenButton = true,
            ToggleKey = Enum.KeyCode.G,
            CornerRadius = 26,
        })
    end)

    if not okWin or not Window then
        warn("[HAVOC] VoidUI CreateWindow error:", tostring(errWin))
        return
    end

    havoc.CascadeWindow = Window
    havoc.VoidUIWindow = Window

    pcall(function()
        if Window.Toggle then
            Window:Toggle(true)
        end
        if Window.SelectTab then
            Window:SelectTab(1)
        end
    end)

    pcall(function()
        if VoidUI and VoidUI.Notify then
            VoidUI:Notify({ Title = "HAVOC", Content = "Press 'G' to toggle menu view!", Duration = 5 })
        end
    end)

    local toggleRefs = {}
    local sliderRefs = {}
    local dropdownRefs = {}

    local function addToggle(section, title, desc, cfgKey, onChange)
        local api = section:Toggle({
            Title = title,
            Desc = desc,
            Value = CFG[cfgKey] == true,
            Callback = function(v)
                CFG[cfgKey] = v
                SaveConfig()
                if onChange then pcall(onChange, v) end
            end,
        })
        toggleRefs[cfgKey] = api
        return api
    end

    local function addSlider(section, title, desc, min, max, cfgKey, suffix, onChange)
        local api = section:Slider({
            Title = title,
            Desc = desc,
            Min = min,
            Max = max,
            Value = CFG[cfgKey] or min,
            Suffix = suffix or "",
            Callback = function(v)
                CFG[cfgKey] = v
                SaveConfig()
                if onChange then pcall(onChange, v) end
            end,
        })
        sliderRefs[cfgKey] = api
        return api
    end

    local function addDropdown(section, title, desc, values, cfgKey, onChange)
        local api = section:Dropdown({
            Title = title,
            Desc = desc,
            Values = values,
            Value = CFG[cfgKey] or values[1],
            Callback = function(v)
                CFG[cfgKey] = v
                SaveConfig()
                if onChange then pcall(onChange, v) end
            end,
        })
        dropdownRefs[cfgKey] = api
        return api
    end

    -- ── 1. COMBAT TAB ─────────────────────────────────────────────────────
    local CombatTab = Window:Tab({ Title = "Combat", Icon = "target", Selected = true })
    local CombatPage = CombatTab:Page({ Title = "Combat Options", Columns = 2 })

    local secNpc = CombatPage:Section({ Title = "NPC Aimbot", Column = 1 })
    addToggle(secNpc, "Aimbot Entity", "Num2 · hold RMB to lock", "npcAimEnabled")
    addToggle(secNpc, "NPC Prediction", "Lead moving targets", "npcAimPrediction")
    addToggle(secNpc, "NPC FOV Circle", "Draw FOV ring", "npcAimDrawFov")
    addToggle(secNpc, "NPC Target Line", "Line to target", "npcAimTargetLine")
    addSlider(secNpc, "NPC FOV", "Target search radius", 10, 500, "npcAimFov", "px")
    addSlider(secNpc, "NPC Smooth", "Aim speed divider", 1, 25, "npcAimSmooth")
    addSlider(secNpc, "NPC Max Range", "Studs", 100, 3000, "npcAimMaxDist", "m")

    local secPlr = CombatPage:Section({ Title = "Player Aimbot", Column = 2 })
    addToggle(secPlr, "Aimbot Player", "Num1 · hold RMB to lock", "playerAimEnabled")
    addToggle(secPlr, "Player FOV Circle", "Draw FOV ring", "playerAimDrawFov")
    addToggle(secPlr, "Player Target Line", "Line to target", "playerAimTargetLine")
    addSlider(secPlr, "Player FOV", "Target search radius", 10, 500, "playerAimFov", "px")
    addSlider(secPlr, "Player Smooth", "Aim speed divider", 1, 25, "playerAimSmooth")
    addToggle(secPlr, "Player Prediction", "Lead moving targets", "playerAimPrediction")

    local secSilent = CombatPage:Section({ Title = "Silent Aim (PvP)", Column = 1 })
    addToggle(secSilent, "Silent Aim", "Bullet goes to enemy in FOV", "silentAim", function() pcall(installNetHooks) end)
    addToggle(secSilent, "Hipfire Accurate", "No ADS needed", "hipfireAccurate")
    addToggle(secSilent, "Wallbang", "Silent ignores walls", "silentAimWallbang")
    addToggle(secSilent, "Silent Needs RMB", "Only while holding RMB", "silentAimRequireRmb")
    addToggle(secSilent, "Silent Prediction", "Lead moving targets", "silentAimPrediction")
    addSlider(secSilent, "Silent FOV", "Hitbox search radius", 20, 800, "silentAimFov", "px")
    addSlider(secSilent, "Silent Max Range", "Studs", 50, 4000, "silentAimMaxDist", "m")

    local secShared = CombatPage:Section({ Title = "Shared Combat", Column = 2 })
    addToggle(secShared, "Visible Only", "LOS check for aimbot", "aimVisibleCheck")
    addToggle(secShared, "Feature Status HUD", "Bottom-left status list", "featureHud")

    -- ── 2. ESP TAB ────────────────────────────────────────────────────────
    local EspTab = Window:Tab({ Title = "ESP", Icon = "eye" })
    local EspPage = EspTab:Page({ Title = "Visual Overlays", Columns = 2 })

    local secEspEntity = EspPage:Section({ Title = "NPC / Entity ESP", Column = 1 })
    addToggle(secEspEntity, "Entity ESP", "NPC visuals", "entityEnabled")
    addToggle(secEspEntity, "Entity Box", "2D Corner Box", "entityBox")
    addToggle(secEspEntity, "Entity Name", "Display Name", "entityName")
    addToggle(secEspEntity, "Entity Distance", "Meters", "entityDistance")
    addToggle(secEspEntity, "Held Item", "Weapon name", "entityHeldItem")
    addToggle(secEspEntity, "Health Bar", "Side bar", "entityHealthBar")
    addToggle(secEspEntity, "Skeleton", "3D Bones", "entitySkeleton")
    addSlider(secEspEntity, "Entity Range", "Studs", 100, 3000, "entityMaxDist", "m")

    local secEspPlr = EspPage:Section({ Title = "Player ESP", Column = 2 })
    addToggle(secEspPlr, "Player ESP", "Player visuals", "playerEnabled")
    addToggle(secEspPlr, "Player Box", "2D Corner Box", "playerBox")
    addToggle(secEspPlr, "Player Name", "Player Name", "playerName")
    addToggle(secEspPlr, "Player Distance", "Meters", "playerDistance")
    addToggle(secEspPlr, "Held Weapon", "Weapon name", "playerHeldItem")
    addToggle(secEspPlr, "Inventory Peek", "Estimated gear value", "playerInvPeek")
    addSlider(secEspPlr, "Min Inv Value", "Filter $", 0, 100000, "playerInvMinValue", "$")
    addToggle(secEspPlr, "Health Bar", "Side bar", "playerHealthBar")
    addToggle(secEspPlr, "Skeleton", "3D Bones", "playerSkeleton")
    addSlider(secEspPlr, "Player Range", "Studs", 100, 3000, "playerMaxDist", "m")

    local secEspLoot = EspPage:Section({ Title = "Loot Containers", Column = 1 })
    addToggle(secEspLoot, "Loot ESP", "Num3 toggle", "lootEnabled")
    addToggle(secEspLoot, "Loot Distance", "Meters", "lootDistance")
    addToggle(secEspLoot, "Color Marker", "Dot marker", "lootMarker")
    addSlider(secEspLoot, "Loot Range", "Studs", 100, 5000, "lootMaxDist", "m")
    addSlider(secEspLoot, "Text Size", "Font size", 10, 20, "lootTextSize", "px")

    local secEspVis = EspPage:Section({ Title = "Visibility & Tracers", Column = 2 })
    addToggle(secEspVis, "Visibility Check", "Raycast LOS", "espVisibleCheck")
    addToggle(secEspVis, "Tint Hidden", "Occluded drawn gray", "espHiddenTint")
    addToggle(secEspVis, "Hide Occluded", "Skip behind walls", "espHideOccluded")
    addToggle(secEspVis, "Entity Tracers", "Snap lines", "entityTracer")
    addToggle(secEspVis, "Player Tracers", "Snap lines", "playerTracer")

    local secRadar = EspPage:Section({ Title = "Threat Radar", Column = 1 })
    addToggle(secRadar, "Circular Radar", "Ring + blips", "radarEnabled")
    addToggle(secRadar, "Behind Warning", "Warn if enemy behind", "threatBehind")
    addToggle(secRadar, "Targeted Warning", "Warn if aiming at you", "threatAiming")
    addToggle(secRadar, "Threat Beep", "Audio alert", "threatSound")
    addSlider(secRadar, "Radar Size", "Radius", 50, 140, "radarRadius", "px")
    addSlider(secRadar, "Radar Range", "Studs", 100, 2000, "radarMaxDist", "m")
    addSlider(secRadar, "Targeted Range", "Studs", 50, 800, "threatMaxDist", "m")

    local secExfil = EspPage:Section({ Title = "Exfil & Ground Drops", Column = 2 })
    addToggle(secExfil, "Exfil ESP", "Num4 toggle", "exfilEnabled")
    addToggle(secExfil, "Exfil Timer", "Countdown", "exfilTimer")
    addToggle(secExfil, "Line To Nearest", "Snap line", "exfilNearestLine")
    addToggle(secExfil, "Dropped Items", "Items on ground", "dropsEnabled")
    addToggle(secExfil, "Drop Value", "Trader sell $", "dropsShowValue")
    addToggle(secExfil, "Drop Buy Price", "Show vendor buyPrice", "dropsShowBuyPrice")
    addToggle(secExfil, "Drop Tag", "Category label", "dropsShowTag")
    addToggle(secExfil, "Drop Tier", "Tier & level", "dropsShowTier")
    addToggle(secExfil, "Color By Tier", "Rarity color", "dropsColorByTier")
    addToggle(secExfil, "Drop Marker", "Dot marker", "dropsMarker")
    addSlider(secExfil, "Drop Range", "Studs", 50, 3000, "dropsMaxDist", "m")
    addSlider(secExfil, "Min Drop Value", "Filter $", 0, 50000, "dropsMinValue", "$")
    addSlider(secExfil, "Min Tier", "Filter tier", 0, 5, "dropsMinTier")

    local secDropFilter = EspPage:Section({ Title = "Drop Categories", Column = 1 })
    addToggle(secDropFilter, "Show Quest", "Quest items", "dropsFilterQuest")
    addToggle(secDropFilter, "Show Ammo", "Ammunition", "dropsFilterAmmo")
    addToggle(secDropFilter, "Show Meds", "Medical supplies", "dropsFilterMed")
    addToggle(secDropFilter, "Show Armor", "Vests & helmets", "dropsFilterArmor")
    addToggle(secDropFilter, "Show Other", "Misc loot", "dropsFilterOther")

    local secQuest = EspPage:Section({ Title = "Quest Objectives", Column = 2 })
    addToggle(secQuest, "Quest Markers", "Map objectives", "questMarkerEnabled")
    addSlider(secQuest, "Quest Range", "Studs", 100, 8000, "questMaxDist", "m")

    -- ── 3. MODS TAB ───────────────────────────────────────────────────────
    local ModsTab = Window:Tab({ Title = "Mods", Icon = "zap" })
    local ModsPage = ModsTab:Page({ Title = "Weapon & Environment Mods", Columns = 2 })

    local secWeap = ModsPage:Section({ Title = "Weapon Modifiers", Column = 1 })
    addToggle(secWeap, "No Recoil", "Zero kick", "noRecoil", function() pcall(applyWeaponMods) end)
    addToggle(secWeap, "No Spread (soft)", "Tighten cone", "noSpread", function() pcall(applyWeaponMods) end)
    addToggle(secWeap, "True No Spread", "Zero spread", "trueNoSpread", function() pcall(applyWeaponMods) end)
    addToggle(secWeap, "Fast Bullet / Hitscan", "Boost velocity", "fastVel", function() pcall(applyWeaponMods) end)
    addToggle(secWeap, "Magic Bullet", "Instant hitscan + max velocity", "magicBullet", function() pcall(applyWeaponMods) end)
    addToggle(secWeap, "Zero Gravity Bullet", "No bullet drop", "zeroGravity", function() pcall(applyWeaponMods) end)
    addToggle(secWeap, "Instant ADS", "Instant zoom", "instantAds", function() pcall(applyWeaponMods) end)
    addToggle(secWeap, "Fix Sway Weights", "Zero sway", "noSway", function() pcall(applyWeaponMods) end)

    local secLight = ModsPage:Section({ Title = "Environment Lighting", Column = 2 })
    addDropdown(secLight, "Time Mode", "Day / Night override", TIME_MODES, "timeMode", function() pcall(applyTimeOfDay) end)
    addSlider(secLight, "Custom Clock", "Hour of day", 0, 24, "customClockTime", "h", function() pcall(applyTimeOfDay) end)
    addSlider(secLight, "Brightness Boost", "Night vision boost", 0, 100, "brightnessBoost", "%", function() pcall(applyTimeOfDay) end)

    -- ── 4. PLAYER TAB ─────────────────────────────────────────────────────
    local PlrTab = Window:Tab({ Title = "Player", Icon = "user" })
    local PlrPage = PlrTab:Page({ Title = "Movement & Survival", Columns = 2 })

    local secMove = PlrPage:Section({ Title = "Movement", Column = 1 })
    addToggle(secMove, "Overweight Sprint", "Sprint while heavy", "owSprint", function() pcall(installSkillHooks) end)
    addToggle(secMove, "No Weight Slowdown", "Normal speed", "noWeightSpeed", function() pcall(installSkillHooks) end)
    addToggle(secMove, "Infinite Stamina", "No drain", "infStamina", function() pcall(installSkillHooks) end)

    local secSurv = PlrPage:Section({ Title = "Survival", Column = 2 })
    addToggle(secSurv, "No Fall Damage", "Bypass fall damage", "noFall")
    addToggle(secSurv, "No Drown", "Bypass drowning", "noDrown")
    addToggle(secSurv, "Auto Self-Revive", "Use inhaler on downed", "autoSelfRevive")

    local secCombatAct = PlrPage:Section({ Title = "Combat Actions", Column = 1 })
    addToggle(secCombatAct, "Instant Finisher", "Finish downed in 12m", "autoFinisher")

    local secInteract = PlrPage:Section({ Title = "Interactions", Column = 2 })
    addToggle(secInteract, "Auto Lockpick", "Bypass lockpick minigame", "autoLockpick", function() pcall(installNetHooks) end)

    local secGear = PlrPage:Section({ Title = "Gear Toggles", Column = 1 })
    secGear:Button({
        Title = "Toggle Headlamp",
        Desc = "Requires equipped lamp",
        Icon = "lucide:sun",
        Callback = function() pcall(fireGearToggle, "lampToggle") end,
    })
    secGear:Button({
        Title = "Toggle Visor",
        Desc = "Requires equipped helmet",
        Icon = "lucide:shield",
        Callback = function() pcall(fireGearToggle, "visorToggle") end,
    })

    -- ── 5. HUD TAB ────────────────────────────────────────────────────────
    local HudTab = Window:Tab({ Title = "HUD", Icon = "list" })
    local HudPage = HudTab:Page({ Title = "Overlay HUDs", Columns = 1 })

    local secHud = HudPage:Section({ Title = "HUD Elements", Column = 1 })
    addToggle(secHud, "Raid HUD", "Overlay stats", "hudEnabled")
    addToggle(secHud, "Raid Timer", "Remaining time", "hudRaidTimer")
    addToggle(secHud, "Combat Timer", "In-combat state", "hudCombat")
    addToggle(secHud, "Loot Secured", "Secured value", "hudLootSecured")
    addToggle(secHud, "Open Exfil Count", "Available zones", "hudExfilCount")
    addToggle(secHud, "Ammo / Mag HUD", "Weapon magazine", "hudAmmo")
    addToggle(secHud, "Crosshair", "Center crosshair", "crosshair")

    -- ── 6. MENU TAB ───────────────────────────────────────────────────────
    local MenuTab = Window:Tab({ Title = "Menu", Icon = "settings" })
    local MenuPage = MenuTab:Page({ Title = "Window Settings", Columns = 1 })

    local secMenu = MenuPage:Section({ Title = "Keybinds & Controls", Column = 1 })
    secMenu:Keybind({
        Title = "Toggle Menu Key",
        Desc = "Show / hide menu window",
        Value = Enum.KeyCode.G,
        Callback = function(key)
            if key and Window.SetToggleKey then
                pcall(function() Window:SetToggleKey(key) end)
            end
        end,
    })
    secMenu:Button({
        Title = "Save Config",
        Desc = "Force write to disk",
        Icon = "lucide:save",
        Callback = function()
            pcall(SaveConfig)
            pcall(function()
                if VoidUI and VoidUI.Notify then
                    VoidUI:Notify({ Title = "HAVOC", Content = "Configuration saved successfully!", Duration = 2 })
                end
            end)
        end,
    })

    -- ── Synchronizer Helper ───────────────────────────────────────────────
    havoc.cascadeUiSync = function()
        for key, ref in pairs(toggleRefs) do
            if ref and type(ref.Set) == "function" then
                pcall(ref.Set, ref, CFG[key] == true, true)
            end
        end
        for key, ref in pairs(sliderRefs) do
            if ref and type(ref.Set) == "function" then
                pcall(ref.Set, ref, CFG[key] or 0, true)
            end
        end
        for key, ref in pairs(dropdownRefs) do
            if ref and type(ref.Set) == "function" then
                pcall(ref.Set, ref, CFG[key], true)
            end
        end
    end

    print("[HAVOC] VoidUI menu ready | Key G toggle")
end
