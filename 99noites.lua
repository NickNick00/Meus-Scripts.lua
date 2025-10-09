-- ===================================================================
--                  CARREGAMENTO DA BIBLIOTECA WINDUI
-- ===================================================================
local WindUI

-- Função para baixar e carregar o WindUI de forma mais robusta
local function loadWindUI()
    local successHttp, httpResult = pcall(function()
        return game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua")
    end)
    if not successHttp then error("Erro de rede ao obter WindUI: " .. tostring(httpResult)) end
    if not httpResult or #httpResult == 0 then error("Código do WindUI vazio.") end

    local loaderSuccess, loaderResult = pcall(loadstring, httpResult)
    if not loaderSuccess then error("Erro de sintaxe no WindUI: " .. tostring(loaderResult)) end
    if not loaderResult then error("Loadstring retornou nil para WindUI.") end

    local executionSuccess, executionResult = pcall(loaderResult)
    if not executionSuccess then error("Erro de execução do WindUI: " .. tostring(executionResult)) end
    if not executionResult then error("WindUI não retornou o objeto da UI.") end

    return executionResult
end

local successWindUI, loadedWindUI = pcall(loadWindUI)
if not successWindUI then
    warn("Falha ao carregar WindUI:", loadedWindUI)
    error("Erro fatal: Não foi possível carregar a interface. " .. loadedWindUI)
else
    WindUI = loadedWindUI
end

-- ===================================================================
--                  VARIÁVEIS DE CONTROLE E SERVIÇOS
-- ===================================================================
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

-- ===================================================================
--                  VARIÁVEIS DE CONFIGURAÇÃO DO SCRIPT
-- ===================================================================

-- ESP
local espPlayersAtivo = false
local espHighlights = {}
local espColor = Color3.fromRGB(0, 255, 0)

-- BRING GLOBAL
local bringUntouchable = false
local bringFreecamActive = false
local bringHeight = 20
local noQuantityLimit = false
local selectedBringDestination = "Eu"
local BRING_AUTO_COOLDOWN = 1
local activeAutoBringCount = 0

-- Player original state (para Bring TP / Untouchable / Freecam)
local originalPlayerState = {
    WalkSpeed = 16,
    JumpPower = 50,
    CanCollide = true,
    Transparency = 0,
    PlatformStand = false,
    CameraType = Enum.CameraType.Custom,
    CameraSubject = nil,
    CameraCFrame = CFrame.new()
}

-- BRING METHODS
local currentBringMethod = "Rapido"
local bringSimpleMaxQuantity = 100
local bringTPCooldown = 1

-- PLAYER MOVEMENT
local currentWalkSpeed = 16
local currentJumpPower = 50

-- KILL AURA
local killAuraAtivo = false
local killAuraConnection = nil
local killAuraRange = 10

-- ===================================================================
--                  ITENS E CATEGORIAS CONFIGURÁVEIS
-- ===================================================================

local ITEM_DATABASE = {
    Log = "Combustivel", Chair = "Combustivel", Biofuel = "Combustivel", Coal = "Combustivel",
    ["Fuel Canister"] = "Combustivel", ["Oil Barrel"] = "Combustivel", Sapling = "Combustivel",
    Carrot = "Comida e Cura", Corn = "Comida e Cura", Pumpkin = "Comida e Cura", Berry = "Comida e Cura", Apple = "Comida e Cura",
    Morsel = "Comida e Cura", ["Cooked Morsel"] = "Comida e Cura", Steak = "Comida e Cura", ["Cooked Steak"] = "Comida e Cura",
    Ribs = "Comida e Cura", ["Cooked Ribs"] = "Comida e Cura", Cake = "Comida e Cura", Chili = "Comida e Cura", Stew = "Comida e Cura",
    ["Hearty Stew"] = "Comida e Cura", ["Meat? Sandwich"] = "Comida e Cura", ["Seafood Chowder"] = "Comida e Cura",
    ["Steak Dinner"] = "Comida e Cura", ["Pumpkin Soup"] = "Comida e Cura", ["BBQ Ribs"] = "Comida e Cura",
    ["Carrot Cake"] = "Comida e Cura", ["Jar o' Jelly"] = "Comida e Cura", Crab = "Comida e Cura", Salmon = "Comida e Cura",
    Swordfish = "Comida e Cura", Fruit = "Comida e Cura", Spice = "Comida e Cura", ["Dinner Meat"] = "Comida e Cura",
    Bandage = "Comida e Cura", Medkit = "Comida e Cura", Pepper = "Comida e Cura",
    Bolt = "Sucata", Screw = "Sucata", ["Sheet Metal"] = "Sucata", ["UFO Junk"] = "Sucata", ["UFO Component"] = "Sucata",
    ["UFO Scrap"] = "Sucata", ["Broken Fan"] = "Sucata", ["Old Radio"] = "Sucata", ["Broken Microwave"] = "Sucata",
    Tyre = "Sucata", ["Metal Chair"] = "Sucata", ["Old Car Engine"] = "Sucata", ["Washing Machine"] = "Sucata",
    ["Cultist Experiment"] = "Sucata", ["Cultist Prototype"] = "Sucata",
    Backpack = "Armas e Armaduras", SmallBackpack = "Armas e Armaduras", LargeBackpack = "Armas e Armaduras",
    Axe = "Armas e Armaduras", StoneAxe = "Armas e Armaduras", MetalAxe = "Armas e Armaduras", Chainsaw = "Armas e Armaduras",
    Helmet = "Armas e Armaduras", Chestplate = "Armas e Armaduras", Leggings = "Armas e Armaduras", Boots = "Armas e Armaduras",
    Torch = "Armas e Armaduras", Pickaxe = "Armas e Armaduras", Hammer = "Armas e Armaduras", FishingRod = "Armas e Armaduras",
    Bow = "Armas e Armaduras", Arrow = "Armas e Armaduras", Gun = "Armas e Armaduras", Ammo = "Armas e Armaduras",
    Shield = "Armas e Armaduras", Lantern = "Armas e Armaduras", Compass = "Armas e Armaduras", Map = "Armas e Armaduras",
    Key = "Armas e Armaduras", Radio = "Armas e Armaduras", Binoculars = "Armas e Armaduras", WaterBottle = "Armas e Armaduras",
    Cookpot = "Armas e Armaduras", TentKit = "Armas e Armaduras", SleepingBag = "Armas e Armaduras",
    ["Infernal Sword"] = "Armas e Armaduras", ["Morning Star"] = "Armas e Armaduras", Crossbow = "Armas e Armaduras",
    ["Infernal Bow"] = "Armas e Armaduras", ["Laser Sword"] = "Armas e Armaduras", ["Ray Gun"] = "Armas e Armaduras",
    ["Ice Axe"] = "Armas e Armaduras", ["Ice Sword"] = "Armas e Armaduras", ["Strong Axe"] = "Armas e Armaduras",
    ["Sword Camp Kit"] = "Armas e Armaduras", Lance = "Armas e Armaduras", ["Good Axe"] = "Armas e Armaduras",
    Revolver = "Armas e Armaduras", Rifle = "Armas e Armaduras", ["Tactical Shotgun"] = "Armas e Armaduras",
    ["Revolver Ammo"] = "Armas e Armaduras", ["Rifle Ammo"] = "Armas e Armaduras", ["Alien Armor"] = "Armas e Armaduras",
    ["Frog Boots"] = "Armas e Armaduras", ["Leather Body"] = "Armas e Armaduras", ["Iron Body"] = "Armas e Armaduras",
    ["Spiked Body"] = "Armas e Armaduras", ["Rebellion Shield"] = "Armas e Armaduras",
    ["Armor Camp Kit"] = "Armas e Armaduras", ["Obsidian Boots"] = "Armas e Armaduras",
    Flower = "Outros", Feather = "Outros", Fire = "Outros", ["Sacrifice Totem"] = "Outros", ["Old Rod"] = "Outros",
    ["Coin Pile"] = "Outros", ["Infernal Bag"] = "Outros", ["Giant Bag"] = "Outros", ["Good Bag"] = "Outros",
    ["Old Lantern"] = "Outros", ["Strong Lantern"] = "Outros", Diamond = "Outros", ["Defense Sketch"] = "Outros",
    ["Meteorite Fragment"] = "Meteorito", ["Gold Fragment"] = "Meteorito",
    ["Raw Obsidian Ore"] = "Meteorito", ["Burning Obsidian Ingot"] = "Meteorito",
    Cultist = "Cultista", ["Harpoon Cultist"] = "Cultista",
    ["Cultist Gem"] = "Cultista", ["Gem of the Forest"] = "Cultista"
}

