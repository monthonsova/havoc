return function(havoc)
    local SVC = havoc.SVC
    local LP = havoc.LP
    local CFG = havoc.CFG
    local CACHE = havoc.CACHE

    -- Drawing pools
    havoc.DrawPool = havoc.DrawPool or { texts = {}, lines = {}, squares = {}, circles = {} }
    havoc.usedDraw = havoc.usedDraw or { texts = {}, lines = {}, squares = {}, circles = {} }
    havoc.DRAW_USED = { text = "texts", line = "lines", square = "squares", circle = "circles" }

    local DrawPool = havoc.DrawPool
    local usedDraw = havoc.usedDraw
    local DRAW_USED = havoc.DRAW_USED

    local ESP_INTERVAL = 1 / 20
    local DRAW_POOL_MAX = 350
    local espAccum = 0
    local espErrStamp = 0
    local threatSound = nil
    local threatBeepStamp = 0
    local HIDDEN_COLOR = Color3.fromRGB(150, 150, 155)

    local FEATURE_STATUS = {
        { cfg = "silentAim", label = "Silent Aim", color = Color3.fromRGB(255, 80, 120) },
        { cfg = "hipfireAccurate", label = "Hipfire Acc", color = Color3.fromRGB(255, 180, 90) },
        { cfg = "playerAimEnabled", label = "Aim Player", color = Color3.fromRGB(80, 200, 255) },
        { cfg = "npcAimEnabled", label = "Aim Entity", color = Color3.fromRGB(255, 120, 120) },
        { cfg = "lootEnabled", label = "Loot ESP", color = Color3.fromRGB(255, 200, 90) },
        { cfg = "exfilEnabled", label = "Exfil ESP", color = Color3.fromRGB(90, 255, 120) },
        { cfg = "radarEnabled", label = "Radar", color = Color3.fromRGB(120, 200, 255) },
    }

    -- Drawing Functions wrapper
    havoc.beginDrawFrame = function()
        table.clear(usedDraw.texts)
        table.clear(usedDraw.lines)
        table.clear(usedDraw.squares)
        table.clear(usedDraw.circles)
    end

    havoc.finishDrawFrame = function()
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

    havoc.getDraw = function(kind, pool, key, factory)
        key = havoc.safeDrawKey(key)
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

    havoc.drawText = function(key, pos, text, color, size, centered)
        if not Drawing or not Drawing.new then return end
        local d = havoc.getDraw("text", DrawPool.texts, key, function()
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

    havoc.drawLine = function(key, a, b, color, thickness)
        if not Drawing or not Drawing.new then return end
        local d = havoc.getDraw("line", DrawPool.lines, key, function()
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

    havoc.drawSquare = function(key, pos, size, color, filled, transparency)
        if not Drawing or not Drawing.new then return end
        local d = havoc.getDraw("square", DrawPool.squares, key, function()
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

    havoc.drawCircle = function(key, center, radius, color, filled)
        if not Drawing or not Drawing.new then return end
        local d = havoc.getDraw("circle", DrawPool.circles, key, function()
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

    havoc.drawCornerBox = function(key, pos, size, color)
        local x, y, w, h = pos.X, pos.Y, size.X, size.Y
        local lx, ly = w * 0.25, h * 0.25
        havoc.drawLine(key .. "_1", Vector2.new(x, y), Vector2.new(x + lx, y), color, 1.5)
        havoc.drawLine(key .. "_2", Vector2.new(x, y), Vector2.new(x, y + ly), color, 1.5)
        havoc.drawLine(key .. "_3", Vector2.new(x + w, y), Vector2.new(x + w - lx, y), color, 1.5)
        havoc.drawLine(key .. "_4", Vector2.new(x + w, y), Vector2.new(x + w, y + ly), color, 1.5)
        havoc.drawLine(key .. "_5", Vector2.new(x, y + h), Vector2.new(x + lx, y + h), color, 1.5)
        havoc.drawLine(key .. "_6", Vector2.new(x, y + h), Vector2.new(x, y + h - ly), color, 1.5)
        havoc.drawLine(key .. "_7", Vector2.new(x + w, y + h), Vector2.new(x + w - lx, y + h), color, 1.5)
        havoc.drawLine(key .. "_8", Vector2.new(x + w, y + h), Vector2.new(x + w, y + h - ly), color, 1.5)
    end

    havoc.drawSkeleton = function(key, parts, color)
        local bones = parts["UpperTorso"] and havoc.SKELETON_R15 or havoc.SKELETON_R6
        for i = 1, #bones do
            local p1, p2 = parts[bones[i][1]], parts[bones[i][2]]
            if p1 and p2 then
                local a, ok1 = havoc.w2s(p1.Position)
                local b, ok2 = havoc.w2s(p2.Position)
                if ok1 and ok2 then havoc.drawLine(key .. "_" .. i, a, b, color, 1.5) end
            end
        end
    end

    local function getBounds(root, parts)
        local top, topOk = havoc.w2s(root.Position + Vector3.new(0, havoc.HEAD_OFFSET, 0))
        local bot, botOk = havoc.w2s(root.Position - Vector3.new(0, havoc.FOOT_OFFSET, 0))
        if not (topOk and botOk) then return nil end
        local h = math.max(math.abs(bot.Y - top.Y), 1)
        local w = h * 0.5
        return Vector2.new(top.X - w * 0.5, top.Y), Vector2.new(w, h)
    end

    -- ── ESP Features ─────────────────────────────────────────────────────
    havoc.drawEntityEsp = function(prefix, ent, opts, maxDist, cpos)
        local root = ent.root
        if not root then return end
        local dist = (root.Position - cpos).Magnitude
        if dist > maxDist then return end
        if opts.hideDead and ent.humanoid.Health <= 0 then return end

        local visible = true
        if opts.visibleCheck then
            visible = havoc.isVisible(root.Position, cpos, ent.model)
            if not visible and opts.hideOccluded then return end
        end
        local col = (not visible and opts.tint) and HIDDEN_COLOR or opts.color

        local pos, size = getBounds(root, ent.parts)
        if not pos then return end

        if opts.tracer and opts.tracerFrom then
            havoc.drawLine(prefix .. "_trace", opts.tracerFrom, Vector2.new(pos.X + size.X * 0.5, pos.Y + size.Y), col, 1.3)
        end
        if opts.box then havoc.drawCornerBox(prefix .. "_box", pos, size, col) end
        if opts.healthBar then
            local hp = math.clamp(ent.humanoid.Health / math.max(ent.humanoid.MaxHealth, 1), 0, 1)
            havoc.drawSquare(prefix .. "_hpbg", Vector2.new(pos.X - 5, pos.Y), Vector2.new(3, size.Y), Color3.new(0, 0, 0), true, 0.4)
            havoc.drawSquare(prefix .. "_hp", Vector2.new(pos.X - 5, pos.Y + size.Y * (1 - hp)), Vector2.new(3, size.Y * hp), Color3.fromRGB(80, 220, 100), true, 0.2)
        end
        if opts.skeleton then havoc.drawSkeleton(prefix .. "_skel", ent.parts, col) end

        local textY = pos.Y - 4
        if opts.name then
            local label = ent.name or ent.model.Name
            if opts.healthText then
                label = string.format("%s [%d/%d]", label, math.floor(ent.humanoid.Health), math.floor(ent.humanoid.MaxHealth))
            end
            havoc.drawText(prefix .. "_name", Vector2.new(pos.X + size.X * 0.5, textY), label, col, 14)
            textY = textY - 16
        end
        if opts.heldItem then
            local held = ent.heldName or havoc.getHeldItem(ent)
            local heldVal = ent.heldValue
            if held then
                local label = held:gsub("_", " ")
                if opts.invPeek and heldVal and heldVal > 0 then
                    label = label .. " [$" .. havoc.formatMoney(heldVal) .. "]"
                end
                havoc.drawText(prefix .. "_held", Vector2.new(pos.X + size.X * 0.5, pos.Y + size.Y + 14), label, Color3.fromRGB(255, 200, 100), 13)
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
                havoc.drawText(prefix .. "_inv", Vector2.new(pos.X + size.X * 0.5, pos.Y + size.Y + below),
                    "INV $" .. havoc.formatMoney(total), invCol, 13)
                below = below + 16
            end
        end
        if opts.distance then
            havoc.drawText(prefix .. "_dist", Vector2.new(pos.X + size.X * 0.5, pos.Y + size.Y + below),
                string.format("%dm", math.floor(dist)), Color3.fromRGB(170, 170, 170), 13)
        end
    end

    havoc.lootPassesFilter = function(idx, is_open, is_locked)
        if idx == 2 then return is_locked == true end
        if idx == 3 then return is_locked ~= true end
        if idx == 4 then return is_open == true end
        if idx == 5 then return is_open ~= true end
        return true
    end

    -- ── Radar & Feature HUDs ─────────────────────────────────────────────
    local function playThreatBeep()
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

    havoc.drawThreatRadar = function(cpos)
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

        local radarR = math.clamp(CFG.radarRadius or 90, 50, 140)
        local radarC = Vector2.new(vs.X - radarR - 28, vs.Y * 0.42)
        local maxDist = math.max(CFG.radarMaxDist or 600, 50)

        local aimingName, behindCount = nil, 0

        if CFG.radarEnabled then
            havoc.drawCircle("radar_ring", radarC, radarR, Color3.fromRGB(70, 90, 110), false)
            havoc.drawCircle("radar_ring2", radarC, radarR * 0.5, Color3.fromRGB(50, 65, 80), false)
            havoc.drawLine("radar_n", radarC, radarC + Vector2.new(0, -radarR), Color3.fromRGB(90, 110, 130), 1)
            havoc.drawCircle("radar_me", radarC, 3, Color3.fromRGB(255, 255, 255), true)
            havoc.drawText("radar_lbl", Vector2.new(radarC.X, radarC.Y + radarR + 12), "RADAR", Color3.fromRGB(140, 160, 180), 11, true)
        end

        local function plotBlip(key, worldPos, col, isPlayer)
            local delta = worldPos - myPos
            local dist = delta.Magnitude
            if dist > maxDist or dist < 0.5 then return dist end

            local flat = Vector3.new(delta.X, 0, delta.Z)
            local fx = flat:Dot(flatRight)
            local fz = flat:Dot(flatLook)
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
                havoc.drawCircle(key, bp, isPlayer and 4 or 3, col, true)
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
                            havoc.drawLine("rad_arr_" .. i .. "a", tip, base + perp * 8, col, 2)
                            havoc.drawLine("rad_arr_" .. i .. "b", tip, base - perp * 8, col, 2)
                        end
                    end
                end
            end
        end

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
            havoc.drawText("threat_aim", Vector2.new(center.X, vs.Y * 0.18), "TARGETED BY " .. aimingName, Color3.fromRGB(255, 50, 50), 16, true)
            playThreatBeep()
        end
        if CFG.threatBehind and behindCount > 0 then
            havoc.drawText("threat_behind", Vector2.new(center.X, vs.Y * 0.18 + 22), behindCount .. " ENEMY BEHIND", Color3.fromRGB(255, 150, 40), 14, true)
        end
    end

    havoc.drawFeatureHud = function(cam)
        if not CFG.featureHud then return end
        local vs = cam and cam.ViewportSize
        if not vs then return end
        local x, y = 14, vs.Y - 118
        havoc.drawText("fh_title", Vector2.new(x, y), "HAVOC", Color3.fromRGB(220, 220, 230), 13, false)
        y = y + 15

        for i = 1, #FEATURE_STATUS do
            local entry = FEATURE_STATUS[i]
            local on = CFG[entry.cfg] == true
            havoc.drawText("fh_" .. i, Vector2.new(x, y),
                (on and "[ON]  " or "[OFF] ") .. entry.label,
                on and entry.color or Color3.fromRGB(120, 120, 130), 12, false)
            y = y + 14
        end

        if CFG.playerAimEnabled or CFG.npcAimEnabled or CFG.silentAim then
            local locking = havoc.isRightMouseDown()
            local silentLive = havoc.aimState.silentUntil and tick() < havoc.aimState.silentUntil
            local hint
            if silentLive then
                hint = "SILENT → TARGET"
            elseif CFG.silentAim then
                hint = "Silent: shoot when enemy in FOV"
            else
                hint = locking and "RMB LOCKING" or "RMB hold aim"
            end
            havoc.drawText("fh_rmb", Vector2.new(x, y), hint,
                silentLive and Color3.fromRGB(255, 80, 120)
                    or (locking and Color3.fromRGB(90, 255, 120) or Color3.fromRGB(150, 150, 160)),
                11, false)
        end
    end

    havoc.drawAimVisuals = function(cpos, cross)
        if not havoc.isRightMouseDown() then return end

        if CFG.playerAimEnabled and CFG.playerAimDrawFov then
            havoc.drawCircle("plr_fov", cross, CFG.playerAimFov, Color3.fromRGB(80, 200, 255), false)
        end
        if CFG.npcAimEnabled and CFG.npcAimDrawFov then
            havoc.drawCircle("npc_fov", cross, CFG.npcAimFov, Color3.new(1, 1, 1), false)
        end

        if CFG.playerAimEnabled then
            local pos, ent = havoc.pickTarget(CACHE.player, CFG.playerAimBone, CFG.playerAimFov, CFG.playerAimMaxDist,
                havoc.aimState.playerPrev, cpos, cross, CFG.playerAimPrediction, 1)
            havoc.aimState.playerLocked = ent
            havoc.aimState.playerPrev = ent and ent.model
            if pos then
                if CFG.playerAimTargetLine then
                    local sp, ok = havoc.w2s(pos)
                    if ok then havoc.drawLine("plr_aim_line", cross, sp, Color3.fromRGB(80, 200, 255), 1.5) end
                end
                return
            end
            havoc.drawText("plr_aim_miss", cross + Vector2.new(0, 44), "PLAYER AIM: no target in FOV", Color3.fromRGB(120, 200, 255), 13)
        end

        if CFG.npcAimEnabled then
            local pos, ent = havoc.pickTarget(CACHE.entity, CFG.npcAimBone, CFG.npcAimFov, CFG.npcAimMaxDist,
                havoc.aimState.npcPrev, cpos, cross, CFG.npcAimPrediction, CFG.npcAimTargetType)
            havoc.aimState.npcLocked = ent
            havoc.aimState.npcPrev = ent and ent.model
            if pos then
                if CFG.npcAimTargetLine then
                    local sp, ok = havoc.w2s(pos)
                    if ok then havoc.drawLine("npc_aim_line", cross, sp, Color3.fromRGB(255, 80, 80), 1.5) end
                end
            else
                havoc.drawText("npc_aim_miss", cross + Vector2.new(0, 28), "ENTITY AIM: no target in FOV", Color3.fromRGB(255, 120, 120), 13)
            end
        end
    end

    havoc.renderEsp = function(dt)
        if not Drawing or not Drawing.new then return end

        espAccum = espAccum + (typeof(dt) == "number" and dt or 0)
        if espAccum < ESP_INTERVAL then return end
        espAccum = 0

        havoc.beginDrawFrame()

        local ok, err = pcall(function()
            local cpos = havoc.camPos()
            local cross = havoc.aimCrosshairPos()
            local cam = workspace.CurrentCamera
            local tracerFrom = cam and Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y) or nil

            if CFG.entityEnabled then
                for i = 1, #CACHE.entity do
                    local ent = CACHE.entity[i]
                    havoc.drawEntityEsp("ent_" .. havoc.instKey(ent.model), ent, {
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
                    havoc.drawEntityEsp(havoc.entDrawKey("plr_", ent), ent, {
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
                        local is_open = loot.is_open
                        if loot.is_open_inst and loot.is_open_inst.Parent then
                            pcall(function() is_open = loot.is_open_inst.Value end)
                        end
                        local is_locked = loot.is_locked
                        if loot.is_locked_inst and loot.is_locked_inst.Parent then
                            pcall(function() is_locked = loot.is_locked_inst.Value end)
                        end
                        if havoc.lootPassesFilter(CFG.lootFilter, is_open, is_locked) then
                            local dist = (loot.pos - cpos).Magnitude
                            if dist <= CFG.lootMaxDist then
                                local sp, ok = havoc.w2s(loot.pos)
                                if ok then
                                    local col = loot.category.color or Color3.fromRGB(220, 180, 120)
                                    local label = loot.category.display
                                    if is_locked then label = label .. " [Locked]" end
                                    if CFG.lootDistance then label = label .. string.format(" [%dm]", math.floor(dist)) end
                                    local lk = loot.model and havoc.instKey(loot.model) or havoc.posKey(loot.pos)
                                    havoc.drawText("loot_" .. lk, sp, label, col, CFG.lootTextSize)
                                    if CFG.lootMarker then
                                        havoc.drawCircle("loot_mk_" .. lk, sp, 5, col, true)
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
                            local sp, ok = havoc.w2s(ex.pos)
                            if ok then
                                if CFG.exfilEnabled then
                                    local label = ex.name
                                    if CFG.exfilTimer then
                                        if ex.locked == true then label = label .. " [CLOSED]"
                                        elseif ex.timer then label = label .. " [" .. havoc.formatMMSS(ex.timer) .. "]"
                                        else label = label .. " [OPEN]" end
                                        label = label .. string.format(" [%dm]", math.floor(dist))
                                    end
                                    local col = ex.locked == true and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(90, 255, 120)
                                    havoc.drawText("exfil_" .. (ex.name or havoc.posKey(ex.pos)), sp, label, col, 13)
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
                local sp, ok = havoc.w2s(nearestExfilPos)
                if ok then
                    havoc.drawLine("exfil_line", cross, sp, Color3.fromRGB(90, 255, 120), 1.5)
                end
            end

            if CFG.dropsEnabled then
                local minVal = CFG.dropsMinValue or 0
                for i = 1, #CACHE.drops do
                    local drop = CACHE.drops[i]
                    if drop.root and drop.root.Parent then drop.pos = drop.root.Position end
                    if havoc.dropPassesFilters(drop) then
                        local dist = (drop.pos - cpos).Magnitude
                        if dist <= CFG.dropsMaxDist then
                            local sp, ok = havoc.w2s(drop.pos)
                            if ok then
                                local meta = drop.meta
                                local dropCol = havoc.DEFAULT_DROP_COL
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
                                    label = label .. " [$" .. havoc.formatMoney(drop.value) .. "]"
                                end
                                if CFG.dropsShowBuyPrice and meta and meta.buyPrice then
                                    label = label .. " [buy $" .. havoc.formatMoney(meta.buyPrice) .. "]"
                                end
                                label = label .. string.format(" [%dm]", math.floor(dist))

                                local dk = "drop_" .. i
                                havoc.drawText(dk, sp, label, dropCol, CFG.dropsTextSize)
                                if CFG.dropsMarker then
                                    havoc.drawCircle(dk .. "_mk", sp, 4, dropCol, true)
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
                            local sp, ok = havoc.w2s(q.pos)
                            if ok then
                                local label = "[QUEST] " .. q.name .. string.format(" [%dm]", math.floor(dist))
                                havoc.drawText("quest_" .. (q.id or i), sp, label, questCol, 13)
                                havoc.drawCircle("quest_mk_" .. (q.id or i), sp, 6, questCol, true)
                            end
                        end
                    end
                end
            end

            if CFG.hudEnabled then
                local y = 108
                local hud_state = havoc.hud_state or {}
                if CFG.hudRaidTimer and hud_state.raid_time then
                    havoc.drawText("hud_raid", Vector2.new(14, y), "RAID " .. havoc.formatMMSS(hud_state.raid_time), Color3.fromRGB(255, 220, 80), 13, false)
                    y = y + 16
                end
                if CFG.hudCombat and hud_state.combat_time then
                    havoc.drawText("hud_combat", Vector2.new(14, y), "COMBAT " .. havoc.formatMMSS(hud_state.combat_time), Color3.fromRGB(255, 90, 90), 13, false)
                    y = y + 16
                end
                if CFG.hudLootSecured and hud_state.loot_secured ~= nil then
                    local secured = hud_state.loot_secured == true
                    havoc.drawText("hud_loot", Vector2.new(14, y), secured and "LOOT SECURED" or "LOOT AT RISK",
                        secured and Color3.fromRGB(90, 255, 120) or Color3.fromRGB(255, 150, 60), 13, false)
                    y = y + 16
                end
                if CFG.hudExfilCount then
                    havoc.drawText("hud_exfil", Vector2.new(14, y), "OPEN EXFILS: " .. tostring(hud_state.open_exfils or 0), Color3.fromRGB(90, 255, 120), 13, false)
                end
            end

            if CFG.hudEnabled and CFG.hudAmmo then
                local ammo = havoc.getEquippedAmmo()
                if ammo and cam then
                    local sx, sy = cam.ViewportSize.X, cam.ViewportSize.Y
                    local ax, ay = sx - 160, sy - 118
                    local ammoCol = ammo.empty and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 255, 255)
                    if ammo.current and ammo.max then
                        local ratio = math.clamp(ammo.current / math.max(ammo.max, 1), 0, 1)
                        ammoCol = Color3.fromRGB(170, 0, 0):Lerp(Color3.fromRGB(255, 255, 255), ratio)
                    end
                    havoc.drawText("hud_ammo", Vector2.new(ax, ay), ammo.text, ammoCol, 16, false)
                    havoc.drawText("hud_ammo_name", Vector2.new(ax, ay - 16), (ammo.name or ""):gsub("_", " "), Color3.fromRGB(160, 165, 180), 11, false)
                end
            end

            if CFG.crosshair then
                havoc.drawLine("ch_h", Vector2.new(cross.X - 6, cross.Y), Vector2.new(cross.X + 6, cross.Y), Color3.new(1, 1, 1), 1.5)
                havoc.drawLine("ch_v", Vector2.new(cross.X, cross.Y - 6), Vector2.new(cross.X, cross.Y + 6), Color3.new(1, 1, 1), 1.5)
            end

            havoc.drawThreatRadar(cpos)
            havoc.drawFeatureHud(workspace.CurrentCamera)
            havoc.drawAimVisuals(cpos, cross)
        end)

        havoc.finishDrawFrame()

        if not ok then
            local now = tick()
            if now - espErrStamp > 3 then
                espErrStamp = now
                warn("[HAVOC ESP]", err)
            end
        end
    end
end
