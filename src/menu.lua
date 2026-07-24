return function(havoc)
    local CFG = havoc.CFG
    local SaveConfig = havoc.SaveConfig
    local LP = havoc.LP
    local SVC = havoc.SVC
    local BRAND = havoc.BRAND
    local BRAND_ICON = havoc.BRAND_ICON
    local BRAND_DISCORD = havoc.BRAND_DISCORD
    local TIME_MODES = havoc.TIME_MODES
    local configLoaded = havoc.configLoaded
    local applyTimeOfDay = havoc.applyTimeOfDay
    local applyWeaponMods = havoc.applyWeaponMods
    local installSkillHooks = havoc.installSkillHooks
    local installNetHooks = havoc.installNetHooks
    local fireGearToggle = havoc.fireGearToggle

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

    -- Assign windows back to havoc context
    havoc.CascadeApp = app
    havoc.CascadeWindow = window
    havoc.CascadeGui = screenGui

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
    havoc.cascadeNotifyFn = pushNotify

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

    havoc.cascadeUiSync = function()
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
    end

    local section = window:Section({ Title = "HAVOC", Disclosure = false })

    -- Tab: Combat
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

        local sharedForm = tab:PageSection({ Title = "Shared" }):Form()
        addToggle(sharedForm, "Visible Only", "LOS for aimbot + silent (unless Wallbang)", "aimVisibleCheck")
        addToggle(sharedForm, "Feature Status HUD", "Bottom-left ON/OFF list", "featureHud")
    end

    -- Tab: ESP
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

    -- Tab: Mods
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

    -- Tab: Player
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

    -- Tab: HUD
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

    -- Tab: Menu Keybind
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
