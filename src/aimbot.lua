return function(havoc)
    local SVC = havoc.SVC
    local LP = havoc.LP
    local CFG = havoc.CFG

    -- Shared State
    havoc.aimState = havoc.aimState or {
        npcLocked = nil, playerLocked = nil,
        npcPrev = nil, playerPrev = nil,
        npcLockUntil = 0, playerLockUntil = 0,
        silentHit = nil, silentUntil = 0,
    }
    local aimState = havoc.aimState
    local CACHE = havoc.CACHE

    -- Constants
    local AIM_LOCK_TIME = 0.35

    -- Resolve Mouse Move function
    local genv = (getgenv and getgenv()) or _G
    local moveMouseRel = mousemoverel or mouse_move_rel
        or genv.mousemoverel or genv.mouse_move_rel
        or (syn and syn.mousemoverel)
        or (fluxus and fluxus.mousemove)
        or (input and input.MouseMove)
        or (Input and Input.MouseMove)
        or (KRNL_LOADED and mousemoverel)
    havoc.moveMouseRel = moveMouseRel

    local baseCameraCache = nil
    local aimLastDt = 1 / 60
    local aimUseBaseCamera = false
    local aimErrStamp = 0

    -- Utilities
    havoc.isRightMouseDown = function()
        local ok, down = pcall(function()
            return SVC.UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        end)
        return ok and down
    end

    havoc.aimCrosshairPos = function()
        if havoc.isRightMouseDown() then
            return havoc.screenCenter()
        end
        local mb = SVC.UIS.MouseBehavior
        if mb == Enum.MouseBehavior.LockCenter or mb == Enum.MouseBehavior.LockCurrentPosition then
            return havoc.screenCenter()
        end
        local ok, mp = pcall(function() return SVC.UIS:GetMouseLocation() end)
        if ok and mp then return mp end
        return havoc.screenCenter()
    end

    havoc.getAimPart = function(ent, boneIdx)
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

    havoc.getBaseCamera = function()
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
        pcall(havoc.getBaseCamera)
    end)

    havoc.getAimPivotPos = function(bc)
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

    havoc.lookDirToCameraAngles = function(dir)
        local lx, ly, lz = dir.X, dir.Y, dir.Z
        local horiz = math.sqrt(lx * lx + lz * lz)
        if horiz < 1e-4 then
            return 0, ly > 0 and -87 or 87
        end
        return math.deg(math.atan2(-lx, -lz)), math.deg(math.atan2(ly, horiz))
    end

    havoc.lerpAngleDeg = function(a, b, t)
        local d = (b - a) % 360
        if d > 180 then d = d - 360 end
        return a + d * t
    end

    havoc.getAdsMouseBoost = function()
        local boost = havoc.isRightMouseDown() and 6 or 1
        pcall(function()
            if shared and shared.aim then boost = math.max(boost, 6) end
            local sens = SVC.UIS.MouseDeltaSensitivity
            if type(sens) == "number" and sens > 0 and sens < 0.35 then
                boost = math.max(boost, math.clamp(0.22 / sens, 4, 20))
            end
        end)
        return boost
    end

    havoc.injectMouseDelta = function(dx, dy)
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

    havoc.predictPos = function(part, fromPos, usePrediction)
        if not usePrediction or not part then return part and part.Position end
        local vel = part.AssemblyLinearVelocity
        local dist = (part.Position - fromPos).Magnitude
        local t = dist / 1000
        return part.Position + vel * t
    end

    havoc.pickTarget = function(list, boneIdx, fov, maxDist, prevModel, cpos, cross, usePrediction, targetType, skipVis)
        local best, bestScore, bestEnt = nil, math.huge, nil
        local doVis = (not skipVis) and (CFG.aimVisibleCheck == true)
        for i = 1, #list do
            local ent = list[i]
            if ent.humanoid and ent.humanoid.Health > 0 then
                local part = havoc.getAimPart(ent, boneIdx)
                if part then
                    local pos = havoc.predictPos(part, cpos, usePrediction)
                    local dist = (pos - cpos).Magnitude
                    if maxDist <= 0 or dist <= maxDist then
                        local sp, ok = havoc.w2s(pos)
                        if ok then
                            local px = (sp - cross).Magnitude
                            local effFov = (ent.model == prevModel) and (fov * 1.2) or fov
                            if px <= effFov and (not doVis or havoc.isVisible(part.Position, cpos, ent.model)) then
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

    havoc.pickTargetSticky = function(list, boneIdx, fov, maxDist, lockKey, untilKey, prevModel, cpos, cross, usePrediction, targetType)
        local now = tick()
        local locked = aimState[lockKey]
        if locked and now < aimState[untilKey] then
            local part = havoc.getAimPart(locked, boneIdx)
            if part and locked.humanoid and locked.humanoid.Health > 0 then
                local pos = havoc.predictPos(part, cpos, usePrediction)
                local sp, ok = havoc.w2s(pos)
                if ok and (sp - cross).Magnitude <= fov * 1.25 then
                    return pos, locked
                end
            end
        end

        local pos, ent = havoc.pickTarget(list, boneIdx, fov, maxDist, prevModel, cpos, cross, usePrediction, targetType)
        if ent then
            aimState[lockKey] = ent
            aimState[untilKey] = now + AIM_LOCK_TIME
        else
            aimState[lockKey] = nil
        end
        return pos, ent
    end

    havoc.smoothAimBaseCamera = function(bc, targetPos, smooth)
        local pivot = havoc.getAimPivotPos(bc)
        if not pivot then return false end

        local dir = targetPos - pivot
        local mag = dir.Magnitude
        if mag < 0.01 then return false end
        dir = dir / mag

        local tDx, tDy = havoc.lookDirToCameraAngles(dir)
        if bc._angleY then
            tDy = math.clamp(tDy, bc._angleY.Min, bc._angleY.Max)
        end

        local sm = math.clamp(smooth, 1, 25)
        local alpha = math.clamp(1 / sm, 0.18, 1)

        bc._dx = havoc.lerpAngleDeg(bc._dx, tDx, alpha)
        bc._dy = bc._dy + (tDy - bc._dy) * alpha
        return true
    end

    havoc.smoothAimMouse = function(targetPos, smooth)
        local cam = workspace.CurrentCamera
        if not cam then return false end

        local vp = cam:WorldToViewportPoint(targetPos)
        if vp.Z <= 0 then return false end

        local mp = havoc.aimCrosshairPos()
        local dx, dy = vp.X - mp.X, vp.Y - mp.Y
        if dx * dx + dy * dy < 0.25 then return false end

        local sm = math.clamp(smooth, 1, 25)
        local step = math.clamp(1 / sm, 0.15, 1) * havoc.getAdsMouseBoost()
        havoc.injectMouseDelta(dx * step, dy * step)
        return true
    end

    havoc.smoothAim = function(targetPos, smooth)
        local bc = havoc.getBaseCamera()
        if bc then
            aimUseBaseCamera = havoc.smoothAimBaseCamera(bc, targetPos, smooth)
            if aimUseBaseCamera then return end
        end
        aimUseBaseCamera = false
        havoc.smoothAimMouse(targetPos, smooth)
    end

    havoc.getSilentTargetPos = function(origin)
        if not CFG.silentAim then return nil, nil end
        if CFG.silentAimRequireRmb and not havoc.isRightMouseDown() then return nil, nil end

        local cam = workspace.CurrentCamera
        if not cam then return nil, nil end
        local cpos = cam.CFrame.Position
        local cross = havoc.aimCrosshairPos()
        local bone = CFG.silentAimBone or CFG.playerAimBone or 1
        local fov = CFG.silentAimFov or 220
        local maxDist = CFG.silentAimMaxDist or 2000
        local pred = CFG.silentAimPrediction ~= false
        local needVis = (CFG.aimVisibleCheck == true) and (CFG.silentAimWallbang ~= true)

        local function fromEnt(ent)
            if not (ent and ent.humanoid and ent.humanoid.Health > 0) then return nil end
            local part = havoc.getAimPart(ent, bone)
            if not part then return nil end
            if needVis and not havoc.isVisible(part.Position, cpos, ent.model) then return nil end
            local from = (typeof(origin) == "Vector3") and origin or cpos
            return havoc.predictPos(part, from, pred), ent
        end

        local locked = aimState.playerLocked
        if locked then
            local pos = fromEnt(locked)
            if pos then return pos, locked end
        end

        local pos, ent = havoc.pickTarget(
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

    havoc.applySilentFire = function(origin, _dir)
        if not CFG.silentAim then return nil, nil end
        local targetPos, ent = havoc.getSilentTargetPos(origin)
        if not targetPos or typeof(origin) ~= "Vector3" then return nil, nil end
        local delta = targetPos - origin
        if delta.Magnitude < 0.05 then return nil, nil end
        aimState.silentHit = ent
        aimState.silentUntil = tick() + 0.35
        return nil, delta.Unit
    end

    havoc.runAimLock = function(cpos, cross)
        if not havoc.isRightMouseDown() then
            aimState.npcLocked = nil
            aimState.playerLocked = nil
            return
        end

        local substeps = 1
        for _ = 1, substeps do
            if CFG.playerAimEnabled then
                local pos, ent = havoc.pickTargetSticky(CACHE.player, CFG.playerAimBone, CFG.playerAimFov, CFG.playerAimMaxDist,
                    "playerLocked", "playerLockUntil", aimState.playerPrev, cpos, cross, CFG.playerAimPrediction, 1)
                aimState.playerPrev = ent and ent.model
                if pos then
                    havoc.smoothAim(pos, CFG.playerAimSmooth)
                    return
                end
                aimState.playerLocked = nil
            end

            if CFG.npcAimEnabled then
                local pos, ent = havoc.pickTargetSticky(CACHE.entity, CFG.npcAimBone, CFG.npcAimFov, CFG.npcAimMaxDist,
                    "npcLocked", "npcLockUntil", aimState.npcPrev, cpos, cross, CFG.npcAimPrediction, CFG.npcAimTargetType)
                aimState.npcPrev = ent and ent.model
                if pos then
                    havoc.smoothAim(pos, CFG.npcAimSmooth)
                    return
                end
                aimState.npcLocked = nil
            end
        end
    end

    havoc.aimStep = function(dt)
        aimLastDt = (type(dt) == "number" and dt > 0) and dt or aimLastDt
        local ok, err = pcall(function()
            havoc.runAimLock(havoc.camPos(), havoc.aimCrosshairPos())
        end)
        if not ok then
            local now = tick()
            if now - (havoc.aimErrStamp or 0) > 3 then
                havoc.aimErrStamp = now
                warn("[HAVOC AIM]", err)
            end
        end
    end
end