local CATEGORY_CONTROLS = {}
for _, cat in ipairs({"Combustivel", "Comida e Cura", "Sucata", "Armas e Armaduras", "Outros", "Meteorito", "Cultista"}) do
    CATEGORY_CONTROLS[cat] = {specificItem = nil, lastIndex = 1, lastBringTimeTP = 0, autoBringActive = false, autoBringConnection = nil, lastAutoBringTime = 0}
end

-- ===================================================================
--                  FUNÇÕES AUXILIARES DE RASTREAMENTO E UTILIDADE
-- ===================================================================

local updateCooldown = 1.0 -- Debounce time for dropdowns
local find = function(tbl, value) for _, v in ipairs(tbl) do if v == value then return true end end return false end

local BRINGABLE_CATEGORIES_LIST = {}
for _, category in pairs(ITEM_DATABASE) do if not find(BRINGABLE_CATEGORIES_LIST, category) then table.insert(BRINGABLE_CATEGORIES_LIST, category) end end
table.sort(BRINGABLE_CATEGORIES_LIST)

local CAMPFIRE_STRUCTURE_NAMES = {"MainFire", "Campfire"}
local WORKBENCH_STRUCTURE_NAMES = {"CraftingBench", "Crafting Bench", "Workbench", "Work Bench", "CraftingTable", "Crafting Table"}
local CAMPGROUND_NAMES = {"Campground", "CampArea", "BaseCamp", "SmallCamp"}
local GIANT_TREE_NAMES = {"TreeGiant", "GiantTree"}
local KID_NAMES = {"DinoKid", "KrakenKid", "SquidKid", "KoalaKid"}
local ANIMAL_NAMES = {"Bunny", "Bear", "Wolf", "Spider", "Scorpion", "Crow"}
local TREE_STRUCTURE_NAMES = {"TreeBig", "Small Tree", "Snowy Small Tree", "Dead Tree1", "Dead Tree2", "Dead Tree3"}

local ALL_TRACKED_STRUCTURE_NAMES_TO_DISPLAY = {}
for _, n in ipairs(CAMPFIRE_STRUCTURE_NAMES) do table.insert(ALL_TRACKED_STRUCTURE_NAMES_TO_DISPLAY, n) end
for _, n in ipairs(WORKBENCH_STRUCTURE_NAMES) do table.insert(ALL_TRACKED_STRUCTURE_NAMES_TO_DISPLAY, n) end
for _, n in ipairs(CAMPGROUND_NAMES) do table.insert(ALL_TRACKED_STRUCTURE_NAMES_TO_DISPLAY, n) end
for _, n in ipairs(GIANT_TREE_NAMES) do table.insert(ALL_TRACKED_STRUCTURE_NAMES_TO_DISPLAY, n) end

local trackedGroundItems = {}
local trackedStructures = {}
local trackedKids = {}
local trackedAnimals = {}
local trackedTreesForKA = {}

local REPLICATED_STORAGE_EVENTS_PATH = game:GetService("ReplicatedStorage"):FindFirstChild("RemoteEvents")
local damageEvents = {}
local chopEvents = {}

local function debounce(func, delay)
    local lastCallTime = 0
    local timer = nil
    return function(...)
        local args = {...}
        local currentTime = tick()
        if currentTime - lastCallTime > delay then
            lastCallTime = currentTime
            func(unpack(args))
        else
            if timer then task.cancel(timer) end
            timer = task.delay(delay - (currentTime - lastCallTime), function()
                lastCallTime = tick()
                func(unpack(args))
            end)
        end
    end
end

local function parseDestinationString(destinationString)
    local pureName, x_str, z_str = destinationString:match("^(.-)%s*%((%d+),%s*(%d+)%)")
    if not pureName then pureName = destinationString:match("^(.-)%s*%(Player%)") or destinationString end
    local colonPos = pureName:find(":")
    if colonPos then pureName = pureName:sub(colonPos + 2) end
    return pureName, tonumber(x_str), tonumber(z_str)
end

local function getSafePosition(instance)
    if not instance or not instance.Parent then return nil end
    if instance:IsA("BasePart") then return instance.Position end
    if instance:IsA("Model") then
        local primaryPart = instance.PrimaryPart
        if primaryPart and primaryPart:IsA("BasePart") then return primaryPart.Position end
        local centerPart = instance:FindFirstChild("Center") or instance:FindFirstChild("Primary") or instance:FindFirstChildWhichIsA("BasePart")
        if centerPart and centerPart:IsA("BasePart") then return centerPart.Position end
    end
    return nil
