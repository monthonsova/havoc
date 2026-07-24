return function(havoc)
    local SVC = havoc.SVC
    local LP = havoc.LP

    -- Shared State Tables (allocated if not already present)
    havoc.CACHE = havoc.CACHE or { entity = {}, player = {}, loot = {}, exfil = {}, drops = {}, quest = {} }
    havoc.TSTAMP = havoc.TSTAMP or { entity = 0, player = 0, playerInv = 0, loot = 0, exfil = 0, drops = 0, quest = 0 }
    havoc.loot_by_model = havoc.loot_by_model or {}
    havoc.inv_price_cursor = havoc.inv_price_cursor or 0

    local CACHE = havoc.CACHE
    local TSTAMP = havoc.TSTAMP
    local loot_by_model = havoc.loot_by_model

    -- Constants
    havoc.BONE_NAMES = {
        "Head", "Torso", "UpperTorso", "LowerTorso",
        "Left Arm", "Right Arm", "Left Leg", "Right Leg",
        "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "RightUpperArm", "RightLowerArm", "RightHand",
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "RightUpperLeg", "RightLowerLeg", "RightFoot",
    }
    havoc.SKELETON_R15 = {
        { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
        { "UpperTorso", "LeftUpperArm" }, { "UpperTorso", "RightUpperArm" },
        { "LeftUpperArm", "LeftLowerArm" }, { "RightUpperArm", "RightLowerArm" },
        { "LeftLowerArm", "LeftHand" }, { "RightLowerArm", "RightHand" },
        { "LowerTorso", "LeftUpperLeg" }, { "LowerTorso", "RightUpperLeg" },
        { "LeftUpperLeg", "LeftLowerLeg" }, { "RightUpperLeg", "RightLowerLeg" },
        { "LeftLowerLeg", "LeftFoot" }, { "RightLowerLeg", "RightFoot" },
    }
    havoc.SKELETON_R6 = {
        { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
        { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
    }

    havoc.HEAD_OFFSET = 2.6
    havoc.FOOT_OFFSET = 3.2
    local PLAYER_MATCH_DIST = 5.0
    local LOOT_SCAN_INTERVAL = 15
    local LOOT_LIVE_BATCH = 12
    local loot_live_cursor = 1
    local INV_PRICE_BATCH = 2
    local QUEST_PLACEHOLDER = Vector3.new(10000, 10000, 10000)
    local ENTITY_NODES_PER_TICK = 35
    local CACHE_TICK = 0.2
    local ENTITY_PRUNE_INTERVAL = 1.5
    local ENTITY_RESCAN_INTERVAL = 5
    local EXFIL_RESCAN_INTERVAL = 6
    local PLAYER_RESCAN_INTERVAL = 1.5
    local DROPS_RESCAN_INTERVAL = 4.5
    local QUEST_RESCAN_INTERVAL = 4

    local cacheAccum = 0
    local entityPruneStamp = 0
    local entityRescanStamp = -5

    local characters_folder, buildings_folder

    -- Raycast parameters for Line of Sight checks
    local visParams = RaycastParams.new()
    visParams.FilterType = Enum.RaycastFilterType.Exclude
    visParams.IgnoreWater = true
    local visIgnore = {}
    local visIgnoreStamp = 0

    -- Math / Camera Utilities
    havoc.instKey = function(inst)
        if not inst then return "nil" end
        return tostring(inst):gsub("%W", "_")
    end

    havoc.entDrawKey = function(prefix, ent)
        if ent.model then
            local plr = SVC.Players:GetPlayerFromCharacter(ent.model)
            if plr then return prefix .. plr.UserId end
        end
        return prefix .. havoc.instKey(ent.model)
    end

    havoc.safeDrawKey = function(key)
        return tostring(key):gsub("%W", "_")
    end

    havoc.posKey = function(pos)
        return string.format("%x_%x_%x", math.floor(pos.X * 0.1), math.floor(pos.Y * 0.1), math.floor(pos.Z * 0.1))
    end

    havoc.w2s = function(pos)
        local cam = workspace.CurrentCamera
        if not cam then return nil, false end
        local v = cam:WorldToViewportPoint(pos)
        if v.Z <= 0 then return nil, false end
        return Vector2.new(v.X, v.Y), true
    end

    havoc.camPos = function()
        local cam = workspace.CurrentCamera
        return cam and cam.CFrame.Position or Vector3.zero
    end

    havoc.screenCenter = function()
        local cam = workspace.CurrentCamera
        if not cam then return Vector2.new(960, 540) end
        local vs = cam.ViewportSize
        return Vector2.new(vs.X * 0.5, vs.Y * 0.5)
    end

    -- Loot categorizations
    havoc.nameMatches = function(name, pattern)
        if type(pattern) == "table" then
            for i = 1, #pattern do
                if string.find(name, pattern[i], 1, true) then return true end
            end
            return false
        end
        return pattern and string.find(name, pattern, 1, true) ~= nil
    end

    havoc.lootTypeEntry = function(lootTypeId)
        if not lootTypeId then return nil end
        local key = havoc.LOOT_TYPE_ID[lootTypeId]
        if not key then return nil end
        for i = 1, #havoc.LOOT_TYPES do
            if havoc.LOOT_TYPES[i].key == key then return havoc.LOOT_TYPES[i] end
        end
        return nil
    end

    havoc.categorizeLoot = function(name, lootTypeId)
        local byType = havoc.lootTypeEntry(lootTypeId)
        if byType then return byType end
        for i = 1, #havoc.LOOT_TYPES do
            local e = havoc.LOOT_TYPES[i]
            if e.match and e.match ~= "__body_bag__" and havoc.nameMatches(name, e.match) then
                return e
            end
        end
        return havoc.LOOT_TYPES[#havoc.LOOT_TYPES - 1]
    end

    havoc.getLootRoot = function(model)
        local pp = model.PrimaryPart
        if pp and pp:IsA("BasePart") then return pp end
        for _, partName in ipairs({ "Base", "Bottom", "Handle" }) do
            local part = model:FindFirstChild(partName)
            if part and part:IsA("BasePart") then return part end
        end
        return model:FindFirstChildWhichIsA("BasePart")
    end

    havoc.collectBodyParts = function(model)
        local parts, sizes = {}, {}
        for j = 1, #havoc.BONE_NAMES do
            local name = havoc.BONE_NAMES[j]
            local p = model:FindFirstChild(name, true)
            if p and p:IsA("BasePart") then
                parts[name] = p
                sizes[name] = p.Size
            end
        end
        return parts, sizes
    end

    havoc.resolveCharactersFolder = function()
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

    havoc.isPlayerCharacter = function(model, root)
        for _, p in ipairs(SVC.Players:GetPlayers()) do
            if p.Character == model then return true end
            local pr = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if pr and (pr.Position - root.Position).Magnitude < PLAYER_MATCH_DIST then return true end
        end
        return false
    end

    -- Visibility Checking
    havoc.refreshVisIgnore = function()
        local now = tick()
        if now - visIgnoreStamp < 1 and #visIgnore > 0 then return end
        visIgnoreStamp = now
        local list = {}
        local function add(inst)
            if inst then list[#list + 1] = inst end
        end
        add(LP.Character)
        add(havoc.resolveCharactersFolder())
        for _, p in ipairs(SVC.Players:GetPlayers()) do
            add(p.Character)
        end
        add(workspace:FindFirstChild("Ignored"))
        add(workspace:FindFirstChild("_weldobjects.temp.others"))
        add(workspace:FindFirstChild("_weldobjects.temp"))
        add(workspace.CurrentCamera)
        visIgnore = list
        visParams.FilterDescendantsInstances = list
    end

    havoc.isVisible = function(targetPos, fromPos, ignoreModel)
        fromPos = fromPos or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position) or Vector3.zero
        havoc.refreshVisIgnore()
        local dir = targetPos - fromPos
        local mag = dir.Magnitude
        if mag < 4 then return true end
        local ok, res = pcall(workspace.Raycast, workspace, fromPos, dir, visParams)
        if not ok then return true end
        if res == nil then return true end
        if ignoreModel and res.Instance and res.Instance:IsDescendantOf(ignoreModel) then return true end
        return false
    end

    -- Scanning Players & Entities
    havoc.getPlayersList = function()
        local out, seen = {}, {}

        local function addEntry(model, displayName)
            if not model or seen[model] then return end
            local hum = model:FindFirstChildOfClass("Humanoid")
            local root = model:FindFirstChild("HumanoidRootPart")
                or model:FindFirstChild("UpperTorso")
                or model:FindFirstChildWhichIsA("BasePart")
            if hum and root and hum.Health > 0 then
                seen[model] = true
                local parts, sizes = havoc.collectBodyParts(model)
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

        local folder = havoc.resolveCharactersFolder()
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

    havoc.collectEntities = function(container, out, depth)
        if depth > 6 or not container then return end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Model") or child:IsA("WorldModel") then
                local hum = child:FindFirstChildOfClass("Humanoid")
                if hum then
                    local root = child:FindFirstChild("HumanoidRootPart")
                        or child:FindFirstChild("Torso")
                        or child:FindFirstChild("UpperTorso")
                        or child:FindFirstChildWhichIsA("BasePart")
                    if root and not havoc.isPlayerCharacter(child, root) then
                        local parts, sizes = havoc.collectBodyParts(child)
                        out[#out + 1] = { model = child, root = root, humanoid = hum, parts = parts, part_size = sizes }
                    end
                else
                    havoc.collectEntities(child, out, depth + 1)
                end
            elseif child:IsA("Folder") then
                havoc.collectEntities(child, out, depth + 1)
            end
        end
    end

    local entityScan = { stack = {}, out = {}, active = false }

    havoc.addEntityModel = function(child)
        local hum = child:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local root = child:FindFirstChild("HumanoidRootPart")
            or child:FindFirstChild("Torso")
            or child:FindFirstChild("UpperTorso")
            or child:FindFirstChildWhichIsA("BasePart")
        if not root or havoc.isPlayerCharacter(child, root) then return end
        local parts, sizes = havoc.collectBodyParts(child)
        entityScan.out[#entityScan.out + 1] = {
            model = child, root = root, humanoid = hum, parts = parts, part_size = sizes,
        }
    end

    havoc.pushEntityScanFrame = function(depth, children)
        entityScan.stack[#entityScan.stack + 1] = { depth = depth, i = 1, children = children }
    end

    havoc.processEntityScanChild = function(child, depth)
        if depth > 6 then return end
        if child:IsA("Model") or child:IsA("WorldModel") then
            if child:FindFirstChildOfClass("Humanoid") then
                havoc.addEntityModel(child)
            else
                havoc.pushEntityScanFrame(depth + 1, child:GetChildren())
            end
        elseif child:IsA("Folder") then
            havoc.pushEntityScanFrame(depth + 1, child:GetChildren())
        end
    end

    havoc.beginEntityRescan = function()
        if entityScan.active then return end
        local root = havoc.resolveCharactersFolder()
        if not root then
            CACHE.entity = {}
            return
        end
        entityScan.active = true
        entityScan.out = {}
        entityScan.stack = { { depth = 0, i = 1, children = root:GetChildren() } }
    end

    havoc.stepEntityRescan = function(budget)
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
                havoc.processEntityScanChild(child, frame.depth)
            end
        end
        if #entityScan.stack == 0 then
            CACHE.entity = entityScan.out
            entityScan.active = false
        end
    end

    havoc.pruneEntityCache = function()
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

    -- Loot logic
    havoc.getLootInfo = function(model)
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
    havoc.getOrCreateLootEntry = function(model, root, category, is_open_inst, is_locked_inst)
        if not BODY_BAG_CATEGORY then
            for i = 1, #havoc.LOOT_TYPES do
                if havoc.LOOT_TYPES[i].key == "body_bag" then
                    BODY_BAG_CATEGORY = havoc.LOOT_TYPES[i]
                    break
                end
            end
        end
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

    havoc.collectLoot = function(container, out, depth, seen)
        if depth > 8 or not container then return end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Model") then
                if not seen[child] then
                    local is_open, is_locked, loot_type = havoc.getLootInfo(child)
                    if is_open then
                        local root = havoc.getLootRoot(child)
                        if root then
                            seen[child] = true
                            out[#out + 1] = havoc.getOrCreateLootEntry(child, root, havoc.categorizeLoot(child.Name, loot_type), is_open, is_locked)
                        end
                    else
                        havoc.collectLoot(child, out, depth + 1, seen)
                    end
                end
            elseif child:IsA("Folder") or child:IsA("WorldModel") then
                havoc.collectLoot(child, out, depth + 1, seen)
            end
        end
    end

    havoc.collectLootDeep = function(root, out, seen)
        if not root then return end
        local ok, descendants = pcall(function() return root:GetDescendants() end)
        if not ok or not descendants then return end
        for i = 1, #descendants do
            local inst = descendants[i]
            if inst:IsA("Model") and not seen[inst] then
                local is_open, is_locked, loot_type = havoc.getLootInfo(inst)
                if is_open then
                    local partRoot = havoc.getLootRoot(inst)
                    if partRoot then
                        seen[inst] = true
                        out[#out + 1] = havoc.getOrCreateLootEntry(inst, partRoot, havoc.categorizeLoot(inst.Name, loot_type), is_open, is_locked)
                    end
                end
            end
            if i % 100 == 0 then task.wait() end
        end
    end

    havoc.collectBodyBags = function(buildings, out, seen)
        if not BODY_BAG_CATEGORY then
            for i = 1, #havoc.LOOT_TYPES do
                if havoc.LOOT_TYPES[i].key == "body_bag" then
                    BODY_BAG_CATEGORY = havoc.LOOT_TYPES[i]
                    break
                end
            end
        end
        local loots1 = buildings:FindFirstChild("Loots")
        local loots2 = loots1 and loots1:FindFirstChild("Loots")
        local characters = loots2 and loots2:FindFirstChild("Characters")
        if not characters then return end

        for _, child in ipairs(characters:GetChildren()) do
            if child:IsA("Model") and not seen[child] then
                local root = child:FindFirstChildWhichIsA("BasePart")
                if root then
                    seen[child] = true
                    out[#out + 1] = havoc.getOrCreateLootEntry(child, root, BODY_BAG_CATEGORY or havoc.LOOT_TYPES[#havoc.LOOT_TYPES], nil, nil)
                end
            end
        end
    end

    havoc.getWeldTempFolder = function()
        local ignored = workspace:FindFirstChild("Ignored")
        return ignored and ignored:FindFirstChild("_weldobjects.temp")
    end

    havoc.resolveDropName = function(inst)
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

    -- Pricing DB
    local priceFn
    local itemDataMod

    havoc.TIER_ESP_COLORS = {
        common = Color3.fromRGB(190, 190, 190),
        uncommon = Color3.fromRGB(70, 210, 190),
        rare = Color3.fromRGB(190, 110, 255),
        contraband = Color3.fromRGB(220, 200, 70),
        mythic = Color3.fromRGB(255, 70, 70),
        usable = Color3.fromRGB(110, 220, 130),
        keys = Color3.fromRGB(230, 195, 70),
        cash = Color3.fromRGB(90, 255, 110),
    }
    havoc.TIER_LEVEL_COLORS = {
        [0] = Color3.fromRGB(90, 255, 110),
        [1] = Color3.fromRGB(190, 190, 190),
        [2] = Color3.fromRGB(70, 210, 190),
        [3] = Color3.fromRGB(190, 110, 255),
        [4] = Color3.fromRGB(255, 150, 210),
        [5] = Color3.fromRGB(255, 70, 70),
    }
    havoc.CAT_TAG = {
        ammo = "AMMO",
        mags = "AMMO",
        medical = "MED",
        armor = "ARMOR",
        helmet = "ARMOR",
        lower_armor = "ARMOR",
        mask = "ARMOR",
        backpack = "ARMOR",
    }
    havoc.DEFAULT_DROP_COL = Color3.fromRGB(255, 210, 80)

    havoc.ensurePriceFn = function()
        if priceFn ~= nil then return priceFn ~= false end
        local ok, fn = pcall(function()
            if not shared.cachedModules then shared.cachedModules = {} end
            local storage = SVC.RS:WaitForChild("Storage", 8)
            return require(storage.Modules.Helper.getTotalPrice)
        end)
        priceFn = ok and fn or false
        return priceFn ~= false
    end

    havoc.ensureItemData = function()
        if itemDataMod ~= nil then return itemDataMod ~= false end
        local ok, mod = pcall(function()
            local storage = SVC.RS:WaitForChild("Storage", 8)
            return require(storage.Modules.Library.itemData)
        end)
        itemDataMod = (ok and type(mod) == "table" and mod) or false
        return itemDataMod ~= false
    end

    havoc.formatMoney = function(n)
        n = math.floor((n or 0) + 0.5)
        local s = tostring(math.abs(n))
        local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return n < 0 and "-" .. formatted or formatted
    end

    havoc.getDropValue = function(inst)
        if not inst or not havoc.ensurePriceFn() then return nil end
        local ok, val = pcall(priceFn, inst, 0, 0)
        if ok and type(val) == "number" then return math.floor(val + 0.5) end
        return nil
    end

    havoc.lookupItemMeta = function(itemName)
        if not itemName or not havoc.ensureItemData() then return nil end
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
        elseif cat and havoc.CAT_TAG[cat] then
            tag = havoc.CAT_TAG[cat]
        end

        local col = havoc.TIER_ESP_COLORS[tierType] or havoc.TIER_LEVEL_COLORS[tierLevel] or havoc.DEFAULT_DROP_COL
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

    havoc.dropPassesFilters = function(entry)
        if not entry then return false end
        local minVal = havoc.CFG.dropsMinValue or 0
        local val = entry.value
        if minVal > 0 then
            if val == nil or val < minVal then return false end
        end

        local meta = entry.meta
        local tierLevel = (meta and meta.tierLevel) or 1
        if tierLevel < (havoc.CFG.dropsMinTier or 1) then return false end

        local tag = meta and meta.tag
        if tag == "QUEST" then
            return havoc.CFG.dropsFilterQuest ~= false
        elseif tag == "AMMO" then
            return havoc.CFG.dropsFilterAmmo ~= false
        elseif tag == "MED" then
            return havoc.CFG.dropsFilterMed ~= false
        elseif tag == "ARMOR" then
            return havoc.CFG.dropsFilterArmor ~= false
        end
        return havoc.CFG.dropsFilterOther ~= false
    end

    havoc.enrichDropEntry = function(entry, child)
        if not entry then return end
        local name = entry.name or (child and child.Name)
        local meta = havoc.lookupItemMeta(name)
        if not meta and child and child.Name ~= name then
            meta = havoc.lookupItemMeta(child.Name)
        end
        entry.meta = meta

        if havoc.CFG.dropsShowValue then
            local cached = child and child:GetAttribute("_havocPrice")
            if typeof(cached) == "number" then
                entry.value = cached
            else
                local val = havoc.getDropValue(child)
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

    havoc.resolveObjectivePos = function(child)
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

    havoc.isValidObjectivePos = function(pos)
        if typeof(pos) ~= "Vector3" then return false end
        return (pos - QUEST_PLACEHOLDER).Magnitude > 100
    end

    havoc.parseObjectiveLabel = function(name)
        local s = name:gsub("-point$", "")
        local _, obj = s:match("^(.-)%-(.+)$")
        if obj then return obj:gsub("_", " ") end
        return s:gsub("_", " ")
    end

    havoc.getEquippedAmmo = function()
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

    havoc.resolveDropPart = function(inst)
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

    havoc.isDropInstance = function(inst)
        if not inst or not inst.Parent then return false end
        if inst.Name == "Cash" then return false end
        if string.find(inst.Name, "-Holsters", 1, true) then return false end
        if inst:FindFirstChild("_data") or inst:FindFirstChild("data") then return true end
        if inst:FindFirstChild("currentWeldModel") then return true end
        if inst:IsA("Tool") then return true end
        if inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChild("Handle")) then return true end
        return false
    end

    havoc.collectGroundDrops = function(out, seen)
        local roots = {}
        local weldTemp = havoc.getWeldTempFolder()
        if weldTemp then roots[#roots + 1] = weldTemp end
        local others = workspace:FindFirstChild("_weldobjects.temp.others")
        if others then roots[#roots + 1] = others end

        for r = 1, #roots do
            local root = roots[r]
            for _, child in ipairs(root:GetChildren()) do
                if not seen[child] and havoc.isDropInstance(child) then
                    local part = havoc.resolveDropPart(child)
                    if part and part:IsDescendantOf(game) then
                        seen[child] = true
                        local entry = {
                            name = havoc.resolveDropName(child),
                            pos = part.Position,
                            root = part,
                            inst = child,
                        }
                        havoc.enrichDropEntry(entry, child)
                        out[#out + 1] = entry
                    end
                end
            end
        end
    end

    havoc.tickWorldCaches = function(dt)
        cacheAccum = cacheAccum + (typeof(dt) == "number" and dt or 0)
        if cacheAccum < CACHE_TICK then return end
        cacheAccum = 0

        havoc.stepEntityRescan(ENTITY_NODES_PER_TICK)

        local now = tick()
        if now - entityPruneStamp >= ENTITY_PRUNE_INTERVAL then
            entityPruneStamp = now
            havoc.pruneEntityCache()
        end
        if now - entityRescanStamp >= ENTITY_RESCAN_INTERVAL and not entityScan.active then
            entityRescanStamp = now
            havoc.beginEntityRescan()
        end

        havoc.refreshCaches(now)
    end

    havoc.refreshLootCache = function()
        if not buildings_folder then buildings_folder = workspace:FindFirstChild("Buildings") end
        local out = {}
        local seen = {}

        if buildings_folder then
            for _, b in ipairs(buildings_folder:GetChildren()) do
                if b.Name == "Loots" then
                    havoc.collectLoot(b, out, 0, seen)
                else
                    local loots = b:FindFirstChild("Loots")
                    if loots then havoc.collectLoot(loots, out, 0, seen) end
                end
            end

            local topLoots = buildings_folder:FindFirstChild("Loots")
            if topLoots then
                local inner = topLoots:FindFirstChild("Loots")
                if inner then
                    havoc.collectLoot(inner, out, 0, seen)
                    local crates = inner:FindFirstChild("Crates")
                    if crates then havoc.collectLoot(crates, out, 0, seen) end
                end
                local objects = topLoots:FindFirstChild("Objects")
                if objects then havoc.collectLoot(objects, out, 0, seen) end
            end

            havoc.collectLootDeep(buildings_folder, out, seen)
            havoc.collectBodyBags(buildings_folder, out, seen)
        end

        if #out > 0 then
            local new_by_model = {}
            for i = 1, #out do
                new_by_model[out[i].model] = out[i]
            end
            havoc.loot_by_model = new_by_model
            CACHE.loot = out
        end
        TSTAMP.loot = tick()
    end

    havoc.formatMMSS = function(sec)
        if not sec or sec < 0 then return "--:--" end
        local t = math.floor(sec + 0.5)
        return string.format("%02d:%02d", math.floor(t / 60), t % 60)
    end

    havoc.getHeldItem = function(ent)
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

    havoc.getHeldTool = function(model)
        if not model then return nil end
        for _, child in ipairs(model:GetChildren()) do
            if child:IsA("Tool") then return child end
        end
        return nil
    end

    havoc.isPricableItem = function(inst)
        if not inst or not inst.Parent then return false end
        if inst:FindFirstChild("_data") or inst:FindFirstChild("data") then return true end
        if inst:IsA("Tool") then return true end
        return false
    end

    havoc.scanCharacterInventory = function(model)
        local total, count, heldName, heldValue = 0, 0, nil, nil
        if not model then return total, count, heldName, heldValue end

        local held = havoc.getHeldTool(model)
        if held then
            heldName = held.Name
            heldValue = havoc.getDropValue(held)
            if heldValue then
                total = total + heldValue
                count = count + 1
            end
        end

        local seen = {}
        if held then seen[held] = true end

        local function consider(inst)
            if not inst or seen[inst] or not havoc.isPricableItem(inst) then return end
            if inst:IsA("BasePart") or inst:IsA("Humanoid") or inst:IsA("Accoutrement") then return end
            if inst.Name == "Handle" or inst.Name == "HumanoidRootPart" then return end
            seen[inst] = true
            local val = havoc.getDropValue(inst)
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

    havoc.refreshPlayerInventoryCache = function(budget)
        if not havoc.CFG.playerInvPeek then return end
        havoc.ensurePriceFn()
        havoc.ensureItemData()
        budget = budget or INV_PRICE_BATCH
        local n = #CACHE.player
        if n == 0 then return end

        local inv_price_cursor = havoc.inv_price_cursor or 0
        local done = 0
        while done < budget and done < n do
            inv_price_cursor = inv_price_cursor + 1
            if inv_price_cursor > n then inv_price_cursor = 1 end
            local ent = CACHE.player[inv_price_cursor]
            if ent and ent.model and ent.model.Parent then
                local total, count, heldName, heldValue = havoc.scanCharacterInventory(ent.model)
                ent.invTotal = total
                ent.invCount = count
                ent.heldName = heldName
                ent.heldValue = heldValue
            end
            done = done + 1
        end
        havoc.inv_price_cursor = inv_price_cursor
    end

    havoc.refreshCaches = function(now)
        now = now or tick()

        if now - TSTAMP.player >= PLAYER_RESCAN_INTERVAL then
            TSTAMP.player = now
            CACHE.player = havoc.getPlayersList()
        end

        if havoc.CFG.playerInvPeek and now - TSTAMP.playerInv >= 0.35 then
            TSTAMP.playerInv = now
            pcall(havoc.refreshPlayerInventoryCache, INV_PRICE_BATCH)
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

        local exfilEnabled = havoc.CFG.exfilEnabled or havoc.CFG.exfilNearestLine or havoc.CFG.hudExfilCount
        if exfilEnabled and now - TSTAMP.exfil >= EXFIL_RESCAN_INTERVAL then
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

        if havoc.CFG.dropsEnabled and now - TSTAMP.drops >= DROPS_RESCAN_INTERVAL then
            TSTAMP.drops = now
            local out, seen = {}, {}
            havoc.collectGroundDrops(out, seen)
            CACHE.drops = out
        end

        if havoc.CFG.questMarkerEnabled and now - TSTAMP.quest >= QUEST_RESCAN_INTERVAL then
            TSTAMP.quest = now
            local out = {}
            pcall(function()
                local ignored = workspace:FindFirstChild("Ignored")
                local points = ignored and ignored:FindFirstChild("ObjectivePoints")
                if not points then return end
                for _, child in ipairs(points:GetChildren()) do
                    local pos = havoc.resolveObjectivePos(child)
                    if havoc.isValidObjectivePos(pos) then
                        out[#out + 1] = {
                            name = havoc.parseObjectiveLabel(child.Name),
                            pos = pos,
                            id = child.Name,
                        }
                    end
                end
            end)
            CACHE.quest = out
        end

        havoc.hud_state = havoc.hud_state or {}
        local hud_state = havoc.hud_state
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
end
