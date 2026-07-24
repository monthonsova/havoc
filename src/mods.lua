return function(havoc)
    local SVC = havoc.SVC
    local LP = havoc.LP
    local CFG = havoc.CFG
    local CACHE = havoc.CACHE

    -- Local & Shared State Reference
    havoc.TIME_MODES = { "Auto", "Force Day", "Force Night", "Custom Time" }

    local skillsTbl, origIsUnlocked, origGetModified, origStaminaFn
    local netTbl, netTbl2, origInvoke, origFire
    local pendingLockpick
    local selfReviving = false
    local finisherBusy = false
    local timeLockBound = false
    local weaponRuntimeStamp = 0
    local weaponModStamp = 0
    local INHALER_NAME = "RV11: Emergency Resuscitator Inhaler"

    -- ── Character Skills & Stamina Hooks ─────────────────────────────────
    havoc.installSkillHooks = function()
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
                    if havoc.scriptAlive and CFG.owSprint and skill == "iron_back" and plr == LP then
                        return true
                    end
                    return origIsUnlocked(plr, skill, ...)
                end
            end
            if type(skills.getModifiedValue) == "function" then
                origGetModified = skills.getModifiedValue
                skills.getModifiedValue = function(plr, key, base, ...)
                    if havoc.scriptAlive and plr == LP then
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
                if havoc.scriptAlive and CFG.infStamina and action == "drain" then return end
                return origStaminaFn(action, ...)
            end
        end
        havoc.skillsTbl = skillsTbl
        return skillsTbl ~= nil
    end

    havoc.restoreSkillHooks = function()
        if skillsTbl then
            if origIsUnlocked then pcall(function() skillsTbl.isUnlocked = origIsUnlocked end) end
            if origGetModified then pcall(function() skillsTbl.getModifiedValue = origGetModified end) end
            skillsTbl, origIsUnlocked, origGetModified = nil, nil, nil
        end
        if origStaminaFn and shared then
            pcall(function() shared.staminaFunction = origStaminaFn end)
            origStaminaFn = nil
        end
        havoc.skillsTbl = nil
    end

    -- ── Network & Lockpick Hooks ──────────────────────────────────────────
    local function hasLockpickTool()
        local bp = LP:FindFirstChild("Backpack")
        local ch = LP.Character
        return (bp and bp:FindFirstChild("Lockpick")) or (ch and ch:FindFirstChild("Lockpick"))
    end
    havoc.hasLockpickTool = hasLockpickTool

    local function tryCompleteLockpick(force)
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
    havoc.tryCompleteLockpick = tryCompleteLockpick

    local function lockTypeOf(d)
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

    havoc.installNetHooks = function()
        if netTbl and origInvoke and origFire then return true end
        local net = shared and shared.Network
        if type(net) ~= "table" or type(net.InvokeServer) ~= "function" or type(net.FireServer) ~= "function" then
            return false
        end
        if not netTbl then netTbl, netTbl2 = net, net end
        if not origInvoke then
            origInvoke = net.InvokeServer
            net.InvokeServer = function(self, evName, ...)
                if havoc.scriptAlive and CFG.autoLockpick and evName == "interact" and hasLockpickTool() then
                    shared.lockpick = true
                end
                local rets = table.pack(origInvoke(self, evName, ...))
                if havoc.scriptAlive and CFG.autoLockpick and evName == "interact" then
                    local info = rets[2]
                    if type(info) == "table" and typeof(info.data) == "Instance" and info.pattern then
                        local okLt, lt = pcall(lockTypeOf, info.data)
                        if okLt and lt then
                            pendingLockpick = {
                                lockType = lt,
                                data = info.data,
                                session = info.session,
                                t = tick(),
                            }
                            task.delay(0.35, function() tryCompleteLockpick(true) end)
                            task.delay(1.2, function() tryCompleteLockpick(true) end)
                        end
                    end
                end
                return table.unpack(rets, 1, rets.n)
            end
        end
        if not origFire then
            origFire = net.FireServer
            net.FireServer = function(self, evName, a, b, c, ...)
                if havoc.scriptAlive and evName == "fire" then
                    if type(havoc.applySilentFire) == "function" then
                        local origin, dir = b, c
                        local nOrigin, nDir = havoc.applySilentFire(origin, dir)
                        if nOrigin ~= nil or nDir ~= nil then
                            return origFire(self, evName, a, nOrigin or origin, nDir or dir, ...)
                        end
                    end
                    return origFire(self, evName, a, b, c, ...)
                end
                if havoc.scriptAlive and evName == "vars" then
                    if CFG.noFall and a == "fall" then return end
                    if CFG.noDrown and a == "drown" then return end
                end
                return origFire(self, evName, a, b, c, ...)
            end
        end
        havoc.netTbl = netTbl
        return true
    end

    havoc.restoreNetHooks = function()
        if netTbl then
            if origInvoke then pcall(function() netTbl.InvokeServer = origInvoke end) end
            if origFire then pcall(function() netTbl2.FireServer = origFire end) end
            netTbl, netTbl2, origInvoke, origFire = nil, nil, nil, nil
        end
        havoc.netTbl = nil
    end

    -- ── Auto Self-Revive & Instant Finisher ──────────────────────────────
    local function localHumanoid()
        local char = LP.Character
        return char and char:FindFirstChildOfClass("Humanoid"), char
    end

    local function hasInhaler(char)
        local bp = LP:FindFirstChild("Backpack")
        return (bp and bp:FindFirstChild(INHALER_NAME)) or (char and char:FindFirstChild(INHALER_NAME))
    end

    havoc.tryAutoSelfRevive = function()
        if selfReviving or not netTbl then return end
        local hum, char = localHumanoid()
        if not (hum and hum:GetAttribute("Downed")) then return end
        if not hasInhaler(char) then return end
        selfReviving = true
        task.spawn(function()
            pcall(function() netTbl:InvokeServer("varsFunction", "selfRevive", { state = true }) end)
            local t = tick()
            while havoc.scriptAlive and CFG.autoSelfRevive and tick() - t < 15 do
                local h = localHumanoid()
                if not (h and h:GetAttribute("Downed")) then break end
                task.wait(0.3)
            end
            selfReviving = false
        end)
    end

    havoc.tryInstantFinisher = function(entities)
        if finisherBusy or not netTbl then return end
        local hum, char = localHumanoid()
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

    havoc.fireGearToggle = function(sub)
        if not netTbl then return end
        pcall(function() netTbl:FireServer("vars", sub) end)
    end

    -- Hook installation loop at start
    task.spawn(function()
        for _ = 1, 80 do
            if not havoc.scriptAlive then return end
            havoc.installSkillHooks()
            havoc.installNetHooks()
            if skillsTbl and netTbl and origInvoke then return end
            task.wait(0.5)
        end
        warn("[HAVOC] hooks not fully installed — some Player features may be inactive")
    end)

    -- ── Weapon Mod Patching ──────────────────────────────────────────────
    local function safeRawGet(tbl, key)
        if type(tbl) ~= "table" then return nil end
        local ok, val = pcall(rawget, tbl, key)
        return ok and val or nil
    end

    local function isWeaponModule(tbl)
        if type(tbl) ~= "table" or typeof(tbl) == "Instance" then return false end
        local recoil = safeRawGet(tbl, "recoil")
        if type(recoil) ~= "table" then return false end
        if type(safeRawGet(recoil, "vPunchBase")) ~= "number" then return false end
        local gunType = safeRawGet(tbl, "gunType")
        if gunType == nil and safeRawGet(tbl, "damage") == nil then return false end
        return true
    end

    local function getEquippedWeapon()
        local char = LP.Character
        if not char then return nil, nil, nil end
        for _, child in ipairs(char:GetChildren()) do
            local handle = child:FindFirstChild("Handle")
            if handle and (child:IsA("Tool") or child:IsA("Model")) then
                local name = child.Name
                local mod = shared and shared.cachedModules and shared.cachedModules[name]
                if mod and isWeaponModule(mod) then
                    return mod, name, child
                end
            end
        end
        return nil, nil, nil
    end

    local function zeroSpreadAxis(axis)
        if type(axis) ~= "table" then return end
        axis[1], axis[2], axis[3] = 0, 0, 1
    end

    havoc.patchWeaponTable = function(tbl)
        if type(tbl) ~= "table" or not isWeaponModule(tbl) then return end

        local recoil = safeRawGet(tbl, "recoil")
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

        if CFG.trueNoSpread then
            pcall(function()
                local spread = safeRawGet(tbl, "spread")
                if type(spread) == "table" then
                    zeroSpreadAxis(spread.x)
                    zeroSpreadAxis(spread.y)
                    zeroSpreadAxis(spread.z)
                end
                if type(tbl.spreadReduce) == "number" then tbl.spreadReduce = 100 end
                if type(tbl.crosshairRadius) == "number" then tbl.crosshairRadius = 0 end
                if type(tbl.crosshairShoveSize) == "number" then tbl.crosshairShoveSize = 0 end
                if type(tbl.aimAccuracy) == "number" then tbl.aimAccuracy = 0 end
            end)
        end

        if CFG.fastVel then
            pcall(function()
                if type(tbl.vel) == "number" then tbl.vel = 100000 end
            end)
        end

        if CFG.instantAds then
            pcall(function()
                local ads = safeRawGet(tbl, "ads_config")
                if type(ads) == "table" then
                    ads.tweenInfoIn = TweenInfo.new(0.01, Enum.EasingStyle.Linear)
                    ads.tweenInfoOut = TweenInfo.new(0.01, Enum.EasingStyle.Linear)
                end
                if type(tbl.aimWeight) == "number" and tbl.aimWeight < 1 then tbl.aimWeight = 1 end
                if type(tbl.unAimWeight) == "number" and tbl.unAimWeight < 1 then tbl.unAimWeight = 1 end
            end)
        end

        if CFG.noSway then
            pcall(function()
                if type(tbl.aimWeight) == "number" and tbl.aimWeight <= 0 then tbl.aimWeight = 1 end
                if type(tbl.unAimWeight) == "number" and tbl.unAimWeight <= 0 then tbl.unAimWeight = 1 end
                if type(tbl.weight) == "number" and tbl.weight <= 0 then tbl.weight = 1 end
            end)
        end
    end

    havoc.patchEquippedWeaponRuntime = function(inst)
        if not inst then return end
        if CFG.noSpread or CFG.trueNoSpread then
            pcall(function()
                if inst:GetAttribute("RateHeat") ~= nil then
                    inst:SetAttribute("RateHeat", 0)
                end
            end)
        end
    end

    havoc.tickWeaponRuntime = function()
        local active = CFG.trueNoSpread or CFG.instantAds or CFG.noSpread or CFG.fastVel or CFG.hipfireAccurate or CFG.silentAim
        if not active then return end
        if shared then
            if CFG.trueNoSpread or CFG.hipfireAccurate or CFG.silentAim then
                shared.aimAlpha = 1
            elseif CFG.instantAds and shared.aim then
                shared.aimAlpha = 1
            end
        end
        local now = tick()
        if now - weaponRuntimeStamp < 0.2 then return end
        weaponRuntimeStamp = now
        local _, _, inst = getEquippedWeapon()
        havoc.patchEquippedWeaponRuntime(inst)
    end

    havoc.anyWeaponModEnabled = function()
        return CFG.noRecoil or CFG.noSpread or CFG.trueNoSpread or CFG.noSway
            or CFG.fastVel or CFG.instantAds
    end

    havoc.applyWeaponMods = function()
        if not havoc.anyWeaponModEnabled() then return end

        local now = tick()
        if now - weaponModStamp < 2 then return end
        weaponModStamp = now

        local mod, name, inst = getEquippedWeapon()
        if mod then
            pcall(havoc.patchWeaponTable, mod)
            if name and shared and shared.cachedModules and shared.cachedModules[name] and shared.cachedModules[name] ~= mod then
                pcall(havoc.patchWeaponTable, shared.cachedModules[name])
            end
            havoc.patchEquippedWeaponRuntime(inst)
        end
    end

    havoc.setupWeaponModHooks = function()
        local function hookChar(char)
            local c = char.ChildAdded:Connect(function(child)
                if child:FindFirstChild("Handle") then
                    task.defer(havoc.applyWeaponMods)
                end
            end)
            table.insert(havoc.conns, c)
        end
        if LP.Character then hookChar(LP.Character) end
        local c = LP.CharacterAdded:Connect(hookChar)
        table.insert(havoc.conns, c)
    end

    -- ── Day / Night Cycle / lighting Controls ─────────────────────────────
    local function pinLighting(clockTime, ambient, outdoor, brightness)
        local Lighting = SVC.Lighting
        Lighting.ClockTime = clockTime
        Lighting.Brightness = brightness
        Lighting.Ambient = ambient
        Lighting.OutdoorAmbient = outdoor
    end

    havoc.pinForcedTime = function()
        shared.freezeCycle = true
        pcall(function() workspace:SetAttribute("LockCycle", true) end)

        if shared._HAVOC_DN_cycle == nil then
            shared._HAVOC_DN_cycle = shared.DN_cycle
        end
        shared.DN_cycle = false

        local mode = CFG.timeMode or 1
        local boost = math.clamp((CFG.brightnessBoost or 0) / 100, 0, 1)

        if mode == 2 then
            pinLighting(14,
                Color3.fromRGB(128, 128, 140),
                Color3.fromRGB(140, 140, 155),
                2 + boost * 2)
        elseif mode == 3 then
            pinLighting(2.5,
                Color3.fromRGB(55, 60, 80):Lerp(Color3.fromRGB(175, 180, 205), boost),
                Color3.fromRGB(45, 50, 70):Lerp(Color3.fromRGB(155, 165, 190), boost),
                1.2 + boost * 4)
        else
            local t = CFG.customClockTime or 14
            local isNight = t < 6 or t > 18
            if isNight then
                pinLighting(t,
                    Color3.fromRGB(60, 65, 85):Lerp(Color3.fromRGB(170, 175, 200), boost),
                    Color3.fromRGB(50, 55, 75):Lerp(Color3.fromRGB(150, 160, 185), boost),
                    1.5 + boost * 3)
            else
                pinLighting(t,
                    Color3.fromRGB(120, 125, 135):Lerp(Color3.fromRGB(185, 190, 200), boost * 0.5),
                    Color3.fromRGB(130, 135, 145):Lerp(Color3.fromRGB(195, 200, 210), boost * 0.5),
                    1.5 + boost * 3)
            end
        end
    end

    local function syncTimeLockBinding()
        local active = (CFG.timeMode or 1) > 1
        if active and not timeLockBound then
            timeLockBound = true
            pcall(function()
                SVC.RunService:BindToRenderStep("HAVOC_TIME", Enum.RenderPriority.Camera.Value + 2, havoc.pinForcedTime)
            end)
        elseif not active and timeLockBound then
            timeLockBound = false
            pcall(function() SVC.RunService:UnbindFromRenderStep("HAVOC_TIME") end)
        end
    end

    havoc.applyTimeOfDay = function()
        local mode = CFG.timeMode or 1
        if mode == 1 then
            shared.freezeCycle = false
            pcall(function() workspace:SetAttribute("LockCycle", nil) end)
            if shared._HAVOC_DN_cycle ~= nil then
                shared.DN_cycle = shared._HAVOC_DN_cycle
                shared._HAVOC_DN_cycle = nil
            end
            syncTimeLockBinding()
            return
        end

        havoc.pinForcedTime()
        syncTimeLockBinding()
    end

    task.defer(function()
        if CFG.timeMode and CFG.timeMode > 1 then havoc.applyTimeOfDay() end
    end)
end