end

local function updatePlayersEsp()
    if not espPlayersAtivo then
        for char, highlight in pairs(espHighlights) do if highlight and highlight.Parent then highlight:Destroy() end espHighlights[char] = nil end
        return
    end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            if not espHighlights[p.Character] then
                local highlight = Instance.new("Highlight")
                highlight.OutlineColor = espColor
                highlight.FillColor = espColor
                highlight.FillTransparency = 0.7
                highlight.Parent = p.Character
                espHighlights[p.Character] = highlight
            else
                espHighlights[p.Character].OutlineColor = espColor
                espHighlights[p.Character].FillColor = espColor
            end
        elseif espHighlights[p.Character] then
            if espHighlights[p.Character] and espHighlights[p.Character].Parent then espHighlights[p.Character]:Destroy() end
            espHighlights[p.Character] = nil
        end
    end
    for char, highlight in pairs(espHighlights) do
        if not char.Parent then if highlight and highlight.Parent then highlight:Destroy() end espHighlights[char] = nil end
    end
end

local function onItemAdded(instance)
    if not instance or not instance.Parent or not (instance:IsA("BasePart") or instance:IsA("Model")) then return end
    if ITEM_DATABASE[instance.Name] then trackedGroundItems[instance] = true return end
    if find(ALL_TRACKED_STRUCTURE_NAMES_TO_DISPLAY, instance.Name) then if getSafePosition(instance) then trackedStructures[instance] = true end return end
    if find(KID_NAMES, instance.Name) then if getSafePosition(instance) then trackedKids[instance] = true end return end
    if find(ANIMAL_NAMES, instance.Name) and instance:FindFirstChildOfClass("Humanoid") then if getSafePosition(instance) then trackedAnimals[instance] = true end return end
    if find(TREE_STRUCTURE_NAMES, instance.Name) then if getSafePosition(instance) then trackedTreesForKA[instance] = true end return end
end

local function onItemRemoved(instance)
    if trackedGroundItems[instance] then trackedGroundItems[instance] = nil end
    if trackedStructures[instance] then trackedStructures[instance] = nil end
    if trackedKids[instance] then trackedKids[instance] = nil end
    if trackedAnimals[instance] then trackedAnimals[instance] = nil end
    if trackedTreesForKA[instance] then trackedTreesForKA[instance] = nil end
end

local function initializeItemTracking()
    trackedGroundItems = {}; trackedStructures = {}; trackedKids = {}; trackedAnimals = {}; trackedTreesForKA = {}
    for _, instance in pairs(Workspace:GetDescendants()) do onItemAdded(instance) end
end

local debouncedUpdateBringDestinationDropdown = debounce(function(dropdown)
    local currentDestinations = {"Voce"}
    local tempTracked = {}; for inst, _ in pairs(trackedStructures) do table.insert(tempTracked, inst) end; for inst, _ in pairs(trackedKids) do table.insert(tempTracked, inst) end
    for _, instance in ipairs(tempTracked) do
        if instance and instance.Parent then
            local instancePosition = getSafePosition(instance)
            if instancePosition then
                local nameToDisplay = tostring(instance.Name)
                if find(CAMPFIRE_STRUCTURE_NAMES, instance.Name) then nameToDisplay = "Fogueira: " .. nameToDisplay
                elseif find(WORKBENCH_STRUCTURE_NAMES, instance.Name) then nameToDisplay = "Bancada: " .. nameToDisplay
                elseif find(CAMPGROUND_NAMES, instance.Name) then nameToDisplay = "Acampamento: " .. nameToDisplay
                elseif find(GIANT_TREE_NAMES, instance.Name) then nameToDisplay = "Arvore Gigante: " .. nameToDisplay
                elseif find(KID_NAMES, instance.Name) then nameToDisplay = "Crianca: " .. nameToDisplay end
                table.insert(currentDestinations, nameToDisplay .. " (" .. tostring(math.floor(instancePosition.X)) .. ", " .. tostring(math.floor(instancePosition.Z)) .. ")")
            end
        end
    end
    if dropdown and dropdown.Refresh then dropdown:Refresh(currentDestinations) else warn("Dropdown de destino do Bring (ou refresh) nao encontrado/valido!") end
end, updateCooldown)

local debouncedUpdateKidDropdown = debounce(function(dropdown)
    local currentKids = {"Nenhum"}
    for instance, _ in pairs(trackedKids) do
        if instance and instance.Parent then
            local instancePosition = getSafePosition(instance)
            if instancePosition then table.insert(currentKids, tostring(instance.Name) .. " (" .. tostring(math.floor(instancePosition.X)) .. ", " .. tostring(math.floor(instancePosition.Z)) .. ")") end
        end
    end
    if dropdown and dropdown.Refresh then dropdown:Refresh(currentKids) else warn("Dropdown de criancas (ou refresh) nao encontrado/valido!") end
end, updateCooldown)

local function getAllItemNamesForCategory(categoryName)
    local itemNames = {}; for itemName, cat in pairs(ITEM_DATABASE) do if cat == categoryName then table.insert(itemNames, itemName) end end
    return itemNames
end

-- ===================================================================
--                  FUNÇÕES DO BRING
-- ===================================================================

local function getBringTargetCFrame(destinationString, playerHrp)
    local offsetY = bringHeight 
    if destinationString == "Voce" and playerHrp and playerHrp.Parent then return playerHrp.CFrame * CFrame.new(0, offsetY, -3) end
    local pureName, targetX, targetZ = parseDestinationString(destinationString)
    local targetInstance = nil
    local allTracked = {}; for inst, _ in pairs(trackedStructures) do table.insert(allTracked, inst) end; for inst, _ in pairs(trackedKids) do table.insert(allTracked, inst) end
    for _, instance in ipairs(allTracked) do
        if instance and instance.Parent then
            local instancePos = getSafePosition(instance)
            if instancePos and instance.Name == pureName and math.floor(instancePos.X) == targetX and math.floor(instancePos.Z) == targetZ then
                targetInstance = instance; break
            end
        end
    end
    if targetInstance then
        local instancePosition = getSafePosition(targetInstance)
        if not instancePosition then return nil end
        local finalPosition = instancePosition
        if find(CAMPFIRE_STRUCTURE_NAMES, targetInstance.Name) and targetInstance:FindFirstChild("Center") then finalPosition = targetInstance.Center.Position
        elseif find(WORKBENCH_STRUCTURE_NAMES, targetInstance.Name) and targetInstance:FindFirstChild("Main") then finalPosition = targetInstance.Main.Position end
        return CFrame.new(finalPosition) * CFrame.new(0, offsetY, 0)
    end
    return nil
end

local function saveOriginalPlayerState()
    local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if humanoid then
        originalPlayerState.WalkSpeed = humanoid.WalkSpeed
        originalPlayerState.JumpPower = humanoid.JumpPower
        originalPlayerState.PlatformStand = humanoid.PlatformStand
    end
    if hrp then
        originalPlayerState.CanCollide = hrp.CanCollide
        local torso = Player.Character:FindFirstChild("Torso") or Player.Character:FindFirstChild("UpperTorso")
        originalPlayerState.Transparency = (torso and torso.Transparency) or 0
    end
    if Camera then
        originalPlayerState.CameraType = Camera.CameraType
        originalPlayerState.CameraSubject = Camera.CameraSubject
        originalPlayerState.CameraCFrame = Camera.CFrame
    end
end

local function restorePlayerState()
    local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")

    if humanoid and humanoid.Parent then
        humanoid.WalkSpeed = originalPlayerState.WalkSpeed
        humanoid.JumpPower = originalPlayerState.JumpPower
        humanoid.PlatformStand = originalPlayerState.PlatformStand
    end
    if hrp and hrp.Parent then
        hrp.CanCollide = originalPlayerState.CanCollide
        for _, part in ipairs(Player.Character:GetChildren()) do
            if part:IsA("BasePart") then
                part.Transparency = originalPlayerState.Transparency
                part.CanCollide = originalPlayerState.CanCollide
            end
        end
    end
    if Camera and originalPlayerState.CameraType then
        Camera.CameraType = originalPlayerState.CameraType
        Camera.CameraSubject = originalPlayerState.CameraSubject
        Camera.CFrame = originalPlayerState.CameraCFrame
    end
    -- WindUI:Notify({Title = "Bring", Content = "Estado do jogador restaurado.", Color = "Gray", Duration = 2})
end

local function applyPlayerBringState(disconnectCamera)
    local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp or not humanoid.Parent or not hrp.Parent then return end -- Log error if needed, but not critical

    if bringFreecamActive then
        humanoid.WalkSpeed = 0; humanoid.JumpPower = 0; humanoid.PlatformStand = true
        for _, part in ipairs(Player.Character:GetChildren()) do if part:IsA("BasePart") then part.Transparency = 1; part.CanCollide = false end end
        if Camera and disconnectCamera then Camera.CameraType = Enum.CameraType.Scriptable; Camera.CFrame = Camera.CFrame end
    elseif bringUntouchable then
        humanoid.WalkSpeed = originalPlayerState.WalkSpeed; humanoid.JumpPower = originalPlayerState.JumpPower
        humanoid.PlatformStand = originalPlayerState.PlatformStand
        for _, part in ipairs(Player.Character:GetChildren()) do if part:IsA("BasePart") then part.Transparency = originalPlayerState.Transparency; part.CanCollide = false end end
        if Camera then Camera.CameraType = originalPlayerState.CameraType end
    else -- Both off, ensure normal state
        restorePlayerState()
    end
end

local function runBringLogic(categoryName, itemsToBringList, bringRange, maxQuantity, bringCooldown, bringMethod)
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return false end
    local playerHrp = Player.Character.HumanoidRootPart
    local targetCFrame = getBringTargetCFrame(selectedBringDestination, playerHrp)
    if not targetCFrame then return false end
    if not itemsToBringList or #itemsToBringList == 0 then return false end

    local itemsFoundInRange = {}; for itemInstance, _ in pairs(trackedGroundItems) do
        if itemInstance and itemInstance.Parent and find(itemsToBringList, itemInstance.Name) then
            local itemPosition = getSafePosition(itemInstance)
            if itemPosition and (playerHrp.Position - itemPosition).Magnitude <= bringRange then table.insert(itemsFoundInRange, itemInstance) end
        end
    end
    
    local actualItemsPulled = 0
    if bringMethod == "rapido" then
        local currentMaxQuantity = noQuantityLimit and #itemsFoundInRange or maxQuantity
        local control = CATEGORY_CONTROLS[categoryName]; control.lastIndex = control.lastIndex or 1

        local itemsProcessedThisFrame = 0
        local itemsToProcess = {}
        for i=1, currentMaxQuantity do
            local itemIndex = ((control.lastIndex -1 + i -1) % #itemsFoundInRange) + 1
            if itemsFoundInRange[itemIndex] then
                table.insert(itemsToProcess, itemsFoundInRange[itemIndex])
            else break end -- No more items
        end

        for _, itemInstance in ipairs(itemsToProcess) do
            if itemInstance and itemInstance.Parent then
                local targetPart = itemInstance:IsA("Model") and itemInstance.PrimaryPart or itemInstance:FindFirstChild("Center") or itemInstance:FindFirstChild("Primary") or itemInstance:FindFirstChildWhichIsA("BasePart") or itemInstance
                if targetPart and targetPart.Parent and targetPart:IsA("BasePart") then
                    targetPart.Anchored = false; targetPart.CanCollide = false
                    local randomOffsetX = math.random() * 1.5 - 0.75; local randomOffsetZ = math.random() * 1.5 - 0.75
                    local spreadCFrame = targetCFrame * CFrame.new(randomOffsetX, 0, randomOffsetZ)
                    if itemInstance:IsA("Model") then itemInstance:SetPrimaryPartCFrame(spreadCFrame * CFrame.Angles(targetPart.CFrame:ToOrientation()))
                    else itemInstance.CFrame = spreadCFrame * CFrame.Angles(targetPart.CFrame:ToOrientation()) end
                    targetPart.CanCollide = true
                    itemsProcessedThisFrame = itemsProcessedThisFrame + 1; actualItemsPulled = actualItemsPulled + 1
                    task.wait(0.01)
                end
            end
        end
        control.lastIndex = (control.lastIndex + itemsProcessedThisFrame -1) % #itemsFoundInRange + 1
        if #itemsFoundInRange == 0 then control.lastIndex = 1 end
        return actualItemsPulled > 0
    elseif bringMethod == "Teleporte" then
        local control = CATEGORY_CONTROLS[categoryName]
        if tick() - control.lastBringTimeTP < bringCooldown then return false end
        local itemToBring = nil; local minDistance = bringRange + 1
        for itemInstance, _ in pairs(trackedGroundItems) do
            if itemInstance and itemInstance.Parent and find(itemsToBringList, itemInstance.Name) then
                local itemPosition = getSafePosition(itemInstance)
                if itemPosition then
                    local currentDistance = (playerHrp.Position - itemPosition).Magnitude
                    if currentDistance <= bringRange and currentDistance < minDistance then minDistance = currentDistance; itemToBring = itemInstance end
                end
            end
        end
        if itemToBring and itemToBring.Parent then
            local itemPosition = getSafePosition(itemToBring)
            if not itemPosition then return false end
            local currentBringFreecamActive = bringFreecamActive; local currentBringUntouchable = bringUntouchable
            -- Temporarily force freecam for teleport if not already active to avoid character movement issues
            if not currentBringFreecamActive then bringFreecamActive = true; saveOriginalPlayerState(); applyPlayerBringState(true) end

            pcall(function() playerHrp.CFrame = CFrame.new(itemPosition) * CFrame.new(0, 5, 0) end); task.wait(0.05)
            local targetPart = itemToBring:IsA("Model") and itemToBring.PrimaryPart or itemToBring:FindFirstChild("Center") or itemToBring:FindFirstChild("Primary") or itemToBring:FindFirstChildWhichIsA("BasePart") or itemToBring
            if targetPart and targetPart.Parent and targetPart:IsA("BasePart") then
                targetPart.Anchored = false; targetPart.CanCollide = false
                local randomOffsetX = math.random() * 1.5 - 0.75; local randomOffsetZ = math.random() * 1.5 - 0.75
                local spreadCFrame = targetCFrame * CFrame.new(randomOffsetX, 0, randomOffsetZ)
                if itemToBring:IsA("Model") then itemToBring:SetPrimaryPartCFrame(spreadCFrame * CFrame.Angles(targetPart.CFrame:ToOrientation()))
                else itemToBring.CFrame = spreadCFrame * CFrame.Angles(targetPart.CFrame:ToOrientation()) end
                targetPart.CanCollide = true
            end
            trackedGroundItems[itemToBring] = nil; task.wait(0.05)
            pcall(function() playerHrp.CFrame = targetCFrame * CFrame.new(0, 5, 0) end); task.wait(0.05)

            if not currentBringFreecamActive then bringFreecamActive = false; restorePlayerState() end -- Restore only if we forced it
            control.lastBringTimeTP = tick(); actualItemsPulled = actualItemsPulled + 1
            return true
        end
    end
    return actualItemsPulled > 0
end

local function bringItemsOnceForCategory(categoryName)
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then
        WindUI:Notify({Title = "Bring Manual", Content = "Personagem nao encontrado.", Color = "Red", Duration = 3}) return
    end
    local control = CATEGORY_CONTROLS[categoryName]
    if not control then return end
    if not selectedBringDestination or selectedBringDestination == "Nenhum" then
        WindUI:Notify({Title = "Bring Error", Content = "Selecione um destino valido para o Bring!", Color = "Red", Duration = 3}) return
    end
    if control.specificItem == nil or control.specificItem == "" then
        WindUI:Notify({Title = "Bring Error", Content = "Selecione um item para puxar na categoria '" .. categoryName .. "'!", Color = "Red", Duration = 3}) return
    end

    local bringRange = (currentBringMethod == "rapido" and bringSimpleRange) or bringTPRange
    local maxQuantity = (currentBringMethod == "rapido" and bringSimpleMaxQuantity) or 1
    local cooldown = (currentBringMethod == "Teleporte" and bringTPCooldown) or 0
    
    local success = runBringLogic(categoryName, {control.specificItem}, bringRange, maxQuantity, cooldown, currentBringMethod)
    if success then
        WindUI:Notify({Title = "Bring Manual", Content = "Itens de '" .. control.specificItem .. "' puxados para '" .. selectedBringDestination .. "'!", Color = "Green", Duration = 2})
    else
        WindUI:Notify({Title = "Bring Manual", Content = "Nenhum item '" .. control.specificItem .. "' encontrado no raio ou em cooldown.", Color = "Orange", Duration = 2})
    end
end

local function updateStopButtonVisibility()
    stopBringButton.Visible = (activeAutoBringCount > 0) or bringFreecamActive or bringUntouchable
end

local function activateAutoBringForCategory(categoryName)
    local control = CATEGORY_CONTROLS[categoryName]
    if control.autoBringConnection then return end
    local itemsToBringList = getAllItemNamesForCategory(categoryName)
    if #itemsToBringList == 0 then return end -- No items to bring
    control.autoBringActive = true; activeAutoBringCount = activeAutoBringCount + 1; updateStopButtonVisibility()
    -- WindUI:Notify({Title = "Bring Automatico", Content = "Bring de " .. categoryName .. " ATIVADO!", Color = "Green", Duration = 2})
    control.autoBringConnection = RunService.Heartbeat:Connect(function()
        if not control.autoBringActive then return end
        if tick() - control.lastAutoBringTime < BRING_AUTO_COOLDOWN then return end
        control.lastAutoBringTime = tick()
        local bringRange = (currentBringMethod == "Simples" and bringSimpleRange) or bringTPRange
        local maxQuantity = (currentBringMethod == "Simples" and bringSimpleMaxQuantity) or 1
        local cooldown = (currentBringMethod == "Teleporte" and bringTPCooldown) or 0 
        runBringLogic(categoryName, itemsToBringList, bringRange, maxQuantity, cooldown, currentBringMethod)
    end)
end

local function deactivateAutoBringForCategory(categoryName)
    local control = CATEGORY_CONTROLS[categoryName]
    if not control.autoBringConnection then return end
    control.autoBringConnection:Disconnect(); control.autoBringConnection = nil
    control.autoBringActive = false; activeAutoBringCount = activeAutoBringCount - 1; updateStopButtonVisibility()
    -- WindUI:Notify({Title = "Bring Automatico", Content = "Bring de " .. categoryName .. " DESATIVADO!", Color = "Gray", Duration = 2})
end

-- ===================================================================
--                  FUNÇÕES GERAIS E TELEPORTE
-- ===================================================================

local function applyPlayerMovement()
    if Player.Character then
        local humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Parent then
            humanoid.WalkSpeed = currentWalkSpeed
            humanoid.JumpPower = currentJumpPower
        end
    end
end

local function teleportToPosition(position, name)
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then
        WindUI:Notify({Title = "Teleporte", Content = "Personagem nao disponivel.", Color = "Red", Duration = 3}) return
    end
    pcall(function() Player.Character.HumanoidRootPart.CFrame = CFrame.new(position) * CFrame.new(0, 5, 0) end)
    WindUI:Notify({Title = "Teleporte", Content = "Teleportado para: " .. tostring(name) .. "!", Color = "Green", Duration = 2})
end

-- ===================================================================
--                  KILL AURA FUNÇÕES
-- ===================================================================

local function findRemoteEvents()
    if not REPLICATED_STORAGE_EVENTS_PATH then warn("KillAura: Pasta 'RemoteEvents' nao encontrada.") return end
    damageEvents = {}; chopEvents = {}
    for _, eventItem in pairs(REPLICATED_STORAGE_EVENTS_PATH:GetChildren()) do
        if eventItem:IsA("Folder") then
            local folderName = eventItem.Name
            if find(ANIMAL_NAMES, folderName) then
                local damageEvent = eventItem:FindFirstChild("Damage")
                if damageEvent and damageEvent:IsA("RemoteEvent") then damageEvents[folderName] = damageEvent end
            end
            if find(TREE_STRUCTURE_NAMES, folderName) then
                local chopEvent = eventItem:FindFirstChild("Chop")
                if chopEvent and chopEvent:IsA("RemoteEvent") then chopEvents[folderName] = chopEvent end
            end
        elseif eventItem:IsA("RemoteEvent") then
            if eventItem.Name == "HitEvent" or eventItem.Name == "DamagePlayer" then damageEvents["GenericPlayerDamage"] = eventItem
            elseif eventItem.Name == "ChopTree" or eventItem.Name == "InteractTree" then chopEvents["GenericChop"] = eventItem end
        end
    end
    -- if next(damageEvents) == nil then warn("KillAura: Nenhum RemoteEvent de dano encontrado.") end
    -- if next(chopEvents) == nil then warn("KillAura: Nenhum RemoteEvent de corte encontrado.") end
end

local function playerHasAxeEquipped()
    if not Player.Character then return nil end
    local backpack = Player:FindFirstChildOfClass("Backpack")
    if backpack then for _, item in pairs(backpack:GetChildren()) do if item:IsA("Tool") and (item.Name:find("Axe") or item.Name:find("Chainsaw")) then return item end end end
    for _, child in pairs(Player.Character:GetChildren()) do if child:IsA("Tool") and (child.Name:find("Axe") or child.Name:find("Chainsaw")) then return child end end
    return nil
end

local function toggleKillAura(state)
    killAuraAtivo = state
    if state then
        WindUI:Notify({Title = "Kill Aura", Content = "Kill Aura ATIVADA!", Color = "Green", Duration = 2})
        killAuraConnection = RunService.Heartbeat:Connect(function()
            if not Player.Character then return end
            local playerHrp = Player.Character:FindFirstChild("HumanoidRootPart")
            if not playerHrp or not playerHrp.Parent then return end
            local playerPosition = playerHrp.Position
            local equippedTool = playerHasAxeEquipped(); local hasAxe = equippedTool ~= nil

            for _, p in pairs(Players:GetPlayers()) do
                if p ~= Player and p.Character then
                    local targetChar = p.Character; local targetHrp = targetChar:FindFirstChild("HumanoidRootPart"); local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
                    if targetHrp and targetHumanoid and targetHrp.Parent and targetHumanoid.Parent and (playerPosition - targetHrp.Position).Magnitude <= killAuraRange then
                        local damageEvent = damageEvents["GenericPlayerDamage"]
                        if damageEvent then pcall(function() damageEvent:FireServer(targetHumanoid, targetHrp, 20, equippedTool and tostring(equippedTool.Name) or "Fist") end) end
                    end
                end
            end
            for animalInstance, _ in pairs(trackedAnimals) do
                if animalInstance and animalInstance.Parent then
                    local targetHrp = animalInstance:FindFirstChild("HumanoidRootPart"); local targetHumanoid = animalInstance:FindFirstChildOfClass("Humanoid")
                    local targetPosition = getSafePosition(animalInstance)
                    if targetHrp and targetHumanoid and targetHrp.Parent and targetHumanoid.Parent and targetPosition and (playerPosition - targetPosition).Magnitude <= killAuraRange then
                        local damageEvent = damageEvents[animalInstance.Name] or damageEvents["GenericPlayerDamage"]
                        if damageEvent then pcall(function() damageEvent:FireServer(targetHumanoid, targetHrp, 15, equippedTool and tostring(equippedTool.Name) or "Fist") end) end
                    end
                end
            end
            if hasAxe then
                for treeInstance, _ in pairs(trackedTreesForKA) do
                    if treeInstance and treeInstance.Parent then
                        local targetPosition = getSafePosition(treeInstance)
                        if targetPosition and (playerPosition - targetPosition).Magnitude <= killAuraRange then
                            local chopEvent = chopEvents[treeInstance.Name] or chopEvents["GenericChop"]
                            if chopEvent and equippedTool then pcall(function() chopEvent:FireServer(treeInstance, equippedTool) end) end
                        end
                    end
                end
            end
        end)
    else
        if killAuraConnection then killAuraConnection:Disconnect(); killAuraConnection = nil end
        WindUI:Notify({Title = "Kill Aura", Content = "Kill Aura DESATIVADA!", Color = "Gray", Duration = 2})
    end
end

-- ===================================================================
--                         INTERFACE GRÁFICA
-- ===================================================================

local Window = WindUI:CreateWindow({
    Title = "99 noites", Icon = "door-open", Author = "by kyuzzy", Folder = "99 noites", Size = UDim2.fromOffset(400, 550), Theme = "Dark"
})

local TabESP = Window:Tab({ Title = "ESP", Icon = "eye" })
local TabBring = Window:Tab({ Title = "Bring Stuff", Icon = "hand-point-right" })
local TabCombate = Window:Tab({ Title = "Combate", Icon = "sword" })
local TabTeleporte = Window:Tab({ Title = "Teleporte", Icon = "compass" })

TabESP:Section({ Title = "ESP de Jogadores" })
TabESP:Toggle({
    Title = "ESP de Jogadores (Verde)",
    Callback = function(state) espPlayersAtivo = state; updatePlayersEsp()
        WindUI:Notify({Title = "ESP", Content = "ESP de Jogadores " .. (state and "ATIVADO!" or "DESATIVADO!"), Color = state and "Green" or "Gray", Duration = 2}) end
})

-- ===================================
--         BRING TAB (Refatorada)
-- ===================================

TabBring:Section({ Title = "Configuracoes Gerais do Bring" })

TabBring:Toggle({
    Title = "Usar Freecam para Trazer Itens",
    Desc = "A camera permanece no lugar, personagem intangivel e invisivel. Pode ser detectado.",
    Callback = function(state)
        if state and not (bringUntouchable or bringFreecamActive) then saveOriginalPlayerState() end
        bringFreecamActive = state
        applyPlayerBringState(true)
        updateStopButtonVisibility()
        WindUI:Notify({Title = "Bring Freecam", Content = "Freecam para Bring: " .. (state and "ATIVADO" or "DESATIVADO"), Color = "Blue", Duration = 2})
    end
})

TabBring:Toggle({
    Title = "Untouchable by Outros",
    Desc = "Torna seu personagem sem colisao enquanto o Bring esta ativo. Pode ser detectado.",
    Callback = function(state)
        if state and not (bringUntouchable or bringFreecamActive) then saveOriginalPlayerState() end
        bringUntouchable = state
        applyPlayerBringState(false)
        updateStopButtonVisibility()
        WindUI:Notify({Title = "Bring Untouchable", Content = "Untouchable para Bring: " .. (state and "ATIVADO" or "DESATIVADO"), Color = "Blue", Duration = 2})
    end
})

local bringMethodDropdown_UI = TabBring:Dropdown({
    Title = "Bring Method", Values = {"rapido", "Teleporte"}, Default = currentBringMethod,
    Callback = function(name) currentBringMethod = name; WindUI:Notify({Title = "Bring Method", Content = "Metodo de Bring: " .. tostring(name), Color = "Blue", Duration = 2}) end
})

local bringLocalizationDropdown_UI = TabBring:Dropdown({
    Title = "(Destination)", Values = {"(Voce)"}, Default = selectedBringDestination,
    Callback = function(name) selectedBringDestination = name; WindUI:Notify({Title = "Bring", Content = "Destino do Bring definido para: " .. tostring(name), Color = "Blue", Duration = 2}) end
})

local bringHeightInput_UI = TabBring:Input({
    Title = "(Altura)", Placeholder = tostring(bringHeight), Default = tostring(bringHeight), Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 0 and numValue <= 200 then bringHeight = numValue
        else WindUI:Notify({Title = "Bring", Content = "Altura invalida! Use um numero entre 0 e 200.", Color = "Red", Duration = 3}); bringHeightInput_UI:Set(tostring(bringHeight)) end
    end
})

TabBring:Divider()
TabBring:Section({ Title = "Configuracoes por Metodo" })

local bringSimpleMaxQuantityInput_UI = TabBring:Input({
    Title = "Maximo de Itens por Vez (Simples)", Placeholder = tostring(bringSimpleMaxQuantity), Default = tostring(bringSimpleMaxQuantity), Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 5 and numValue <= 200 then bringSimpleMaxQuantity = numValue
        else WindUI:Notify({Title = "Bring (Simples)", Content = "Quantidade invalida! Use um numero entre 5 e 200.", Color = "Red", Duration = 3}); bringSimpleMaxQuantityInput_UI:Set(tostring(bringSimpleMaxQuantity)) end
    end
})

local bringTPCooldownInput_UI = TabBring:Input({
    Title = "Cooldown entre TP (Teleporte)", Placeholder = tostring(bringTPCooldown), Default = tostring(bringTPCooldown), Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 0.1 and numValue <= 2 then bringTPCooldown = numValue
        else WindUI:Notify({Title = "Bring (Teleporte)", Content = "Cooldown invalido! Use um numero entre 0.1 e 2.", Color = "Red", Duration = 3}); bringTPCooldownInput_UI:Set(tostring(bringTPCooldown)) end
    end
})

TabBring:Toggle({
    Title = "Sem Limite de Quantidade", Desc = "Ignora o 'Maximo de Itens por Vez', tentando puxar todos os itens do raio (pode causar lag).",
    Callback = function(state) noQuantityLimit = state; WindUI:Notify({Title = "Bring", Content = "Sem Limite de Quantidade: " .. (state and "ATIVADO" or "DESATIVADO"), Color = "Blue", Duration = 2}) end
})

TabBring:Divider()
TabBring:Section({ Title = "Bring Manual por Categoria" })

-- Consolidação da UI para Bring Manual por Categoria
for _, categoryName in ipairs(BRINGABLE_CATEGORIES_LIST) do
    local categoryControl = CATEGORY_CONTROLS[categoryName]
    local itemsInCategoryList = getAllItemNamesForCategory(categoryName)
    local defaultItem = itemsInCategoryList[1] or nil
    categoryControl.specificItem = defaultItem

    TabBring:Dropdown({
        Title = categoryName .. " (Item)", Values = itemsInCategoryList, Default = defaultItem,
        Callback = function(name) categoryControl.specificItem = name end
    })
    
    TabBring:Button({
        Title = "Trazer " .. categoryName .. " (Uma Vez)",
        Desc = "Puxa o item selecionado da categoria " .. categoryName .. " uma vez para o destino.",
        Callback = function() bringItemsOnceForCategory(categoryName) end
    })
end

TabBring:Divider()
TabBring:Section({ Title = "Bring Automatico Multi-Categoria" })

local multiCategoryBringDropdown_UI = TabBring:Dropdown({
    Title = "Categorias para Bring Automatico", Values = BRINGABLE_CATEGORIES_LIST, Multi = true, AllowNone = true,
    Callback = function(selectedCategories)
        local activeCategories = {}; for catName, ctrl in pairs(CATEGORY_CONTROLS) do if ctrl.autoBringActive then table.insert(activeCategories, catName) end end
        for _, categoryName in ipairs(activeCategories) do if not find(selectedCategories, categoryName) then deactivateAutoBringForCategory(categoryName) end end
        for _, selectedCat in ipairs(selectedCategories) do
            local control = CATEGORY_CONTROLS[selectedCat]
            if control and not control.autoBringActive then activateAutoBringForCategory(selectedCat) end
        end
    end
})

TabCombate:Section({ Title = "Kill Aura" })
TabCombate:Toggle({
    Title = "Ativar Kill Aura", Desc = "Ataca jogadores, animais e corta arvores automaticamente (com machado equipado).",
    Callback = toggleKillAura
})

local killAuraRangeInput_UI = TabCombate:Input({
    Title = "Raio da Kill Aura", Placeholder = tostring(killAuraRange), Default = tostring(killAuraRange), Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 10 and numValue <= 200 then killAuraRange = numValue
        else WindUI:Notify({Title = "Kill Aura", Content = "Raio invalido! Use um numero entre 10 e 200.", Color = "Red", Duration = 3}); killAuraRangeInput_UI:Set(tostring(killAuraRange)) end
    end
})

TabTeleporte:Section({ Title = "Movimento do Jogador" })
local walkspeedInput_UI = TabTeleporte:Input({
    Title = "Velocidade (WalkSpeed)", Placeholder = tostring(currentWalkSpeed), Default = tostring(currentWalkSpeed), Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 0 and numValue <= 500 then currentWalkSpeed = numValue; applyPlayerMovement()
        else WindUI:Notify({Title = "Movimento", Content = "Valor de velocidade invalido! Use um numero entre 0 e 500.", Color = "Red", Duration = 3}); walkspeedInput_UI:Set(tostring(currentWalkSpeed)) end
    end
})
local jumppowerInput_UI = TabTeleporte:Input({
    Title = "Poder de Pulo (JumpPower)", Placeholder = tostring(currentJumpPower), Default = tostring(currentJumpPower), Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 0 and numValue <= 500 then currentJumpPower = numValue; applyPlayerMovement()
        else WindUI:Notify({Title = "Movimento", Content = "Valor de pulo invalido! Use um numero entre 0 e 500.", Color = "Red", Duration = 3}); jumppowerInput_UI:Set(tostring(currentJumpPower)) end
    end
})

TabTeleporte:Section({ Title = "Teleporte Rapido" })
TabTeleporte:Button({
    Title = "TP para Fogueira", Desc = "Teleporta voce para a fogueira principal (MainFire).",
    Callback = function()
        local foundMainFire = nil; for instance, _ in pairs(trackedStructures) do if find(CAMPFIRE_STRUCTURE_NAMES, instance.Name) then foundMainFire = instance; break end end
        if foundMainFire then teleportToPosition(getSafePosition(foundMainFire), "Fogueira ("..foundMainFire.Name..")")
        else WindUI:Notify({Title = "Teleporte", Content = "Nenhuma fogueira encontrada no mapa.", Color = "Red", Duration = 3}) end
    end
})
TabTeleporte:Button({
    Title = "TP para Bancada", Desc = "Teleporta voce para a bancada de trabalho principal (CraftingBench).",
    Callback = function()
        local foundCraftingBench = nil; for instance, _ in pairs(trackedStructures) do if find(WORKBENCH_STRUCTURE_NAMES, instance.Name) then foundCraftingBench = instance; break end end
        if foundCraftingBench then teleportToPosition(getSafePosition(foundCraftingBench), "Bancada ("..foundCraftingBench.Name..")")
        else WindUI:Notify({Title = "Teleporte", Content = "Nenhuma bancada de trabalho encontrada no mapa.", Color = "Red", Duration = 3}) end
    end
})
TabTeleporte:Button({
    Title = "TP para Acampamento", Desc = "Teleporta voce para o acampamento principal.",
    Callback = function()
        local foundCampground = nil; for instance, _ in pairs(trackedStructures) do if find(CAMPGROUND_NAMES, instance.Name) then foundCampground = instance; break end end
        if foundCampground then teleportToPosition(getSafePosition(foundCampground), "Acampamento ("..foundCampground.Name..")")
        else WindUI:Notify({Title = "Teleporte", Content = "Nenhum acampamento encontrado no mapa.", Color = "Red", Duration = 3}) end
    end
})
TabTeleporte:Button({
    Title = "TP para Arvore Gigante", Desc = "Teleporta voce para a Arvore Gigante mais proxima.",
    Callback = function()
        local foundGiantTree = nil; for instance, _ in pairs(trackedStructures) do if find(GIANT_TREE_NAMES, instance.Name) then foundGiantTree = instance; break end end
        if foundGiantTree then teleportToPosition(getSafePosition(foundGiantTree), "Arvore Gigante ("..foundGiantTree.Name..")")
        else WindUI:Notify({Title = "Teleporte", Content = "Nenhuma Arvore Gigante encontrada no mapa.", Color = "Red", Duration = 3}) end
    end
})

local selectedKid = "Nenhum"
local kidDropdown_UI = TabTeleporte:Dropdown({
    Title = "TP para Crianca:", Values = {"Nenhum"}, Default = selectedKid,
    Callback = function(name) selectedKid = name; WindUI:Notify({Title = "Teleporte", Content = "Crianca selecionada: " .. tostring(name), Color = "Blue", Duration = 2}) end
})
TabTeleporte:Button({
    Title = "Teleportar para Crianca", Desc = "Teleporta para a crianca selecionada no dropdown.",
    Callback = function()
        if selectedKid == "Nenhum" then WindUI:Notify({Title = "Teleporte", Content = "Nenhuma crianca selecionada.", Color = "Red", Duration = 3}); return end
        local pureName, targetX, targetZ = parseDestinationString(selectedKid); local targetInstance = nil
        for instance, _ in pairs(trackedKids) do
            local instancePos = getSafePosition(instance)
            if instancePos and instance.Name == pureName and math.floor(instancePos.X) == targetX and math.floor(instancePos.Z) == targetZ then
                targetInstance = instance; break
            end
        end
        if targetInstance then teleportToPosition(getSafePosition(targetInstance), tostring(targetInstance.Name))
        else WindUI:Notify({Title = "Teleporte", Content = "Crianca '" .. tostring(pureName) .. "' nao encontrada ou invalida!", Color = "Red", Duration = 3}) end
    end
})

-- ===================================================================
--                     HUD - PARAR TUDO
-- ===================================================================

-- ===================================================================
--                     INICIALIZAÇÃO E EVENTOS
-- ===================================================================

local function updateAllDropdowns()
    debouncedUpdateBringDestinationDropdown(bringLocalizationDropdown_UI)
    debouncedUpdateKidDropdown(kidDropdown_UI)
end

local function onCharacterAdded(char)
    updatePlayersEsp()
    updateAllDropdowns()
    saveOriginalPlayerState()
    applyPlayerMovement()
    if walkspeedInput_UI then walkspeedInput_UI:Set(tostring(currentWalkSpeed)) end
    if jumppowerInput_UI then jumppowerInput_UI:Set(tostring(currentJumpPower)) end
end

RunService.RenderStepped:Connect(updatePlayersEsp)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(onCharacterAdded)
    player.CharacterRemoving:Connect(function(char)
        if espHighlights[char] then espHighlights[char]:Destroy() end
        espHighlights[char] = nil
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    if player.Character and espHighlights[player.Character] then espHighlights[player.Character]:Destroy() end
    espHighlights[player.Character] = nil
end)

Workspace.DescendantAdded:Connect(function(instance) onItemAdded(instance); updateAllDropdowns() end)
Workspace.DescendantRemoving:Connect(function(instance) onItemRemoved(instance); updateAllDropdowns() end)

initializeItemTracking()
findRemoteEvents()

task.wait(1)
if Player.Character then onCharacterAdded(Player.Character) end

applyPlayerMovement()
updateStopButtonVisibility()

WindUI:Notify({Title = "Script 99 Noites", Content = "Script carregado com sucesso!", Color = "Dark", Duration = 3})
