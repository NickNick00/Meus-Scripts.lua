-- ===================================================================
--                  CARREGAMENTO DA BIBLIOTECA WINDUI
-- ===================================================================
local WindUI

-- Função para baixar e carregar o WindUI de forma mais robusta
local function loadWindUI()
    local WindUI_Code, WindUI_Code_Error
    local successHttp, httpResult = pcall(function()
        return game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua")
    end)

    if not successHttp then
        warn("Erro ao tentar obter o código do WindUI via HTTP: ", httpResult)
        error("Nao foi possivel obter a interface (erro de rede). Abortando script.")
    end

    WindUI_Code = httpResult
    if not WindUI_Code or #WindUI_Code == 0 then
        warn("Nenhum código do WindUI foi retornado via HTTP.")
        error("Nao foi possivel obter a interface (código vazio). Abortando script.")
    end

    local loaderSuccess, loaderResult = pcall(loadstring, WindUI_Code)

    if not loaderSuccess then
        warn("Erro ao compilar o código do WindUI (erro de sintaxe): ", loaderResult)
        error("Nao foi possivel compilar a interface (código inválido). Abortando script.")
    end

    if not loaderResult then
        warn("Loadstring retornou nil (código do WindUI inválido, mas sem erro de sintaxe explícito).")
        error("Nao foi possivel carregar a interface (código ilegível). Abortando script.")
    end

    local executionSuccess, executionResult = pcall(loaderResult)

    if not executionSuccess then
        warn("Erro ao executar o script do WindUI: ", executionResult)
        error("Nao foi possivel executar a interface. Abortando script.")
    end

    if not executionResult then
        warn("O script do WindUI foi executado mas nao retornou o objeto da UI (nil).")
        error("Nao foi possivel carregar a interface (retorno vazio). Abortando script.")
    end

    return executionResult
end

-- Tenta carregar o WindUI e captura qualquer erro fatal
local successWindUI, loadedWindUI = pcall(loadWindUI)
if not successWindUI then
    error(loadedWindUI) -- Propaga o erro capturado por loadWindUI
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
local bringHeight = 50 -- Altura padrao para onde os itens sao puxados
local noQuantityLimit = false -- Sem Limite de Quantidade
local selectedBringDestination = "Voce (Player)"
local BRING_AUTO_COOLDOWN = 1.0 -- Cooldown para o Bring Automatico (por categoria)
local activeAutoBringCount = 0 -- Contador de categorias com auto-bring ativo

-- Player original state for Bring TP / Untouchable / Freecam
local originalPlayerWalkSpeed = 16
local originalPlayerJumpPower = 50
local originalPlayerCanCollide = true
local originalPlayerTransparency = 0
local originalPlayerPlatformStand = false
local originalCameraType = Camera.CameraType
local originalCameraSubject = Camera.CameraSubject
local originalCameraCFrame = Camera.CFrame or CFrame.new() -- Garante valor inicial

-- BRING METHODS
local currentBringMethod = "Simples" -- "Simples" ou "Teleporte"

-- BRING SIMPLES (Antigo Bring 1)
local bringSimpleRange = 10000
local bringSimpleMaxQuantity = 50

-- BRING TELEPORTE (Antigo Bring 2)
local bringTPRange = 10000
local bringTPCooldown = 0.5

-- PLAYER MOVEMENT
local currentWalkSpeed = 16
local currentJumpPower = 50

-- ===================================================================
--                  ITENS E CATEGORIAS CONFIGURÁVEIS
-- (Nomes foram ajustados para as prováveis versões em inglês, que funcionam no jogo)
-- ===================================================================

local ITEM_DATABASE = {
    -- Combustivel
    Log = "Combustivel", Wood = "Combustivel", Chair = "Combustivel", Biofuel = "Combustivel", Coal = "Combustivel",
    ["Fuel Canister"] = "Combustivel", ["Oil Barrel"] = "Combustivel", Sapling = "Combustivel",

    -- Comida e Cura
    Carrot = "Comida e Cura", Corn = "Comida e Cura", Pumpkin = "Comida e Cura", Berry = "Comida e Cura", Apple = "Comida e Cura",
    Morsel = "Comida e Cura", ["Cooked Morsel"] = "Comida e Cura", Steak = "Comida e Cura", ["Cooked Steak"] = "Comida e Cura",
    Ribs = "Comida e Cura", ["Cooked Ribs"] = "Comida e Cura", Cake = "Comida e Cura", Chili = "Comida e Cura", Stew = "Comida e Cura",
    ["Hearty Stew"] = "Comida e Cura", ["Meat? Sandwich"] = "Comida e Cura", ["Seafood Chowder"] = "Comida e Cura",
    ["Steak Dinner"] = "Comida e Cura", ["Pumpkin Soup"] = "Comida e Cura", ["BBQ Ribs"] = "Comida e Cura",
    ["Carrot Cake"] = "Comida e Cura", ["Jar o' Jelly"] = "Comida e Cura", Crab = "Comida e Cura", Salmon = "Comida e Cura",
    Swordfish = "Comida e Cura", Fruit = "Comida e Cura", Spice = "Comida e Cura", ["Dinner Meat"] = "Comida e Cura",
    Bandage = "Comida e Cura", Medkit = "Comida e Cura", Pepper = "Comida e Cura",

    -- Sucata (Engrenagens)
    Bolt = "Sucata", Screw = "Sucata", ["Sheet Metal"] = "Sucata", ["UFO Junk"] = "Sucata", ["UFO Component"] = "Sucata",
    ["UFO Scrap"] = "Sucata", ["Broken Fan"] = "Sucata", ["Old Radio"] = "Sucata", ["Broken Microwave"] = "Sucata",
    Tyre = "Sucata", ["Metal Chair"] = "Sucata", ["Old Car Engine"] = "Sucata", ["Washing Machine"] = "Sucata",
    ["Cultist Experiment"] = "Sucata", ["Cultist Prototype"] = "Sucata",

    -- Armas e Armaduras (Equipamento)
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

    -- Outros
    Flower = "Outros", Feather = "Outros", Fire = "Outros", ["Sacrifice Totem"] = "Outros", ["Old Rod"] = "Outros",
    ["Coin Pile"] = "Outros", ["Infernal Bag"] = "Outros", ["Giant Bag"] = "Outros", ["Good Bag"] = "Outros",
    ["Old Lantern"] = "Outros", ["Strong Lantern"] = "Outros", Diamond = "Outros", ["Defense Sketch"] = "Outros",

    -- Meteorito (Nova Categoria)
    ["Meteorite Fragment"] = "Meteorito", ["Gold Fragment"] = "Meteorito",
    ["Raw Obsidian Ore"] = "Meteorito", ["Burning Obsidian Ingot"] = "Meteorito",

    -- Cultista (Nova Categoria)
    Cultist = "Cultista", ["Harpoon Cultist"] = "Cultista",
    ["Cultist Gem"] = "Cultista", ["Gem of the Forest"] = "Cultista"
}

-- Mapeamento de categorias para suas variáveis de controle
local CATEGORY_CONTROLS = {
    Combustivel = {specificItem = nil, lastIndex = 1, lastBringTimeTP = 0, autoBringActive = false, autoBringConnection = nil, lastAutoBringTime = 0},
    ["Comida e Cura"] = {specificItem = nil, lastIndex = 1, lastBringTimeTP = 0, autoBringActive = false, autoBringConnection = nil, lastAutoBringTime = 0},
    Sucata = {specificItem = nil, lastIndex = 1, lastBringTimeTP = 0, autoBringActive = false, autoBringConnection = nil, lastAutoBringTime = 0},
    ["Armas e Armaduras"] = {specificItem = nil, lastIndex = 1, lastBringTimeTP = 0, autoBringActive = false, autoBringConnection = nil, lastAutoBringTime = 0},
    Outros = {specificItem = nil, lastIndex = 1, lastBringTimeTP = 0, autoBringActive = false, autoBringConnection = nil, lastAutoBringTime = 0},
    Meteorito = {specificItem = nil, lastIndex = 1, lastBringTimeTP = 0, autoBringActive = false, autoBringConnection = nil, lastAutoBringTime = 0},
    Cultista = {specificItem = nil, lastIndex = 1, lastBringTimeTP = 0, autoBringActive = false, autoBringConnection = nil, lastAutoBringTime = 0},
}

-- ===================================================================
--                  FUNÇÕES AUXILIARES DE RASTREAMENTO E UTILIDADE
-- ===================================================================

local updateCooldown = 0.5 -- Debounce time for dropdowns (seconds)

-- Função auxiliar para substituir table.find
local function find(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

local BRINGABLE_CATEGORIES_LIST = {}
for itemName, category in pairs(ITEM_DATABASE) do
    if not find(BRINGABLE_CATEGORIES_LIST, category) then
        table.insert(BRINGABLE_CATEGORIES_LIST, category)
    end
end
table.sort(BRINGABLE_CATEGORIES_LIST)

local CAMPFIRE_STRUCTURE_NAMES = {"MainFire", "Camp", "Fogueira", "Campfire", "Lareira"}
local WORKBENCH_STRUCTURE_NAMES = {"CraftingBench", "Crafting Bench", "Workbench", "Work Bench", "Bancada", "CraftingTable", "Crafting Table"}
local CAMPGROUND_NAMES = {"Campground", "CampArea", "BaseCamp", "AcampamentoPrincipal", "SmallCamp"}
local GIANT_TREE_NAMES = {"TreeGiant", "GiantTree"}

local KID_NAMES = {"DinoKid", "KrakenKid", "SquidKid", "KoalaKid"}

local ALL_TRACKED_STRUCTURE_NAMES_TO_DISPLAY = {}
for _, name in ipairs(CAMPFIRE_STRUCTURE_NAMES) do table.insert(ALL_TRACKED_STRUCTURE_NAMES_TO_DISPLAY, name) end
for _, name in ipairs(WORKBENCH_STRUCTURE_NAMES) do table.insert(ALL_TRACKED_STRUCTURE_NAMES_TO_DISPLAY, name) end
for _, name in ipairs(CAMPGROUND_NAMES) do table.insert(ALL_TRACKED_STRUCTURE_NAMES_TO_DISPLAY, name) end
for _, name in ipairs(GIANT_TREE_NAMES) do table.insert(ALL_TRACKED_STRUCTURE_NAMES_TO_DISPLAY, name) end

local trackedGroundItems = {}
local trackedStructures = {}
local trackedKids = {}
local trackedAnimals = {}
local trackedTreesForKA = {}

-- KILL AURA
local killAuraAtivo = false
local killAuraConnection = nil
local killAuraRange = 50

local REPLICATED_STORAGE_EVENTS_PATH = game:GetService("ReplicatedStorage"):FindFirstChild("RemoteEvents")
local damageEvents = {}
local chopEvents = {}

local ANIMAL_NAMES = {"Bunny", "Bear", "Wolf", "Spider", "Scorpion", "Crow"}
local TREE_STRUCTURE_NAMES = {"TreeBig", "Small Tree", "Snowy Small Tree", "Dead Tree1", "Dead Tree2", "Dead Tree3"}


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
            if timer then
                task.cancel(timer)
            end
            timer = task.delay(delay - (currentTime - lastCallTime), function()
                lastCallTime = tick()
                func(unpack(args))
            end)
        end
    end
end

local function parseDestinationString(destinationString)
    local pureName, x_str, z_str = destinationString:match("^(.-)%s*%((%d+),%s*(%d+)%)")

    if not pureName then -- Se não houver coordenadas, pode ser apenas o nome (ex: "Voce (Player)" ou "Nenhum")
        pureName = destinationString:match("^(.-)%s*%(Player%)") or destinationString
    end

    local colonPos = pureName:find(":")
    if colonPos then
        pureName = pureName:sub(colonPos + 2) -- +2 para pular ": "
    end
    
    local targetX = tonumber(x_str)
    local targetZ = tonumber(z_str)
    
    return pureName, targetX, targetZ
end

local function getSafePosition(instance)
    if not instance or not instance.Parent then return nil end
    if instance:IsA("BasePart") then
        return instance.Position
    elseif instance:IsA("Model") then
        local primaryPart = instance.PrimaryPart
        if primaryPart and primaryPart:IsA("BasePart") then
            return primaryPart.Position
        end
        local centerPart = instance:FindFirstChild("Center") or instance:FindFirstChild("Primary") or instance:FindFirstChildWhichIsA("BasePart")
        if centerPart and centerPart:IsA("BasePart") then
            return centerPart.Position
        end
    end
    return nil
end

local function updatePlayersEsp()
    if not espPlayersAtivo then
        for char, highlight in pairs(espHighlights) do
            if highlight and highlight.Parent then highlight:Destroy() end
            espHighlights[char] = nil
        end
        return
    end

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            if not espHighlights[p.Character] then
                local highlight = Instance.new("Highlight")
                highlight.OutlineColor = espColor
                highlight.FillColor = Color3.fromRGB(0, 255, 0) -- Pode ser ligeiramente transparente ou a mesma cor da outline
                highlight.FillTransparency = 0.7
                highlight.Parent = p.Character
                espHighlights[p.Character] = highlight
            else
                espHighlights[p.Character].OutlineColor = espColor
                espHighlights[p.Character].FillColor = espColor
            end
        elseif espHighlights[p.Character] then -- Remove highlight se o jogador perdeu o personagem
            if espHighlights[p.Character] and espHighlights[p.Character].Parent then espHighlights[p.Character]:Destroy() end
            espHighlights[p.Character] = nil
        end
    end
    -- Remove highlights para personagens que não existem mais
    for char, highlight in pairs(espHighlights) do
        if not char.Parent then -- Personagem não está mais no Workspace
            if highlight and highlight.Parent then highlight:Destroy() end
            espHighlights[char] = nil
        end
    end
end

-- Função centralizada para adicionar itens a todas as tabelas de rastreamento
local function onItemAdded(instance)
    if not instance or not instance.Parent or not (instance:IsA("BasePart") or instance:IsA("Model")) then return end

    if ITEM_DATABASE[instance.Name] then
        trackedGroundItems[instance] = true
        return
    end

    if find(ALL_TRACKED_STRUCTURE_NAMES_TO_DISPLAY, instance.Name) then
        if getSafePosition(instance) then trackedStructures[instance] = true end
        return
    end

    if find(KID_NAMES, instance.Name) then
        if getSafePosition(instance) then trackedKids[instance] = true end
        return
    end

    if find(ANIMAL_NAMES, instance.Name) and instance:FindFirstChildOfClass("Humanoid") then
        if getSafePosition(instance) then trackedAnimals[instance] = true end
        return
    end
    if find(TREE_STRUCTURE_NAMES, instance.Name) then
        if getSafePosition(instance) then trackedTreesForKA[instance] = true end
        return
    end
end

-- Função centralizada para remover itens de todas as tabelas de rastreamento
local function onItemRemoved(instance)
    if trackedGroundItems[instance] then trackedGroundItems[instance] = nil end
    if trackedStructures[instance] then trackedStructures[instance] = nil end
    if trackedKids[instance] then trackedKids[instance] = nil end
    if trackedAnimals[instance] then trackedAnimals[instance] = nil end
    if trackedTreesForKA[instance] then trackedTreesForKA[instance] = nil end
end

local function initializeItemTracking()
    trackedGroundItems = {}
    trackedStructures = {}
    trackedKids = {}
    trackedAnimals = {}
    trackedTreesForKA = {}

    for _, instance in pairs(Workspace:GetDescendants()) do
        onItemAdded(instance)
    end
end

local debouncedUpdateBringDestinationDropdown = debounce(function(dropdown)
    local currentDestinations = {"Voce (Player)"}

    local tempTracked = {}
    for instance, _ in pairs(trackedStructures) do table.insert(tempTracked, instance) end
    for instance, _ in pairs(trackedKids) do table.insert(tempTracked, instance) end

    for _, instance in ipairs(tempTracked) do
        if instance and instance.Parent then
            local instancePosition = getSafePosition(instance)
            if instancePosition then
                local nameToDisplay = tostring(instance.Name)
                if find(CAMPFIRE_STRUCTURE_NAMES, instance.Name) then
                    nameToDisplay = "Fogueira: " .. nameToDisplay
                elseif find(WORKBENCH_STRUCTURE_NAMES, instance.Name) then
                    nameToDisplay = "Bancada: " .. nameToDisplay
                elseif find(CAMPGROUND_NAMES, instance.Name) then
                    nameToDisplay = "Acampamento: " .. nameToDisplay
                elseif find(GIANT_TREE_NAMES, instance.Name) then
                    nameToDisplay = "Arvore Gigante: " .. nameToDisplay
                elseif find(KID_NAMES, instance.Name) then
                    nameToDisplay = "Crianca: " .. nameToDisplay
                end
                table.insert(currentDestinations, nameToDisplay .. " (" .. tostring(math.floor(instancePosition.X)) .. ", " .. tostring(math.floor(instancePosition.Z)) .. ")")
            end
        end
    end
    
    if dropdown and dropdown.Refresh then
        dropdown:Refresh(currentDestinations)
    else
        warn("Dropdown de destino do Bring (ou refresh) nao encontrado/valido!")
    end
end, updateCooldown)

local debouncedUpdateKidDropdown = debounce(function(dropdown)
    local currentKids = {"Nenhum"}
    for instance, _ in pairs(trackedKids) do
        if instance and instance.Parent then
            local instancePosition = getSafePosition(instance)
            if instancePosition then
                table.insert(currentKids, tostring(instance.Name) .. " (" .. tostring(math.floor(instancePosition.X)) .. ", " .. tostring(math.floor(instancePosition.Z)) .. ")")
            end
        end
    end
    if dropdown and dropdown.Refresh then
        dropdown:Refresh(currentKids)
    else
        warn("Dropdown de criancas (ou refresh) nao encontrado/valido!")
    end
end, updateCooldown)

local function getAllItemNamesForCategory(categoryName)
    local itemNames = {}
    for itemName, cat in pairs(ITEM_DATABASE) do
        if cat == categoryName then
            table.insert(itemNames, itemName)
        end
    end
    return itemNames
end

-- ===================================================================
--                  FUNÇÕES DO BRING
-- ===================================================================

local function getBringTargetCFrame(destinationString, playerHrp)
    local offsetY = bringHeight 
    if destinationString == "Voce (Player)" and playerHrp and playerHrp.Parent then
        return playerHrp.CFrame * CFrame.new(0, offsetY, -3) 
    else
        local pureName, targetX, targetZ = parseDestinationString(destinationString)
        
        local targetInstance = nil
        local allTracked = {}
        for inst, _ in pairs(trackedStructures) do table.insert(allTracked, inst) end
        for inst, _ in pairs(trackedKids) do table.insert(allTracked, inst) end

        for _, instance in ipairs(allTracked) do
            if instance and instance.Parent then
                local instancePos = getSafePosition(instance)
                if instancePos and instance.Name == pureName and
                   math.floor(instancePos.X) == targetX and math.floor(instancePos.Z) == targetZ then
                    targetInstance = instance
                    break
                end
            end
        end
        
        if targetInstance then
            local instancePosition = getSafePosition(targetInstance)
            if not instancePosition then return nil end
            
            -- Lógica aprimorada para fogueiras e bancadas
            local finalPosition = instancePosition
            if find(CAMPFIRE_STRUCTURE_NAMES, targetInstance.Name) and targetInstance:FindFirstChild("Center") then
                finalPosition = targetInstance.Center.Position
            elseif find(WORKBENCH_STRUCTURE_NAMES, targetInstance.Name) and targetInstance:FindFirstChild("Main") then
                finalPosition = targetInstance.Main.Position
            end

            return CFrame.new(finalPosition) * CFrame.new(0, offsetY, 0)
        end
    end
    return nil
end

local function saveOriginalPlayerState()
    local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if humanoid then
        originalPlayerWalkSpeed = humanoid.WalkSpeed
        originalPlayerJumpPower = humanoid.JumpPower
        originalPlayerPlatformStand = humanoid.PlatformStand
    end
    if hrp then
        originalPlayerCanCollide = hrp.CanCollide
        local torso = Player.Character:FindFirstChild("Torso") or Player.Character:FindFirstChild("UpperTorso")
        originalPlayerTransparency = (torso and torso.Transparency) or 0
    end
    if Camera then
        originalCameraType = Camera.CameraType
        originalCameraSubject = Camera.CameraSubject
        originalCameraCFrame = Camera.CFrame
    end
end

local function restorePlayerState()
    local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")

    if humanoid and humanoid.Parent then
        humanoid.WalkSpeed = originalPlayerWalkSpeed
        humanoid.JumpPower = originalPlayerJumpPower
        humanoid.PlatformStand = originalPlayerPlatformStand
    end
    if hrp and hrp.Parent then
        hrp.CanCollide = originalPlayerCanCollide
        for _, part in ipairs(Player.Character:GetChildren()) do
            if part:IsA("BasePart") then
                part.Transparency = originalPlayerTransparency
                part.CanCollide = originalPlayerCanCollide
            end
        end
    end

    -- Restore Camera for Freecam
    if Camera and originalCameraType then
        Camera.CameraType = originalCameraType
        Camera.CameraSubject = originalCameraSubject
        Camera.CFrame = originalCameraCFrame -- Restaurar CFrame da câmera
    end
    WindUI:Notify({Title = "Bring", Content = "Estado do jogador restaurado.", Color = "Gray", Duration = 2})
end

local function applyPlayerBringState(disconnectCamera)
    local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not hrp or not humanoid.Parent or not hrp.Parent then 
        warn("Humanoid ou HRP do Player nao encontrados para aplicar estado do Bring.")
        return 
    end

    -- Aplica os estados
    if bringFreecamActive then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        humanoid.PlatformStand = true
        for _, part in ipairs(Player.Character:GetChildren()) do
            if part:IsA("BasePart") then
                part.Transparency = 1
                part.CanCollide = false
            end
        end
        if Camera and disconnectCamera then
            Camera.CameraType = Enum.CameraType.Scriptable
            Camera.CFrame = Camera.CFrame -- Mantem a camera onde esta
            WindUI:Notify({Title = "Bring Freecam", Content = "Ativado (camera solta, personagem intangivel).", Color = "Yellow", Duration = 2})
        end
    elseif bringUntouchable then
        humanoid.PlatformStand = originalPlayerPlatformStand
        humanoid.WalkSpeed = originalPlayerWalkSpeed
        humanoid.JumpPower = originalPlayerJumpPower
        for _, part in ipairs(Player.Character:GetChildren()) do
            if part:IsA("BasePart") then
                part.Transparency = originalPlayerTransparency
                part.CanCollide = false
            end
        end
        if Camera then Camera.CameraType = originalCameraType end -- Restore camera if it was freecam
        WindUI:Notify({Title = "Bring Untouchable", Content = "Ativado (personagem sem colisao).", Color = "Yellow", Duration = 2})
    else
        restorePlayerState() -- Should not happen if logic is correct, but as a fallback
    end
end

-- Lógica unificada para trazer itens (agora chamada por `bringItemsOnceForCategory` e `activateAutoBringForCategory`)
local function runBringLogic(categoryName, itemsToBringList, bringRange, maxQuantity, bringCooldown, bringMethod)
    if not Player.Character then return false end
    local playerHrp = Player.Character:FindFirstChild("HumanoidRootPart")
    local playerHumanoid = Player.Character:FindFirstChildOfClass("Humanoid")
    if not playerHrp or not playerHrp.Parent or not playerHumanoid or not playerHumanoid.Parent then return false end

    local targetCFrame = getBringTargetCFrame(selectedBringDestination, playerHrp)
    if not targetCFrame then 
        WindUI:Notify({Title = "Bring", Content = "Destino '" .. selectedBringDestination .. "' nao encontrado ou invalido!", Color = "Red", Duration = 3})
        return false -- Indica falha
    end

    if not itemsToBringList or #itemsToBringList == 0 then return false end

    local itemsFoundInRange = {}
    for itemInstance, _ in pairs(trackedGroundItems) do
        if itemInstance and itemInstance.Parent and find(itemsToBringList, itemInstance.Name) then
            local itemPosition = getSafePosition(itemInstance)
            if itemPosition and (playerHrp.Position - itemPosition).Magnitude <= bringRange then
                table.insert(itemsFoundInRange, itemInstance)
            end
        end
    end
    
    local actualItemsPulled = 0

    if bringMethod == "Simples" then
        local currentMaxQuantity = noQuantityLimit and #itemsFoundInRange or maxQuantity
        local categoryControl = CATEGORY_CONTROLS[categoryName]
        categoryControl.lastIndex = categoryControl.lastIndex or 1

        local itemsProcessedThisFrame = 0
        local startIndex = categoryControl.lastIndex

        -- Loop para encontrar e puxar itens
        for i = 1, #itemsFoundInRange do
            local currentItemIndex = (startIndex + i - 2) % #itemsFoundInRange + 1 -- Cicla pelos itens
            local itemInstance = itemsFoundInRange[currentItemIndex]

            if itemInstance and itemInstance.Parent then
                local primaryPart = itemInstance:IsA("Model") and itemInstance.PrimaryPart
                local targetPart = nil

                if itemInstance:IsA("BasePart") then
                    targetPart = itemInstance
                elseif primaryPart and primaryPart.Parent then
                    targetPart = primaryPart
                else
                    targetPart = itemInstance:FindFirstChild("Center") or itemInstance:FindFirstChild("Primary") or itemInstance:FindFirstChildWhichIsA("BasePart")
                end

                if targetPart and targetPart.Parent and targetPart:IsA("BasePart") then
                    targetPart.Anchored = false -- GARANTE QUE O ITEM CAIA
                    targetPart.CanCollide = false -- Desativa colisao antes de mover

                    -- Adiciona um offset aleatório para espalhar os itens
                    local randomOffsetX = math.random() * 1.5 - 0.75 -- entre -0.75 e 0.75 para espalhamento
                    local randomOffsetZ = math.random() * 1.5 - 0.75
                    local spreadCFrame = targetCFrame * CFrame.new(randomOffsetX, 0, randomOffsetZ)

                    if itemInstance:IsA("Model") then
                        itemInstance:SetPrimaryPartCFrame(spreadCFrame * CFrame.Angles(targetPart.CFrame:ToOrientation()))
                    else
                        itemInstance.CFrame = spreadCFrame * CFrame.Angles(targetPart.CFrame:ToOrientation())
                    end
                    targetPart.CanCollide = true -- Reativa colisao para cair

                    itemsProcessedThisFrame = itemsProcessedThisFrame + 1
                    actualItemsPulled = actualItemsPulled + 1
                    task.wait(0.01) -- COOLDOWN MÍNIMO PARA CADA ITEM CAIR

                    if itemsProcessedThisFrame >= currentMaxQuantity then
                        categoryControl.lastIndex = currentItemIndex + 1
                        if categoryControl.lastIndex > #itemsFoundInRange then categoryControl.lastIndex = 1 end
                        return actualItemsPulled > 0
                    end
                end
            end
        end
        categoryControl.lastIndex = 1 -- Reinicia se todos os itens foram processados
        return actualItemsPulled > 0
        

    elseif bringMethod == "Teleporte" then
        if tick() - CATEGORY_CONTROLS[categoryName].lastBringTimeTP < bringCooldown then return false end

        local itemToBring = nil
        local minDistance = bringRange + 1

        for itemInstance, _ in pairs(trackedGroundItems) do
            if itemInstance and itemInstance.Parent and find(itemsToBringList, itemInstance.Name) then
                local itemPosition = getSafePosition(itemInstance)
                if itemPosition then
                    local currentDistance = (playerHrp.Position - itemPosition).Magnitude
                    if currentDistance <= bringRange and currentDistance < minDistance then
                        minDistance = currentDistance
                        itemToBring = itemInstance
                    end
                end
            end
        end
        
        if itemToBring and itemToBring.Parent then
            local itemPosition = getSafePosition(itemToBring)
            if not itemPosition then return false end

            pcall(function()
                playerHrp.CFrame = CFrame.new(itemPosition) * CFrame.new(0, 5, 0)
            end)
            task.wait(0.05)

            local primaryPart = itemToBring:IsA("Model") and itemToBring.PrimaryPart
            local targetPart = nil

            if itemToBring:IsA("BasePart") then
                targetPart = itemToBring
            elseif primaryPart and primaryPart.Parent then
                targetPart = primaryPart
            else
                targetPart = itemToBring:FindFirstChild("Center") or itemToBring:FindFirstChild("Primary") or itemToBring:FindFirstChildWhichIsA("BasePart")
            end
            
            if targetPart and targetPart.Parent and targetPart:IsA("BasePart") then
                targetPart.Anchored = false
                targetPart.CanCollide = false

                -- Adiciona um offset aleatório para espalhar os itens
                local randomOffsetX = math.random() * 1.5 - 0.75
                local randomOffsetZ = math.random() * 1.5 - 0.75
                local spreadCFrame = targetCFrame * CFrame.new(randomOffsetX, 0, randomOffsetZ)

                if itemToBring:IsA("Model") then
                    itemToBring:SetPrimaryPartCFrame(spreadCFrame * CFrame.Angles(targetPart.CFrame:ToOrientation()))
                else
                    itemToBring.CFrame = spreadCFrame * CFrame.Angles(targetPart.CFrame:ToOrientation())
                end
                targetPart.CanCollide = true
            end
            
            trackedGroundItems[itemToBring] = nil -- Remove o item da lista após puxá-lo
            task.wait(0.05)

            pcall(function()
                playerHrp.CFrame = targetCFrame * CFrame.new(0, 5, 0)
            end)
            task.wait(0.05)
            
            CATEGORY_CONTROLS[categoryName].lastBringTimeTP = tick()
            actualItemsPulled = actualItemsPulled + 1
            return true
        end
    end
    return actualItemsPulled > 0
end

-- Função para puxar itens de uma categoria UMA VEZ
local function bringItemsOnceForCategory(categoryName)
    if not Player.Character then 
        WindUI:Notify({Title = "Bring Manual", Content = "Personagem nao encontrado.", Color = "Red", Duration = 3})
        return
    end
    local playerHrp = Player.Character:FindFirstChild("HumanoidRootPart")
    local playerHumanoid = Player.Character:FindFirstChildOfClass("Humanoid")
    if not playerHrp or not playerHrp.Parent or not playerHumanoid or not playerHumanoid.Parent then 
        WindUI:Notify({Title = "Bring Manual", Content = "Componentes do personagem nao encontrados.", Color = "Red", Duration = 3})
        return
    end

    local control = CATEGORY_CONTROLS[categoryName]
    if not control then return end

    if not selectedBringDestination or selectedBringDestination == "Nenhum" then
        WindUI:Notify({Title = "Bring Error", Content = "Selecione um destino valido para o Bring!", Color = "Red", Duration = 3})
        return
    end

    if control.specificItem == nil or control.specificItem == "" then
        WindUI:Notify({Title = "Bring Error", Content = "Selecione um item para puxar na categoria '" .. categoryName .. "'!", Color = "Red", Duration = 3})
        return
    end

    local bringRange = (currentBringMethod == "Simples" and bringSimpleRange) or bringTPRange
    local maxQuantity = (currentBringMethod == "Simples" and bringSimpleMaxQuantity) or 1
    local cooldown = (currentBringMethod == "Teleporte" and bringTPCooldown) or 0

    local success = runBringLogic(categoryName, {control.specificItem}, bringRange, maxQuantity, cooldown, currentBringMethod)

    if success then
        WindUI:Notify({Title = "Bring Manual", Content = "Itens de '" .. control.specificItem .. "' puxados para '" .. selectedBringDestination .. "'!", Color = "Green", Duration = 2})
    else
        WindUI:Notify({Title = "Bring Manual", Content = "Nenhum item '" .. control.specificItem .. "' encontrado no raio ou em cooldown.", Color = "Orange", Duration = 2})
    end
end

local function updateStopButtonVisibility()
    stopBringButton.Visible = (activeAutoBringCount > 0)
end

local function activateAutoBringForCategory(categoryName)
    local control = CATEGORY_CONTROLS[categoryName]
    if not control or control.autoBringConnection then return end -- Already active

    local itemsToBringList = getAllItemNamesForCategory(categoryName)
    if #itemsToBringList == 0 then
        warn("Nenhum item encontrado para a categoria " .. categoryName .. ". Nao e possivel iniciar o auto-bring.")
        WindUI:Notify({Title = "Bring Automatico", Content = "Nenhum item para " .. categoryName .. ". Nao ativado.", Color = "Red", Duration = 3})
        return
    end

    control.autoBringActive = true
    activeAutoBringCount = activeAutoBringCount + 1
    updateStopButtonVisibility()

    WindUI:Notify({Title = "Bring Automatico", Content = "Bring de " .. categoryName .. " ATIVADO!", Color = "Green", Duration = 2})

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
    if not control or not control.autoBringConnection then return end -- Not active

    control.autoBringConnection:Disconnect()
    control.autoBringConnection = nil
    control.autoBringActive = false
    activeAutoBringCount = activeAutoBringCount - 1
    updateStopButtonVisibility()

    WindUI:Notify({Title = "Bring Automatico", Content = "Bring de " .. categoryName .. " DESATIVADO!", Color = "Gray", Duration = 2})
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
    if not Player.Character then
        WindUI:Notify({Title = "Teleporte", Content = "Seu personagem nao esta disponivel para teleporte.", Color = "Red", Duration = 3})
        return
    end
    local playerHrp = Player.Character:FindFirstChild("HumanoidRootPart")
    if not playerHrp or not playerHrp.Parent then
        WindUI:Notify({Title = "Teleporte", Content = "HumanoidRootPart do seu personagem nao esta disponivel.", Color = "Red", Duration = 3})
        return
    end

    if position then
        pcall(function()
            playerHrp.CFrame = CFrame.new(position) * CFrame.new(0, 5, 0)
        end)
        WindUI:Notify({Title = "Teleporte", Content = "Teleportado para: " .. tostring(name) .. "!", Color = "Green", Duration = 2})
    else
        WindUI:Notify({Title = "Teleporte", Content = "Nao foi possivel determinar a posicao do destino.", Color = "Red", Duration = 3})
    end
end

-- ===================================================================
--                  KILL AURA FUNÇÕES
-- ===================================================================

local function findRemoteEvents()
    if not REPLICATED_STORAGE_EVENTS_PATH then
        warn("KillAura: Pasta 'RemoteEvents' nao encontrada em ReplicatedStorage. Funcoes de combate/corte nao funcionarao.")
        return
    end

    damageEvents = {}
    chopEvents = {}

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

    if next(damageEvents) == nil then warn("KillAura: Nenhum RemoteEvent de dano encontrado. Kill Aura para players/animais nao pode funcionar.") end
    if next(chopEvents) == nil then warn("KillAura: Nenhum RemoteEvent de corte encontrado. Auto-chop nao pode funcionar.") end
end

local function playerHasAxeEquipped()
    if not Player.Character then return nil end
    local backpack = Player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, item in pairs(backpack:GetChildren()) do
            if item:IsA("Tool") and (item.Name:find("Axe") or item.Name:find("Chainsaw")) then return item end
        end
    end
    for _, child in pairs(Player.Character:GetChildren()) do
        if child:IsA("Tool") and (child.Name:find("Axe") or child.Name:find("Chainsaw")) then return child end
    end
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

            local equippedTool = playerHasAxeEquipped()
            local hasAxe = equippedTool ~= nil

            for _, p in pairs(Players:GetPlayers()) do
                if p ~= Player and p.Character then
                    local targetChar = p.Character
                    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
                    local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")

                    if targetHrp and targetHumanoid and targetHrp.Parent and targetHumanoid.Parent then
                        local targetPosition = targetHrp.Position
                        if (playerPosition - targetPosition).Magnitude <= killAuraRange then
                            local damageEvent = damageEvents["GenericPlayerDamage"]
                            if damageEvent then
                                pcall(function()
                                    damageEvent:FireServer(targetHumanoid, targetHrp, 20, equippedTool and tostring(equippedTool.Name) or "Fist")
                                end)
                            end
                        end
                    end
                end
            end

            for animalInstance, _ in pairs(trackedAnimals) do
                if animalInstance and animalInstance.Parent then
                    local targetHrp = animalInstance:FindFirstChild("HumanoidRootPart")
                    local targetHumanoid = animalInstance:FindFirstChildOfClass("Humanoid")
                    if targetHrp and targetHumanoid and targetHrp.Parent and targetHumanoid.Parent then
                        local targetPosition = getSafePosition(animalInstance)
                        if targetPosition and (playerPosition - targetPosition).Magnitude <= killAuraRange then
                            local damageEvent = damageEvents[animalInstance.Name] or damageEvents["GenericPlayerDamage"]
                            if damageEvent then
                                pcall(function()
                                    damageEvent:FireServer(targetHumanoid, targetHrp, 15, equippedTool and tostring(equippedTool.Name) or "Fist")
                                end)
                            end
                        end
                    end
                end
            end

            if hasAxe then
                for treeInstance, _ in pairs(trackedTreesForKA) do
                    if treeInstance and treeInstance.Parent then
                        local targetPosition = getSafePosition(treeInstance)
                        if targetPosition and (playerPosition - targetPosition).Magnitude <= killAuraRange then
                            local chopEvent = chopEvents[treeInstance.Name]
                            if not chopEvent then chopEvent = chopEvents["GenericChop"] end
                            if chopEvent and equippedTool then
                                pcall(function()
                                    chopEvent:FireServer(treeInstance, equippedTool)
                                end)
                            end
                        end
                    end
                end
            end
        end)
    else
        if killAuraConnection then
            killAuraConnection:Disconnect()
            killAuraConnection = nil
        end
        WindUI:Notify({Title = "Kill Aura", Content = "Kill Aura DESATIVADA!", Color = "Gray", Duration = 2})
    end
end

-- ===================================================================
--                         INTERFACE GRÁFICA
-- ===================================================================

local Window = WindUI:CreateWindow({
    Title = "99 noites",
    Icon = "door-open",
    Author = "by kyuzzy",
    Folder = "99 noites",
    Size = UDim2.fromOffset(400, 550),
    Theme = "Dark"
})

local TabESP = Window:Tab({ Title = "ESP", Icon = "eye" })
local TabBring = Window:Tab({ Title = "Bring Stuff", Icon = "hand-point-right" })
local TabCombate = Window:Tab({ Title = "Combate", Icon = "sword" })
local TabTeleporte = Window:Tab({ Title = "Teleporte", Icon = "compass" })

TabESP:Section({ Title = "ESP de Jogadores" })
TabESP:Toggle({
    Title = "ESP de Jogadores (Verde)",
    Callback = function(state)
        espPlayersAtivo = state
        updatePlayersEsp()
        if state then WindUI:Notify({Title = "ESP", Content = "ESP de Jogadores ATIVADO!", Color = "Green", Duration = 2})
        else WindUI:Notify({Title = "ESP", Content = "ESP de Jogadores DESATIVADO!", Color = "Gray", Duration = 2}) end
    end
})

-- ===================================
--         BRING TAB (Refatorada)
-- ===================================

TabBring:Section({ Title = "Configuracoes Gerais do Bring" })

TabBring:Toggle({
    Title = "Usar Freecam para Trazer Itens",
    Desc = "A camera permanece no lugar, personagem intangivel e invisivel. Pode ser detectado.",
    Callback = function(state)
        if state then
            if not bringUntouchable and not bringFreecamActive then saveOriginalPlayerState() end
            bringFreecamActive = true
            applyPlayerBringState(true)
        else
            bringFreecamActive = false
            if not bringUntouchable then restorePlayerState() end
        end
        WindUI:Notify({Title = "Bring Freecam", Content = "Freecam para Bring: " .. (state and "ATIVADO" or "DESATIVADO"), Color = "Blue", Duration = 2})
    end
})

TabBring:Toggle({
    Title = "Untouchable by Outros",
    Desc = "Torna seu personagem sem colisao enquanto o Bring esta ativo. Pode ser detectado.",
    Callback = function(state)
        if state then
            if not bringUntouchable and not bringFreecamActive then saveOriginalPlayerState() end
            bringUntouchable = true
            applyPlayerBringState(false)
        else
            bringUntouchable = false
            if not bringFreecamActive then restorePlayerState() end
        end
        WindUI:Notify({Title = "Bring Untouchable", Content = "Untouchable para Bring: " .. (state and "ATIVADO" or "DESATIVADO"), Color = "Blue", Duration = 2})
    end
})

local bringMethodDropdown_UI = TabBring:Dropdown({
    Title = "Bring Method",
    Values = {"Simples", "Teleporte"},
    Default = currentBringMethod,
    Callback = function(name)
        currentBringMethod = name
        WindUI:Notify({Title = "Bring Method", Content = "Metodo de Bring: " .. tostring(name), Color = "Blue", Duration = 2})
    end
})

local bringLocalizationDropdown_UI = TabBring:Dropdown({
    Title = "Trazer Localizacao (Destination)",
    Values = {"Voce (Player)"},
    Default = selectedBringDestination,
    Callback = function(name)
        selectedBringDestination = name
        WindUI:Notify({Title = "Bring", Content = "Destino do Bring definido para: " .. tostring(name), Color = "Blue", Duration = 2})
    end
})

local bringHeightInput_UI = TabBring:Input({
    Title = "Bring Height (Altura)",
    Placeholder = tostring(bringHeight),
    Default = tostring(bringHeight),
    Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 0 and numValue <= 200 then
            bringHeight = numValue
        else
            WindUI:Notify({Title = "Bring", Content = "Altura invalida! Use um numero entre 0 e 200.", Color = "Red", Duration = 3})
            bringHeightInput_UI:Set(tostring(bringHeight))
        end
    end
})

TabBring:Divider()

TabBring:Section({ Title = "Configuracoes por Metodo" })

local bringSimpleRangeInput_UI = TabBring:Input({
    Title = "Raio de Busca (Simples)",
    Placeholder = tostring(bringSimpleRange),
    Default = tostring(bringSimpleRange),
    Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 10 and numValue <= 20000 then
            bringSimpleRange = numValue
        else
            WindUI:Notify({Title = "Bring (Simples)", Content = "Raio invalido! Use um numero entre 10 e 20000.", Color = "Red", Duration = 3})
            bringSimpleRangeInput_UI:Set(tostring(bringSimpleRange))
        end
    end
})

local bringSimpleMaxQuantityInput_UI = TabBring:Input({
    Title = "Maximo de Itens por Vez (Simples)",
    Placeholder = tostring(bringSimpleMaxQuantity),
    Default = tostring(bringSimpleMaxQuantity),
    Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 5 and numValue <= 200 then
            bringSimpleMaxQuantity = numValue
        else
            WindUI:Notify({Title = "Bring (Simples)", Content = "Quantidade invalida! Use um numero entre 5 e 200.", Color = "Red", Duration = 3})
            bringSimpleMaxQuantityInput_UI:Set(tostring(bringSimpleMaxQuantity))
        end
    end
})

local bringTPRangeInput_UI = TabBring:Input({
    Title = "Raio de Busca (Teleporte)",
    Placeholder = tostring(bringTPRange),
    Default = tostring(bringTPRange),
    Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 10 and numValue <= 20000 then
            bringTPRange = numValue
        else
            WindUI:Notify({Title = "Bring (Teleporte)", Content = "Raio invalido! Use um numero entre 10 e 20000.", Color = "Red", Duration = 3})
            bringTPRangeInput_UI:Set(tostring(bringTPRange))
        end
    end
})

local bringTPCooldownInput_UI = TabBring:Input({
    Title = "Cooldown entre TP (Teleporte)",
    Placeholder = tostring(bringTPCooldown),
    Default = tostring(bringTPCooldown),
    Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 0.1 and numValue <= 2 then
            bringTPCooldown = numValue
        else
            WindUI:Notify({Title = "Bring (Teleporte)", Content = "Cooldown invalido! Use um numero entre 0.1 e 2.", Color = "Red", Duration = 3})
            bringTPCooldownInput_UI:Set(tostring(bringTPCooldown))
        end
    end
})

TabBring:Toggle({
    Title = "Sem Limite de Quantidade",
    Desc = "Ignora o 'Maximo de Itens por Vez', tentando puxar todos os itens do raio (pode causar lag).",
    Callback = function(state)
        noQuantityLimit = state
        WindUI:Notify({Title = "Bring", Content = "Sem Limite de Quantidade: " .. (state and "ATIVADO" or "DESATIVADO"), Color = "Blue", Duration = 2})
    end
})

TabBring:Divider()

-- Funcao auxiliar para criar dropdowns de item por categoria e BOTÕES
local function createCategoryBringUI(tab, categoryName)
    local categoryControl = CATEGORY_CONTROLS[categoryName]

    local itemsInCategoryList = {}
    for itemName, cat in pairs(ITEM_DATABASE) do
        if cat == categoryName then
            table.insert(itemsInCategoryList, itemName)
        end
    end
    table.sort(itemsInCategoryList)

    local defaultItem = itemsInCategoryList[1] or nil
    categoryControl.specificItem = defaultItem

    local specificItemDropdown_UI = tab:Dropdown({
        Title = categoryName .. " (Item)",
        Values = itemsInCategoryList,
        Default = defaultItem,
        Callback = function(name)
            categoryControl.specificItem = name
        end
    })
    
    tab:Button({
        Title = "Trazer " .. categoryName .. " (Uma Vez)",
        Desc = "Puxa os itens do tipo selecionado da categoria " .. categoryName .. " uma vez para o destino.",
        Callback = function()
            bringItemsOnceForCategory(categoryName)
        end
    })
    return specificItemDropdown_UI -- Retorna a referência do dropdown
end

-- Criacao dos controles de Bring por Categoria (manual, um item por vez)
local bringCategoryDropdowns = {}
for _, categoryName in ipairs(BRINGABLE_CATEGORIES_LIST) do
    if categoryName == "Meteorito" then TabBring:Section({ Title = "Trazer Itens de Meteorito (Manual)" }) end
    if categoryName == "Cultista" then TabBring:Section({ Title = "Trazer Itens Cultistas (Manual)" }) end
    if categoryName == "Armas e Armaduras" then TabBring:Section({ Title = "Trazer Armas e Armaduras (Manual)" }) end
    if categoryName == "Combustivel" then TabBring:Section({ Title = "Trazer Combustivel (Manual)" }) end
    if categoryName == "Comida e Cura" then TabBring:Section({ Title = "Trazer Comida e Cura (Manual)" }) end
    if categoryName == "Sucata" then TabBring:Section({ Title = "Trazer Sucata (Manual)" }) end
    if categoryName == "Outros" then TabBring:Section({ Title = "Trazer Outros Itens (Manual)" }) end

    bringCategoryDropdowns[categoryName] = createCategoryBringUI(TabBring, categoryName)
end

TabBring:Divider()

-- Novo Multi-select Dropdown para Bring Automatico
TabBring:Section({ Title = "Bring Automatico Multi-Categoria" })

local multiCategoryBringDropdown_UI = TabBring:Dropdown({
    Title = "Categorias para Bring Automatico",
    Values = BRINGABLE_CATEGORIES_LIST,
    Multi = true,
    AllowNone = true,
    Callback = function(selectedCategories)
        local previouslyActive = {}
        for categoryName, control in pairs(CATEGORY_CONTROLS) do
            if control.autoBringActive then
                table.insert(previouslyActive, categoryName)
            end
        end

        -- Desativa categorias que não estão mais selecionadas
        for _, categoryName in ipairs(previouslyActive) do
            local isStillSelected = false
            for _, selectedCat in ipairs(selectedCategories) do
                if selectedCat == categoryName then
                    isStillSelected = true
                    break
                end
            end
            if not isStillSelected then
                deactivateAutoBringForCategory(categoryName)
            end
        end

        -- Ativa categorias que foram recém-selecionadas
        for _, selectedCat in ipairs(selectedCategories) do
            local control = CATEGORY_CONTROLS[selectedCat]
            if control and not control.autoBringActive then
                activateAutoBringForCategory(selectedCat)
            end
        end
    end
})

TabCombate:Section({ Title = "Kill Aura" })
TabCombate:Toggle({
    Title = "Ativar Kill Aura",
    Desc = "Ataca jogadores, animais e corta arvores automaticamente (com machado equipado).",
    Callback = toggleKillAura
})

local killAuraRangeInput_UI = TabCombate:Input({
    Title = "Raio da Kill Aura",
    Placeholder = tostring(killAuraRange),
    Default = tostring(killAuraRange),
    Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 10 and numValue <= 200 then
            killAuraRange = numValue
        else
            WindUI:Notify({Title = "Kill Aura", Content = "Raio invalido! Use um numero entre 10 e 200.", Color = "Red", Duration = 3})
            killAuraRangeInput_UI:Set(tostring(killAuraRange))
        end
    end
})

TabTeleporte:Section({ Title = "Movimento do Jogador" })
local walkspeedInput_UI = TabTeleporte:Input({
    Title = "Velocidade (WalkSpeed)",
    Placeholder = tostring(currentWalkSpeed),
    Default = tostring(currentWalkSpeed),
    Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 0 and numValue <= 500 then
            currentWalkSpeed = numValue
            applyPlayerMovement()
            WindUI:Notify({Title = "Movimento", Content = "Velocidade: " .. numValue, Color = "Blue", Duration = 2})
        else
            WindUI:Notify({Title = "Movimento", Content = "Valor de velocidade invalido! Use um numero entre 0 e 500.", Color = "Red", Duration = 3})
            walkspeedInput_UI:Set(tostring(currentWalkSpeed))
        end
    end
})
local jumppowerInput_UI = TabTeleporte:Input({
    Title = "Poder de Pulo (JumpPower)",
    Placeholder = tostring(currentJumpPower),
    Default = tostring(currentJumpPower),
    Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 0 and numValue <= 500 then
            currentJumpPower = numValue
            applyPlayerMovement()
            WindUI:Notify({Title = "Movimento", Content = "Pulo: " .. numValue, Color = "Blue", Duration = 2})
        else
            WindUI:Notify({Title = "Movimento", Content = "Valor de pulo invalido! Use um numero entre 0 e 500.", Color = "Red", Duration = 3})
            jumppowerInput_UI:Set(tostring(currentJumpPower))
        end
    end
})

TabTeleporte:Section({ Title = "Teleporte Rapido" })
TabTeleporte:Button({
    Title = "TP para Fogueira",
    Desc = "Teleporta voce para a fogueira principal (MainFire).",
    Callback = function()
        local foundMainFire = nil
        for instance, _ in pairs(trackedStructures) do
            if instance and instance.Parent and find(CAMPFIRE_STRUCTURE_NAMES, instance.Name) then
                foundMainFire = instance
                break
            end
        end
        if foundMainFire then
            teleportToPosition(getSafePosition(foundMainFire), "Fogueira ("..foundMainFire.Name..")")
        else
            WindUI:Notify({Title = "Teleporte", Content = "Nenhuma fogueira encontrada no mapa.", Color = "Red", Duration = 3})
        end
    end
})
TabTeleporte:Button({
    Title = "TP para Bancada",
    Desc = "Teleporta voce para a bancada de trabalho principal (CraftingBench).",
    Callback = function()
        local foundCraftingBench = nil
        for instance, _ in pairs(trackedStructures) do
            if instance and instance.Parent and find(WORKBENCH_STRUCTURE_NAMES, instance.Name) then
                foundCraftingBench = instance
                break
            end
        end
        if foundCraftingBench then
            teleportToPosition(getSafePosition(foundCraftingBench), "Bancada ("..foundCraftingBench.Name..")")
        else
            WindUI:Notify({Title = "Teleporte", Content = "Nenhuma bancada de trabalho encontrada no mapa.", Color = "Red", Duration = 3})
        end
    end
})

TabTeleporte:Button({
    Title = "TP para Acampamento",
    Desc = "Teleporta voce para o acampamento principal.",
    Callback = function()
        local foundCampground = nil
        for instance, _ in pairs(trackedStructures) do
            if instance and instance.Parent and find(CAMPGROUND_NAMES, instance.Name) then
                foundCampground = instance
                break
            end
        end
        if foundCampground then
            teleportToPosition(getSafePosition(foundCampground), "Acampamento ("..foundCampground.Name..")")
        else
            WindUI:Notify({Title = "Teleporte", Content = "Nenhum acampamento encontrado no mapa.", Color = "Red", Duration = 3})
        end
    end
})

TabTeleporte:Button({
    Title = "TP para Arvore Gigante",
    Desc = "Teleporta voce para a Arvore Gigante mais proxima.",
    Callback = function()
        local foundGiantTree = nil
        for instance, _ in pairs(trackedStructures) do
            if instance and instance.Parent and find(GIANT_TREE_NAMES, instance.Name) then
                foundGiantTree = instance
                break
            end
        end
        if foundGiantTree then
            teleportToPosition(getSafePosition(foundGiantTree), "Arvore Gigante ("..foundGiantTree.Name..")")
        else
            WindUI:Notify({Title = "Teleporte", Content = "Nenhuma Arvore Gigante encontrada no mapa.", Color = "Red", Duration = 3})
        end
    end
})

local selectedKid = "Nenhum"
local kidDropdown_UI = TabTeleporte:Dropdown({
    Title = "TP para Crianca:",
    Values = {"Nenhum"},
    Default = selectedKid,
    Callback = function(name)
        selectedKid = name
        WindUI:Notify({Title = "Teleporte", Content = "Crianca selecionada: " .. tostring(name), Color = "Blue", Duration = 2})
    end
})
TabTeleporte:Button({
    Title = "Teleportar para Crianca",
    Desc = "Teleporta para a crianca selecionada no dropdown.",
    Callback = function()
        if selectedKid == "Nenhum" then
            WindUI:Notify({Title = "Teleporte", Content = "Nenhuma crianca selecionada.", Color = "Red", Duration = 3})
            return
        end
        local pureName, targetX, targetZ = parseDestinationString(selectedKid)
        local targetInstance = nil
        for instance, _ in pairs(trackedKids) do
            if instance and instance.Parent then
                local instancePos = getSafePosition(instance)
                if instancePos and instance.Name == pureName and
                   math.floor(instancePos.X) == targetX and math.floor(instancePos.Z) == targetZ then
                    targetInstance = instance
                    break
                end
            end
        end
        if targetInstance then
            teleportToPosition(getSafePosition(targetInstance), tostring(targetInstance.Name))
        else
            WindUI:Notify({Title = "Teleporte", Content = "Crianca '" .. tostring(pureName) .. "' nao encontrada ou invalida!", Color = "Red", Duration = 3})
        end
    end
})

-- ===================================================================
--                     HUD - PARAR BRING
-- ===================================================================

local stopBringButton = Instance.new("TextButton")
stopBringButton.Name = "StopBringButton"
stopBringButton.Size = UDim2.new(0, 100, 0, 50)
stopBringButton.Position = UDim2.new(0.5, -50, 1, -100) -- Meio da parte inferior, offset
stopBringButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
stopBringButton.TextColor3 = Color3.fromRGB(255, 255, 255)
stopBringButton.Text = "PARAR TUDO" -- Mais genérico
stopBringButton.Font = Enum.Font.SourceSansBold
stopBringButton.TextSize = 18
stopBringButton.ZIndex = 10 -- Garante que fique por cima de outros GUIs
stopBringButton.Visible = false -- Invisivel por padrao
stopBringButton.Active = true -- Pode ser clicado

local stopBringGui = Instance.new("ScreenGui")
stopBringGui.Name = "StopBringHUD"
stopBringGui.Parent = Player:WaitForChild("PlayerGui")
stopBringButton.Parent = stopBringGui

stopBringButton.MouseButton1Click:Connect(function()
    for categoryName, control in pairs(CATEGORY_CONTROLS) do
        if control.autoBringActive then
            deactivateAutoBringForCategory(categoryName)
        end
    end
    -- Resetar os toggles globais de bring
    bringFreecamActive = false
    bringUntouchable = false
    -- Restaurar o estado do jogador
    restorePlayerState()
    stopBringButton.Visible = false
    WindUI:Notify({Title = "Pânico", Content = "Todos os Brings desativados e estado do jogador restaurado!", Color = "Red", Duration = 3})
end)


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
    saveOriginalPlayerState() -- Salva o estado original na criação do personagem
    applyPlayerMovement()
    if walkspeedInput_UI then walkspeedInput_UI:Set(tostring(currentWalkSpeed)) end
    if jumppowerInput_UI then jumppowerInput_UI:Set(tostring(currentJumpPower)) end
end

RunService.RenderStepped:Connect(function()
    pcall(function()
        updatePlayersEsp()
    end)
end)

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

Workspace.DescendantAdded:Connect(function(instance)
    onItemAdded(instance)
    updateAllDropdowns()
end)

Workspace.DescendantRemoving:Connect(function(instance)
    onItemRemoved(instance)
    updateAllDropdowns()
end)

initializeItemTracking()
findRemoteEvents()

task.wait(1)
if Player.Character then
    onCharacterAdded(Player.Character)
end

applyPlayerMovement()
updateStopButtonVisibility() -- Garante que o botao esteja invisivel no inicio

WindUI:Notify({Title = "Script 99 Noites", Content = "Script carregado com sucesso!", Color = "Dark", Duration = 3})-- ===================================================================
--                  CARREGAMENTO DA BIBLIOTECA WINDUI
-- ===================================================================
local WindUI

-- Função para baixar e carregar o WindUI de forma mais robusta
local function loadWindUI()
    local WindUI_Code, WindUI_Code_Error
    local successHttp, httpResult = pcall(function()
        return game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua")
    end)

    if not successHttp then
        warn("Erro ao tentar obter o código do WindUI via HTTP: ", httpResult)
        error("Nao foi possivel obter a interface (erro de rede). Abortando script.")
    end

    WindUI_Code = httpResult
    if not WindUI_Code or #WindUI_Code == 0 then
        warn("Nenhum código do WindUI foi retornado via HTTP.")
        error("Nao foi possivel obter a interface (código vazio). Abortando script.")
    end

    local loaderSuccess, loaderResult = pcall(loadstring, WindUI_Code)

    if not loaderSuccess then
        warn("Erro ao compilar o código do WindUI (erro de sintaxe): ", loaderResult)
        error("Nao foi possivel compilar a interface (código inválido). Abortando script.")
    end

    if not loaderResult then
        warn("Loadstring retornou nil (código do WindUI inválido, mas sem erro de sintaxe explícito).")
        error("Nao foi possivel carregar a interface (código ilegível). Abortando script.")
    end

    local executionSuccess, executionResult = pcall(loaderResult)

    if not executionSuccess then
        warn("Erro ao executar o script do WindUI: ", executionResult)
        error("Nao foi possivel executar a interface. Abortando script.")
    end

    if not executionResult then
        warn("O script do WindUI foi executado mas nao retornou o objeto da UI (nil).")
        error("Nao foi possivel carregar a interface (retorno vazio). Abortando script.")
    end

    return executionResult
end

-- Tenta carregar o WindUI e captura qualquer erro fatal
local successWindUI, loadedWindUI = pcall(loadWindUI)
if not successWindUI then
    error(loadedWindUI) -- Propaga o erro capturado por loadWindUI
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
local bringHeight = 50 -- Altura padrao para onde os itens sao puxados
local noQuantityLimit = false -- Sem Limite de Quantidade
local selectedBringDestination = "Voce (Player)"
local BRING_AUTO_COOLDOWN = 1.0 -- Cooldown para o Bring Automatico (por categoria)
local activeAutoBringCount = 0 -- Contador de categorias com auto-bring ativo

-- Player original state for Bring TP / Untouchable / Freecam
local originalPlayerWalkSpeed = 16
local originalPlayerJumpPower = 50
local originalPlayerCanCollide = true
local originalPlayerTransparency = 0
local originalPlayerPlatformStand = false
local originalCameraType = Camera.CameraType
local originalCameraSubject = Camera.CameraSubject
local originalCameraCFrame = Camera.CFrame or CFrame.new() -- Garante valor inicial

-- BRING METHODS
local currentBringMethod = "Simples" -- "Simples" ou "Teleporte"

-- BRING SIMPLES (Antigo Bring 1)
local bringSimpleRange = 10000
local bringSimpleMaxQuantity = 50

-- BRING TELEPORTE (Antigo Bring 2)
local bringTPRange = 10000
local bringTPCooldown = 0.5

-- PLAYER MOVEMENT
local currentWalkSpeed = 16
local currentJumpPower = 50

-- ===================================================================
--                  ITENS E CATEGORIAS CONFIGURÁVEIS
-- (Nomes foram ajustados para as prováveis versões em inglês, que funcionam no jogo)
-- ===================================================================

local ITEM_DATABASE = {
    -- Combustivel
    Log = "Combustivel", Wood = "Combustivel", Chair = "Combustivel", Biofuel = "Combustivel", Coal = "Combustivel",
    ["Fuel Canister"] = "Combustivel", ["Oil Barrel"] = "Combustivel", Sapling = "Combustivel",

    -- Comida e Cura
    Carrot = "Comida e Cura", Corn = "Comida e Cura", Pumpkin = "Comida e Cura", Berry = "Comida e Cura", Apple = "Comida e Cura",
    Morsel = "Comida e Cura", ["Cooked Morsel"] = "Comida e Cura", Steak = "Comida e Cura", ["Cooked Steak"] = "Comida e Cura",
    Ribs = "Comida e Cura", ["Cooked Ribs"] = "Comida e Cura", Cake = "Comida e Cura", Chili = "Comida e Cura", Stew = "Comida e Cura",
    ["Hearty Stew"] = "Comida e Cura", ["Meat? Sandwich"] = "Comida e Cura", ["Seafood Chowder"] = "Comida e Cura",
    ["Steak Dinner"] = "Comida e Cura", ["Pumpkin Soup"] = "Comida e Cura", ["BBQ Ribs"] = "Comida e Cura",
    ["Carrot Cake"] = "Comida e Cura", ["Jar o' Jelly"] = "Comida e Cura", Crab = "Comida e Cura", Salmon = "Comida e Cura",
    Swordfish = "Comida e Cura", Fruit = "Comida e Cura", Spice = "Comida e Cura", ["Dinner Meat"] = "Comida e Cura",
    Bandage = "Comida e Cura", Medkit = "Comida e Cura", Pepper = "Comida e Cura",

    -- Sucata (Engrenagens)
    Bolt = "Sucata", Screw = "Sucata", ["Sheet Metal"] = "Sucata", ["UFO Junk"] = "Sucata", ["UFO Component"] = "Sucata",
    ["UFO Scrap"] = "Sucata", ["Broken Fan"] = "Sucata", ["Old Radio"] = "Sucata", ["Broken Microwave"] = "Sucata",
    Tyre = "Sucata", ["Metal Chair"] = "Sucata", ["Old Car Engine"] = "Sucata", ["Washing Machine"] = "Sucata",
    ["Cultist Experiment"] = "Sucata", ["Cultist Prototype"] = "Sucata",

    -- Armas e Armaduras (Equipamento)
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

    -- Outros
    Flower = "Outros", Feather = "Outros", Fire = "Outros", ["Sacrifice Totem"] = "Outros", ["Old Rod"] = "Outros",
    ["Coin Pile"] = "Outros", ["Infernal Bag"] = "Outros", ["Giant Bag"] = "Outros", ["Good Bag"] = "Outros",
    ["Old Lantern"] = "Outros", ["Strong Lantern"] = "Outros", Diamond = "Outros", ["Defense Sketch"] = "Outros",

    -- Meteorito (Nova Categoria)
    ["Meteorite Fragment"] = "Meteorito", ["Gold Fragment"] = "Meteorito",
    ["Raw Obsidian Ore"] = "Meteorito", ["Burning Obsidian Ingot"] = "Meteorito",

    -- Cultista (Nova Categoria)
    Cultist = "Cultista", ["Harpoon Cultist"] = "Cultista",
    ["Cultist Gem"] = "Cultista", ["Gem of the Forest"] = "Cultista"
}

-- Mapeamento de categorias para suas variáveis de controle
local CATEGORY_CONTROLS = {
    Combustivel = {specificItem = nil, lastIndex = 1, lastBringTimeTP = 0, autoBringActive = false, autoBringConnection = nil, lastAutoBringTime = 0},
    ["Comida e Cura"] = {specificItem = nil, lastIndex = 1, lastBringTimeTP = 0, autoBringActive = false, autoBringConnection = nil, lastAutoBringTime = 0},
    Sucata = {specificItem = nil, lastIndex = 1, lastBringTimeTP = 0, autoBringActive = false, autoBringConnection = nil, lastAutoBringTime = 0},
    ["Armas e Armaduras"] = {specificItem = nil, lastIndex = 1, lastBringTimeTP = 0, autoBringActive = false, autoBringConnection = nil, lastAutoBringTime = 0},
    Outros = {specificItem = nil, lastIndex = 1, lastBringTimeTP = 0, autoBringActive = false, autoBringConnection = nil, lastAutoBringTime = 0},
    Meteorito = {specificItem = nil, lastIndex = 1, lastBringTimeTP = 0, autoBringActive = false, autoBringConnection = nil, lastAutoBringTime = 0},
    Cultista = {specificItem = nil, lastIndex = 1, lastBringTimeTP = 0, autoBringActive = false, autoBringConnection = nil, lastAutoBringTime = 0},
}

-- ===================================================================
--                  FUNÇÕES AUXILIARES DE RASTREAMENTO E UTILIDADE
-- ===================================================================

local updateCooldown = 0.5 -- Debounce time for dropdowns (seconds)

-- Função auxiliar para substituir table.find
local function find(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

local BRINGABLE_CATEGORIES_LIST = {}
for itemName, category in pairs(ITEM_DATABASE) do
    if not find(BRINGABLE_CATEGORIES_LIST, category) then
        table.insert(BRINGABLE_CATEGORIES_LIST, category)
    end
end
table.sort(BRINGABLE_CATEGORIES_LIST)

local CAMPFIRE_STRUCTURE_NAMES = {"MainFire", "Camp", "Fogueira", "Campfire", "Lareira"}
local WORKBENCH_STRUCTURE_NAMES = {"CraftingBench", "Crafting Bench", "Workbench", "Work Bench", "Bancada", "CraftingTable", "Crafting Table"}
local CAMPGROUND_NAMES = {"Campground", "CampArea", "BaseCamp", "AcampamentoPrincipal", "SmallCamp"}
local GIANT_TREE_NAMES = {"TreeGiant", "GiantTree"}

local KID_NAMES = {"DinoKid", "KrakenKid", "SquidKid", "KoalaKid"}

local ALL_TRACKED_STRUCTURE_NAMES_TO_DISPLAY = {}
for _, name in ipairs(CAMPFIRE_STRUCTURE_NAMES) do table.insert(ALL_TRACKED_STRUCTURE_NAMES_TO_DISPLAY, name) end
for _, name in ipairs(WORKBENCH_STRUCTURE_NAMES) do table.insert(ALL_TRACKED_STRUCTURE_NAMES_TO_DISPLAY, name) end
for _, name in ipairs(CAMPGROUND_NAMES) do table.insert(ALL_TRACKED_STRUCTURE_NAMES_TO_DISPLAY, name) end
for _, name in ipairs(GIANT_TREE_NAMES) do table.insert(ALL_TRACKED_STRUCTURE_NAMES_TO_DISPLAY, name) end

local trackedGroundItems = {}
local trackedStructures = {}
local trackedKids = {}
local trackedAnimals = {}
local trackedTreesForKA = {}

-- KILL AURA
local killAuraAtivo = false
local killAuraConnection = nil
local killAuraRange = 50

local REPLICATED_STORAGE_EVENTS_PATH = game:GetService("ReplicatedStorage"):FindFirstChild("RemoteEvents")
local damageEvents = {}
local chopEvents = {}

local ANIMAL_NAMES = {"Bunny", "Bear", "Wolf", "Spider", "Scorpion", "Crow"}
local TREE_STRUCTURE_NAMES = {"TreeBig", "Small Tree", "Snowy Small Tree", "Dead Tree1", "Dead Tree2", "Dead Tree3"}


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
            if timer then
                task.cancel(timer)
            end
            timer = task.delay(delay - (currentTime - lastCallTime), function()
                lastCallTime = tick()
                func(unpack(args))
            end)
        end
    end
end

local function parseDestinationString(destinationString)
    local pureName, x_str, z_str = destinationString:match("^(.-)%s*%((%d+),%s*(%d+)%)")

    if not pureName then -- Se não houver coordenadas, pode ser apenas o nome (ex: "Voce (Player)" ou "Nenhum")
        pureName = destinationString:match("^(.-)%s*%(Player%)") or destinationString
    end

    local colonPos = pureName:find(":")
    if colonPos then
        pureName = pureName:sub(colonPos + 2) -- +2 para pular ": "
    end
    
    local targetX = tonumber(x_str)
    local targetZ = tonumber(z_str)
    
    return pureName, targetX, targetZ
end

local function getSafePosition(instance)
    if not instance or not instance.Parent then return nil end
    if instance:IsA("BasePart") then
        return instance.Position
    elseif instance:IsA("Model") then
        local primaryPart = instance.PrimaryPart
        if primaryPart and primaryPart:IsA("BasePart") then
            return primaryPart.Position
        end
        local centerPart = instance:FindFirstChild("Center") or instance:FindFirstChild("Primary") or instance:FindFirstChildWhichIsA("BasePart")
        if centerPart and centerPart:IsA("BasePart") then
            return centerPart.Position
        end
    end
    return nil
end

local function updatePlayersEsp()
    if not espPlayersAtivo then
        for char, highlight in pairs(espHighlights) do
            if highlight and highlight.Parent then highlight:Destroy() end
            espHighlights[char] = nil
        end
        return
    end

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            if not espHighlights[p.Character] then
                local highlight = Instance.new("Highlight")
                highlight.OutlineColor = espColor
                highlight.FillColor = Color3.fromRGB(0, 255, 0) -- Pode ser ligeiramente transparente ou a mesma cor da outline
                highlight.FillTransparency = 0.7
                highlight.Parent = p.Character
                espHighlights[p.Character] = highlight
            else
                espHighlights[p.Character].OutlineColor = espColor
                espHighlights[p.Character].FillColor = espColor
            end
        elseif espHighlights[p.Character] then -- Remove highlight se o jogador perdeu o personagem
            if espHighlights[p.Character] and espHighlights[p.Character].Parent then espHighlights[p.Character]:Destroy() end
            espHighlights[p.Character] = nil
        end
    end
    -- Remove highlights para personagens que não existem mais
    for char, highlight in pairs(espHighlights) do
        if not char.Parent then -- Personagem não está mais no Workspace
            if highlight and highlight.Parent then highlight:Destroy() end
            espHighlights[char] = nil
        end
    end
end

-- Função centralizada para adicionar itens a todas as tabelas de rastreamento
local function onItemAdded(instance)
    if not instance or not instance.Parent or not (instance:IsA("BasePart") or instance:IsA("Model")) then return end

    if ITEM_DATABASE[instance.Name] then
        trackedGroundItems[instance] = true
        return
    end

    if find(ALL_TRACKED_STRUCTURE_NAMES_TO_DISPLAY, instance.Name) then
        if getSafePosition(instance) then trackedStructures[instance] = true end
        return
    end

    if find(KID_NAMES, instance.Name) then
        if getSafePosition(instance) then trackedKids[instance] = true end
        return
    end

    if find(ANIMAL_NAMES, instance.Name) and instance:FindFirstChildOfClass("Humanoid") then
        if getSafePosition(instance) then trackedAnimals[instance] = true end
        return
    end
    if find(TREE_STRUCTURE_NAMES, instance.Name) then
        if getSafePosition(instance) then trackedTreesForKA[instance] = true end
        return
    end
end

-- Função centralizada para remover itens de todas as tabelas de rastreamento
local function onItemRemoved(instance)
    if trackedGroundItems[instance] then trackedGroundItems[instance] = nil end
    if trackedStructures[instance] then trackedStructures[instance] = nil end
    if trackedKids[instance] then trackedKids[instance] = nil end
    if trackedAnimals[instance] then trackedAnimals[instance] = nil end
    if trackedTreesForKA[instance] then trackedTreesForKA[instance] = nil end
end

local function initializeItemTracking()
    trackedGroundItems = {}
    trackedStructures = {}
    trackedKids = {}
    trackedAnimals = {}
    trackedTreesForKA = {}

    for _, instance in pairs(Workspace:GetDescendants()) do
        onItemAdded(instance)
    end
end

local debouncedUpdateBringDestinationDropdown = debounce(function(dropdown)
    local currentDestinations = {"Voce (Player)"}

    local tempTracked = {}
    for instance, _ in pairs(trackedStructures) do table.insert(tempTracked, instance) end
    for instance, _ in pairs(trackedKids) do table.insert(tempTracked, instance) end

    for _, instance in ipairs(tempTracked) do
        if instance and instance.Parent then
            local instancePosition = getSafePosition(instance)
            if instancePosition then
                local nameToDisplay = tostring(instance.Name)
                if find(CAMPFIRE_STRUCTURE_NAMES, instance.Name) then
                    nameToDisplay = "Fogueira: " .. nameToDisplay
                elseif find(WORKBENCH_STRUCTURE_NAMES, instance.Name) then
                    nameToDisplay = "Bancada: " .. nameToDisplay
                elseif find(CAMPGROUND_NAMES, instance.Name) then
                    nameToDisplay = "Acampamento: " .. nameToDisplay
                elseif find(GIANT_TREE_NAMES, instance.Name) then
                    nameToDisplay = "Arvore Gigante: " .. nameToDisplay
                elseif find(KID_NAMES, instance.Name) then
                    nameToDisplay = "Crianca: " .. nameToDisplay
                end
                table.insert(currentDestinations, nameToDisplay .. " (" .. tostring(math.floor(instancePosition.X)) .. ", " .. tostring(math.floor(instancePosition.Z)) .. ")")
            end
        end
    end
    
    if dropdown and dropdown.Refresh then
        dropdown:Refresh(currentDestinations)
    else
        warn("Dropdown de destino do Bring (ou refresh) nao encontrado/valido!")
    end
end, updateCooldown)

local debouncedUpdateKidDropdown = debounce(function(dropdown)
    local currentKids = {"Nenhum"}
    for instance, _ in pairs(trackedKids) do
        if instance and instance.Parent then
            local instancePosition = getSafePosition(instance)
            if instancePosition then
                table.insert(currentKids, tostring(instance.Name) .. " (" .. tostring(math.floor(instancePosition.X)) .. ", " .. tostring(math.floor(instancePosition.Z)) .. ")")
            end
        end
    end
    if dropdown and dropdown.Refresh then
        dropdown:Refresh(currentKids)
    else
        warn("Dropdown de criancas (ou refresh) nao encontrado/valido!")
    end
end, updateCooldown)

local function getAllItemNamesForCategory(categoryName)
    local itemNames = {}
    for itemName, cat in pairs(ITEM_DATABASE) do
        if cat == categoryName then
            table.insert(itemNames, itemName)
        end
    end
    return itemNames
end

-- ===================================================================
--                  FUNÇÕES DO BRING
-- ===================================================================

local function getBringTargetCFrame(destinationString, playerHrp)
    local offsetY = bringHeight 
    if destinationString == "Voce (Player)" and playerHrp and playerHrp.Parent then
        return playerHrp.CFrame * CFrame.new(0, offsetY, -3) 
    else
        local pureName, targetX, targetZ = parseDestinationString(destinationString)
        
        local targetInstance = nil
        local allTracked = {}
        for inst, _ in pairs(trackedStructures) do table.insert(allTracked, inst) end
        for inst, _ in pairs(trackedKids) do table.insert(allTracked, inst) end

        for _, instance in ipairs(allTracked) do
            if instance and instance.Parent then
                local instancePos = getSafePosition(instance)
                if instancePos and instance.Name == pureName and
                   math.floor(instancePos.X) == targetX and math.floor(instancePos.Z) == targetZ then
                    targetInstance = instance
                    break
                end
            end
        end
        
        if targetInstance then
            local instancePosition = getSafePosition(targetInstance)
            if not instancePosition then return nil end
            
            -- Lógica aprimorada para fogueiras e bancadas
            local finalPosition = instancePosition
            if find(CAMPFIRE_STRUCTURE_NAMES, targetInstance.Name) and targetInstance:FindFirstChild("Center") then
                finalPosition = targetInstance.Center.Position
            elseif find(WORKBENCH_STRUCTURE_NAMES, targetInstance.Name) and targetInstance:FindFirstChild("Main") then
                finalPosition = targetInstance.Main.Position
            end

            return CFrame.new(finalPosition) * CFrame.new(0, offsetY, 0)
        end
    end
    return nil
end

local function saveOriginalPlayerState()
    local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if humanoid then
        originalPlayerWalkSpeed = humanoid.WalkSpeed
        originalPlayerJumpPower = humanoid.JumpPower
        originalPlayerPlatformStand = humanoid.PlatformStand
    end
    if hrp then
        originalPlayerCanCollide = hrp.CanCollide
        local torso = Player.Character:FindFirstChild("Torso") or Player.Character:FindFirstChild("UpperTorso")
        originalPlayerTransparency = (torso and torso.Transparency) or 0
    end
    if Camera then
        originalCameraType = Camera.CameraType
        originalCameraSubject = Camera.CameraSubject
        originalCameraCFrame = Camera.CFrame
    end
end

local function restorePlayerState()
    local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")

    if humanoid and humanoid.Parent then
        humanoid.WalkSpeed = originalPlayerWalkSpeed
        humanoid.JumpPower = originalPlayerJumpPower
        humanoid.PlatformStand = originalPlayerPlatformStand
    end
    if hrp and hrp.Parent then
        hrp.CanCollide = originalPlayerCanCollide
        for _, part in ipairs(Player.Character:GetChildren()) do
            if part:IsA("BasePart") then
                part.Transparency = originalPlayerTransparency
                part.CanCollide = originalPlayerCanCollide
            end
        end
    end

    -- Restore Camera for Freecam
    if Camera and originalCameraType then
        Camera.CameraType = originalCameraType
        Camera.CameraSubject = originalCameraSubject
        Camera.CFrame = originalCameraCFrame -- Restaurar CFrame da câmera
    end
    WindUI:Notify({Title = "Bring", Content = "Estado do jogador restaurado.", Color = "Gray", Duration = 2})
end

local function applyPlayerBringState(disconnectCamera)
    local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not hrp or not humanoid.Parent or not hrp.Parent then 
        warn("Humanoid ou HRP do Player nao encontrados para aplicar estado do Bring.")
        return 
    end

    -- Aplica os estados
    if bringFreecamActive then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        humanoid.PlatformStand = true
        for _, part in ipairs(Player.Character:GetChildren()) do
            if part:IsA("BasePart") then
                part.Transparency = 1
                part.CanCollide = false
            end
        end
        if Camera and disconnectCamera then
            Camera.CameraType = Enum.CameraType.Scriptable
            Camera.CFrame = Camera.CFrame -- Mantem a camera onde esta
            WindUI:Notify({Title = "Bring Freecam", Content = "Ativado (camera solta, personagem intangivel).", Color = "Yellow", Duration = 2})
        end
    elseif bringUntouchable then
        humanoid.PlatformStand = originalPlayerPlatformStand
        humanoid.WalkSpeed = originalPlayerWalkSpeed
        humanoid.JumpPower = originalPlayerJumpPower
        for _, part in ipairs(Player.Character:GetChildren()) do
            if part:IsA("BasePart") then
                part.Transparency = originalPlayerTransparency
                part.CanCollide = false
            end
        end
        if Camera then Camera.CameraType = originalCameraType end -- Restore camera if it was freecam
        WindUI:Notify({Title = "Bring Untouchable", Content = "Ativado (personagem sem colisao).", Color = "Yellow", Duration = 2})
    else
        restorePlayerState() -- Should not happen if logic is correct, but as a fallback
    end
end

-- Lógica unificada para trazer itens (agora chamada por `bringItemsOnceForCategory` e `activateAutoBringForCategory`)
local function runBringLogic(categoryName, itemsToBringList, bringRange, maxQuantity, bringCooldown, bringMethod)
    if not Player.Character then return false end
    local playerHrp = Player.Character:FindFirstChild("HumanoidRootPart")
    local playerHumanoid = Player.Character:FindFirstChildOfClass("Humanoid")
    if not playerHrp or not playerHrp.Parent or not playerHumanoid or not playerHumanoid.Parent then return false end

    local targetCFrame = getBringTargetCFrame(selectedBringDestination, playerHrp)
    if not targetCFrame then 
        WindUI:Notify({Title = "Bring", Content = "Destino '" .. selectedBringDestination .. "' nao encontrado ou invalido!", Color = "Red", Duration = 3})
        return false -- Indica falha
    end

    if not itemsToBringList or #itemsToBringList == 0 then return false end

    local itemsFoundInRange = {}
    for itemInstance, _ in pairs(trackedGroundItems) do
        if itemInstance and itemInstance.Parent and find(itemsToBringList, itemInstance.Name) then
            local itemPosition = getSafePosition(itemInstance)
            if itemPosition and (playerHrp.Position - itemPosition).Magnitude <= bringRange then
                table.insert(itemsFoundInRange, itemInstance)
            end
        end
    end
    
    local actualItemsPulled = 0

    if bringMethod == "Simples" then
        local currentMaxQuantity = noQuantityLimit and #itemsFoundInRange or maxQuantity
        local categoryControl = CATEGORY_CONTROLS[categoryName]
        categoryControl.lastIndex = categoryControl.lastIndex or 1

        local itemsProcessedThisFrame = 0
        local startIndex = categoryControl.lastIndex

        -- Loop para encontrar e puxar itens
        for i = 1, #itemsFoundInRange do
            local currentItemIndex = (startIndex + i - 2) % #itemsFoundInRange + 1 -- Cicla pelos itens
            local itemInstance = itemsFoundInRange[currentItemIndex]

            if itemInstance and itemInstance.Parent then
                local primaryPart = itemInstance:IsA("Model") and itemInstance.PrimaryPart
                local targetPart = nil

                if itemInstance:IsA("BasePart") then
                    targetPart = itemInstance
                elseif primaryPart and primaryPart.Parent then
                    targetPart = primaryPart
                else
                    targetPart = itemInstance:FindFirstChild("Center") or itemInstance:FindFirstChild("Primary") or itemInstance:FindFirstChildWhichIsA("BasePart")
                end

                if targetPart and targetPart.Parent and targetPart:IsA("BasePart") then
                    targetPart.Anchored = false -- GARANTE QUE O ITEM CAIA
                    targetPart.CanCollide = false -- Desativa colisao antes de mover

                    -- Adiciona um offset aleatório para espalhar os itens
                    local randomOffsetX = math.random() * 1.5 - 0.75 -- entre -0.75 e 0.75 para espalhamento
                    local randomOffsetZ = math.random() * 1.5 - 0.75
                    local spreadCFrame = targetCFrame * CFrame.new(randomOffsetX, 0, randomOffsetZ)

                    if itemInstance:IsA("Model") then
                        itemInstance:SetPrimaryPartCFrame(spreadCFrame * CFrame.Angles(targetPart.CFrame:ToOrientation()))
                    else
                        itemInstance.CFrame = spreadCFrame * CFrame.Angles(targetPart.CFrame:ToOrientation())
                    end
                    targetPart.CanCollide = true -- Reativa colisao para cair

                    itemsProcessedThisFrame = itemsProcessedThisFrame + 1
                    actualItemsPulled = actualItemsPulled + 1
                    task.wait(0.01) -- COOLDOWN MÍNIMO PARA CADA ITEM CAIR

                    if itemsProcessedThisFrame >= currentMaxQuantity then
                        categoryControl.lastIndex = currentItemIndex + 1
                        if categoryControl.lastIndex > #itemsFoundInRange then categoryControl.lastIndex = 1 end
                        return actualItemsPulled > 0
                    end
                end
            end
        end
        categoryControl.lastIndex = 1 -- Reinicia se todos os itens foram processados
        return actualItemsPulled > 0
        

    elseif bringMethod == "Teleporte" then
        if tick() - CATEGORY_CONTROLS[categoryName].lastBringTimeTP < bringCooldown then return false end

        local itemToBring = nil
        local minDistance = bringRange + 1

        for itemInstance, _ in pairs(trackedGroundItems) do
            if itemInstance and itemInstance.Parent and find(itemsToBringList, itemInstance.Name) then
                local itemPosition = getSafePosition(itemInstance)
                if itemPosition then
                    local currentDistance = (playerHrp.Position - itemPosition).Magnitude
                    if currentDistance <= bringRange and currentDistance < minDistance then
                        minDistance = currentDistance
                        itemToBring = itemInstance
                    end
                end
            end
        end
        
        if itemToBring and itemToBring.Parent then
            local itemPosition = getSafePosition(itemToBring)
            if not itemPosition then return false end

            pcall(function()
                playerHrp.CFrame = CFrame.new(itemPosition) * CFrame.new(0, 5, 0)
            end)
            task.wait(0.05)

            local primaryPart = itemToBring:IsA("Model") and itemToBring.PrimaryPart
            local targetPart = nil

            if itemToBring:IsA("BasePart") then
                targetPart = itemToBring
            elseif primaryPart and primaryPart.Parent then
                targetPart = primaryPart
            else
                targetPart = itemToBring:FindFirstChild("Center") or itemToBring:FindFirstChild("Primary") or itemToBring:FindFirstChildWhichIsA("BasePart")
            end
            
            if targetPart and targetPart.Parent and targetPart:IsA("BasePart") then
                targetPart.Anchored = false
                targetPart.CanCollide = false

                -- Adiciona um offset aleatório para espalhar os itens
                local randomOffsetX = math.random() * 1.5 - 0.75
                local randomOffsetZ = math.random() * 1.5 - 0.75
                local spreadCFrame = targetCFrame * CFrame.new(randomOffsetX, 0, randomOffsetZ)

                if itemToBring:IsA("Model") then
                    itemToBring:SetPrimaryPartCFrame(spreadCFrame * CFrame.Angles(targetPart.CFrame:ToOrientation()))
                else
                    itemToBring.CFrame = spreadCFrame * CFrame.Angles(targetPart.CFrame:ToOrientation())
                end
                targetPart.CanCollide = true
            end
            
            trackedGroundItems[itemToBring] = nil -- Remove o item da lista após puxá-lo
            task.wait(0.05)

            pcall(function()
                playerHrp.CFrame = targetCFrame * CFrame.new(0, 5, 0)
            end)
            task.wait(0.05)
            
            CATEGORY_CONTROLS[categoryName].lastBringTimeTP = tick()
            actualItemsPulled = actualItemsPulled + 1
            return true
        end
    end
    return actualItemsPulled > 0
end

-- Função para puxar itens de uma categoria UMA VEZ
local function bringItemsOnceForCategory(categoryName)
    if not Player.Character then 
        WindUI:Notify({Title = "Bring Manual", Content = "Personagem nao encontrado.", Color = "Red", Duration = 3})
        return
    end
    local playerHrp = Player.Character:FindFirstChild("HumanoidRootPart")
    local playerHumanoid = Player.Character:FindFirstChildOfClass("Humanoid")
    if not playerHrp or not playerHrp.Parent or not playerHumanoid or not playerHumanoid.Parent then 
        WindUI:Notify({Title = "Bring Manual", Content = "Componentes do personagem nao encontrados.", Color = "Red", Duration = 3})
        return
    end

    local control = CATEGORY_CONTROLS[categoryName]
    if not control then return end

    if not selectedBringDestination or selectedBringDestination == "Nenhum" then
        WindUI:Notify({Title = "Bring Error", Content = "Selecione um destino valido para o Bring!", Color = "Red", Duration = 3})
        return
    end

    if control.specificItem == nil or control.specificItem == "" then
        WindUI:Notify({Title = "Bring Error", Content = "Selecione um item para puxar na categoria '" .. categoryName .. "'!", Color = "Red", Duration = 3})
        return
    end

    local bringRange = (currentBringMethod == "Simples" and bringSimpleRange) or bringTPRange
    local maxQuantity = (currentBringMethod == "Simples" and bringSimpleMaxQuantity) or 1
    local cooldown = (currentBringMethod == "Teleporte" and bringTPCooldown) or 0

    local success = runBringLogic(categoryName, {control.specificItem}, bringRange, maxQuantity, cooldown, currentBringMethod)

    if success then
        WindUI:Notify({Title = "Bring Manual", Content = "Itens de '" .. control.specificItem .. "' puxados para '" .. selectedBringDestination .. "'!", Color = "Green", Duration = 2})
    else
        WindUI:Notify({Title = "Bring Manual", Content = "Nenhum item '" .. control.specificItem .. "' encontrado no raio ou em cooldown.", Color = "Orange", Duration = 2})
    end
end

local function updateStopButtonVisibility()
    stopBringButton.Visible = (activeAutoBringCount > 0)
end

local function activateAutoBringForCategory(categoryName)
    local control = CATEGORY_CONTROLS[categoryName]
    if not control or control.autoBringConnection then return end -- Already active

    local itemsToBringList = getAllItemNamesForCategory(categoryName)
    if #itemsToBringList == 0 then
        warn("Nenhum item encontrado para a categoria " .. categoryName .. ". Nao e possivel iniciar o auto-bring.")
        WindUI:Notify({Title = "Bring Automatico", Content = "Nenhum item para " .. categoryName .. ". Nao ativado.", Color = "Red", Duration = 3})
        return
    end

    control.autoBringActive = true
    activeAutoBringCount = activeAutoBringCount + 1
    updateStopButtonVisibility()

    WindUI:Notify({Title = "Bring Automatico", Content = "Bring de " .. categoryName .. " ATIVADO!", Color = "Green", Duration = 2})

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
    if not control or not control.autoBringConnection then return end -- Not active

    control.autoBringConnection:Disconnect()
    control.autoBringConnection = nil
    control.autoBringActive = false
    activeAutoBringCount = activeAutoBringCount - 1
    updateStopButtonVisibility()

    WindUI:Notify({Title = "Bring Automatico", Content = "Bring de " .. categoryName .. " DESATIVADO!", Color = "Gray", Duration = 2})
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
    if not Player.Character then
        WindUI:Notify({Title = "Teleporte", Content = "Seu personagem nao esta disponivel para teleporte.", Color = "Red", Duration = 3})
        return
    end
    local playerHrp = Player.Character:FindFirstChild("HumanoidRootPart")
    if not playerHrp or not playerHrp.Parent then
        WindUI:Notify({Title = "Teleporte", Content = "HumanoidRootPart do seu personagem nao esta disponivel.", Color = "Red", Duration = 3})
        return
    end

    if position then
        pcall(function()
            playerHrp.CFrame = CFrame.new(position) * CFrame.new(0, 5, 0)
        end)
        WindUI:Notify({Title = "Teleporte", Content = "Teleportado para: " .. tostring(name) .. "!", Color = "Green", Duration = 2})
    else
        WindUI:Notify({Title = "Teleporte", Content = "Nao foi possivel determinar a posicao do destino.", Color = "Red", Duration = 3})
    end
end

-- ===================================================================
--                  KILL AURA FUNÇÕES
-- ===================================================================

local function findRemoteEvents()
    if not REPLICATED_STORAGE_EVENTS_PATH then
        warn("KillAura: Pasta 'RemoteEvents' nao encontrada em ReplicatedStorage. Funcoes de combate/corte nao funcionarao.")
        return
    end

    damageEvents = {}
    chopEvents = {}

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

    if next(damageEvents) == nil then warn("KillAura: Nenhum RemoteEvent de dano encontrado. Kill Aura para players/animais nao pode funcionar.") end
    if next(chopEvents) == nil then warn("KillAura: Nenhum RemoteEvent de corte encontrado. Auto-chop nao pode funcionar.") end
end

local function playerHasAxeEquipped()
    if not Player.Character then return nil end
    local backpack = Player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, item in pairs(backpack:GetChildren()) do
            if item:IsA("Tool") and (item.Name:find("Axe") or item.Name:find("Chainsaw")) then return item end
        end
    end
    for _, child in pairs(Player.Character:GetChildren()) do
        if child:IsA("Tool") and (child.Name:find("Axe") or child.Name:find("Chainsaw")) then return child end
    end
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

            local equippedTool = playerHasAxeEquipped()
            local hasAxe = equippedTool ~= nil

            for _, p in pairs(Players:GetPlayers()) do
                if p ~= Player and p.Character then
                    local targetChar = p.Character
                    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
                    local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")

                    if targetHrp and targetHumanoid and targetHrp.Parent and targetHumanoid.Parent then
                        local targetPosition = targetHrp.Position
                        if (playerPosition - targetPosition).Magnitude <= killAuraRange then
                            local damageEvent = damageEvents["GenericPlayerDamage"]
                            if damageEvent then
                                pcall(function()
                                    damageEvent:FireServer(targetHumanoid, targetHrp, 20, equippedTool and tostring(equippedTool.Name) or "Fist")
                                end)
                            end
                        end
                    end
                end
            end

            for animalInstance, _ in pairs(trackedAnimals) do
                if animalInstance and animalInstance.Parent then
                    local targetHrp = animalInstance:FindFirstChild("HumanoidRootPart")
                    local targetHumanoid = animalInstance:FindFirstChildOfClass("Humanoid")
                    if targetHrp and targetHumanoid and targetHrp.Parent and targetHumanoid.Parent then
                        local targetPosition = getSafePosition(animalInstance)
                        if targetPosition and (playerPosition - targetPosition).Magnitude <= killAuraRange then
                            local damageEvent = damageEvents[animalInstance.Name] or damageEvents["GenericPlayerDamage"]
                            if damageEvent then
                                pcall(function()
                                    damageEvent:FireServer(targetHumanoid, targetHrp, 15, equippedTool and tostring(equippedTool.Name) or "Fist")
                                end)
                            end
                        end
                    end
                end
            end

            if hasAxe then
                for treeInstance, _ in pairs(trackedTreesForKA) do
                    if treeInstance and treeInstance.Parent then
                        local targetPosition = getSafePosition(treeInstance)
                        if targetPosition and (playerPosition - targetPosition).Magnitude <= killAuraRange then
                            local chopEvent = chopEvents[treeInstance.Name]
                            if not chopEvent then chopEvent = chopEvents["GenericChop"] end
                            if chopEvent and equippedTool then
                                pcall(function()
                                    chopEvent:FireServer(treeInstance, equippedTool)
                                end)
                            end
                        end
                    end
                end
            end
        end)
    else
        if killAuraConnection then
            killAuraConnection:Disconnect()
            killAuraConnection = nil
        end
        WindUI:Notify({Title = "Kill Aura", Content = "Kill Aura DESATIVADA!", Color = "Gray", Duration = 2})
    end
end

-- ===================================================================
--                         INTERFACE GRÁFICA
-- ===================================================================

local Window = WindUI:CreateWindow({
    Title = "99 noites",
    Icon = "door-open",
    Author = "by kyuzzy",
    Folder = "99 noites",
    Size = UDim2.fromOffset(400, 550),
    Theme = "Dark"
})

local TabESP = Window:Tab({ Title = "ESP", Icon = "eye" })
local TabBring = Window:Tab({ Title = "Bring Stuff", Icon = "hand-point-right" })
local TabCombate = Window:Tab({ Title = "Combate", Icon = "sword" })
local TabTeleporte = Window:Tab({ Title = "Teleporte", Icon = "compass" })

TabESP:Section({ Title = "ESP de Jogadores" })
TabESP:Toggle({
    Title = "ESP de Jogadores (Verde)",
    Callback = function(state)
        espPlayersAtivo = state
        updatePlayersEsp()
        if state then WindUI:Notify({Title = "ESP", Content = "ESP de Jogadores ATIVADO!", Color = "Green", Duration = 2})
        else WindUI:Notify({Title = "ESP", Content = "ESP de Jogadores DESATIVADO!", Color = "Gray", Duration = 2}) end
    end
})

-- ===================================
--         BRING TAB (Refatorada)
-- ===================================

TabBring:Section({ Title = "Configuracoes Gerais do Bring" })

TabBring:Toggle({
    Title = "Usar Freecam para Trazer Itens",
    Desc = "A camera permanece no lugar, personagem intangivel e invisivel. Pode ser detectado.",
    Callback = function(state)
        if state then
            if not bringUntouchable and not bringFreecamActive then saveOriginalPlayerState() end
            bringFreecamActive = true
            applyPlayerBringState(true)
        else
            bringFreecamActive = false
            if not bringUntouchable then restorePlayerState() end
        end
        WindUI:Notify({Title = "Bring Freecam", Content = "Freecam para Bring: " .. (state and "ATIVADO" or "DESATIVADO"), Color = "Blue", Duration = 2})
    end
})

TabBring:Toggle({
    Title = "Untouchable by Outros",
    Desc = "Torna seu personagem sem colisao enquanto o Bring esta ativo. Pode ser detectado.",
    Callback = function(state)
        if state then
            if not bringUntouchable and not bringFreecamActive then saveOriginalPlayerState() end
            bringUntouchable = true
            applyPlayerBringState(false)
        else
            bringUntouchable = false
            if not bringFreecamActive then restorePlayerState() end
        end
        WindUI:Notify({Title = "Bring Untouchable", Content = "Untouchable para Bring: " .. (state and "ATIVADO" or "DESATIVADO"), Color = "Blue", Duration = 2})
    end
})

local bringMethodDropdown_UI = TabBring:Dropdown({
    Title = "Bring Method",
    Values = {"Simples", "Teleporte"},
    Default = currentBringMethod,
    Callback = function(name)
        currentBringMethod = name
        WindUI:Notify({Title = "Bring Method", Content = "Metodo de Bring: " .. tostring(name), Color = "Blue", Duration = 2})
    end
})

local bringLocalizationDropdown_UI = TabBring:Dropdown({
    Title = "Trazer Localizacao (Destination)",
    Values = {"Voce (Player)"},
    Default = selectedBringDestination,
    Callback = function(name)
        selectedBringDestination = name
        WindUI:Notify({Title = "Bring", Content = "Destino do Bring definido para: " .. tostring(name), Color = "Blue", Duration = 2})
    end
})

local bringHeightInput_UI = TabBring:Input({
    Title = "Bring Height (Altura)",
    Placeholder = tostring(bringHeight),
    Default = tostring(bringHeight),
    Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 0 and numValue <= 200 then
            bringHeight = numValue
        else
            WindUI:Notify({Title = "Bring", Content = "Altura invalida! Use um numero entre 0 e 200.", Color = "Red", Duration = 3})
            bringHeightInput_UI:Set(tostring(bringHeight))
        end
    end
})

TabBring:Divider()

TabBring:Section({ Title = "Configuracoes por Metodo" })

local bringSimpleRangeInput_UI = TabBring:Input({
    Title = "Raio de Busca (Simples)",
    Placeholder = tostring(bringSimpleRange),
    Default = tostring(bringSimpleRange),
    Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 10 and numValue <= 20000 then
            bringSimpleRange = numValue
        else
            WindUI:Notify({Title = "Bring (Simples)", Content = "Raio invalido! Use um numero entre 10 e 20000.", Color = "Red", Duration = 3})
            bringSimpleRangeInput_UI:Set(tostring(bringSimpleRange))
        end
    end
})

local bringSimpleMaxQuantityInput_UI = TabBring:Input({
    Title = "Maximo de Itens por Vez (Simples)",
    Placeholder = tostring(bringSimpleMaxQuantity),
    Default = tostring(bringSimpleMaxQuantity),
    Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 5 and numValue <= 200 then
            bringSimpleMaxQuantity = numValue
        else
            WindUI:Notify({Title = "Bring (Simples)", Content = "Quantidade invalida! Use um numero entre 5 e 200.", Color = "Red", Duration = 3})
            bringSimpleMaxQuantityInput_UI:Set(tostring(bringSimpleMaxQuantity))
        end
    end
})

local bringTPRangeInput_UI = TabBring:Input({
    Title = "Raio de Busca (Teleporte)",
    Placeholder = tostring(bringTPRange),
    Default = tostring(bringTPRange),
    Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 10 and numValue <= 20000 then
            bringTPRange = numValue
        else
            WindUI:Notify({Title = "Bring (Teleporte)", Content = "Raio invalido! Use um numero entre 10 e 20000.", Color = "Red", Duration = 3})
            bringTPRangeInput_UI:Set(tostring(bringTPRange))
        end
    end
})

local bringTPCooldownInput_UI = TabBring:Input({
    Title = "Cooldown entre TP (Teleporte)",
    Placeholder = tostring(bringTPCooldown),
    Default = tostring(bringTPCooldown),
    Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 0.1 and numValue <= 2 then
            bringTPCooldown = numValue
        else
            WindUI:Notify({Title = "Bring (Teleporte)", Content = "Cooldown invalido! Use um numero entre 0.1 e 2.", Color = "Red", Duration = 3})
            bringTPCooldownInput_UI:Set(tostring(bringTPCooldown))
        end
    end
})

TabBring:Toggle({
    Title = "Sem Limite de Quantidade",
    Desc = "Ignora o 'Maximo de Itens por Vez', tentando puxar todos os itens do raio (pode causar lag).",
    Callback = function(state)
        noQuantityLimit = state
        WindUI:Notify({Title = "Bring", Content = "Sem Limite de Quantidade: " .. (state and "ATIVADO" or "DESATIVADO"), Color = "Blue", Duration = 2})
    end
})

TabBring:Divider()

-- Funcao auxiliar para criar dropdowns de item por categoria e BOTÕES
local function createCategoryBringUI(tab, categoryName)
    local categoryControl = CATEGORY_CONTROLS[categoryName]

    local itemsInCategoryList = {}
    for itemName, cat in pairs(ITEM_DATABASE) do
        if cat == categoryName then
            table.insert(itemsInCategoryList, itemName)
        end
    end
    table.sort(itemsInCategoryList)

    local defaultItem = itemsInCategoryList[1] or nil
    categoryControl.specificItem = defaultItem

    local specificItemDropdown_UI = tab:Dropdown({
        Title = categoryName .. " (Item)",
        Values = itemsInCategoryList,
        Default = defaultItem,
        Callback = function(name)
            categoryControl.specificItem = name
        end
    })
    
    tab:Button({
        Title = "Trazer " .. categoryName .. " (Uma Vez)",
        Desc = "Puxa os itens do tipo selecionado da categoria " .. categoryName .. " uma vez para o destino.",
        Callback = function()
            bringItemsOnceForCategory(categoryName)
        end
    })
    return specificItemDropdown_UI -- Retorna a referência do dropdown
end

-- Criacao dos controles de Bring por Categoria (manual, um item por vez)
local bringCategoryDropdowns = {}
for _, categoryName in ipairs(BRINGABLE_CATEGORIES_LIST) do
    if categoryName == "Meteorito" then TabBring:Section({ Title = "Trazer Itens de Meteorito (Manual)" }) end
    if categoryName == "Cultista" then TabBring:Section({ Title = "Trazer Itens Cultistas (Manual)" }) end
    if categoryName == "Armas e Armaduras" then TabBring:Section({ Title = "Trazer Armas e Armaduras (Manual)" }) end
    if categoryName == "Combustivel" then TabBring:Section({ Title = "Trazer Combustivel (Manual)" }) end
    if categoryName == "Comida e Cura" then TabBring:Section({ Title = "Trazer Comida e Cura (Manual)" }) end
    if categoryName == "Sucata" then TabBring:Section({ Title = "Trazer Sucata (Manual)" }) end
    if categoryName == "Outros" then TabBring:Section({ Title = "Trazer Outros Itens (Manual)" }) end

    bringCategoryDropdowns[categoryName] = createCategoryBringUI(TabBring, categoryName)
end

TabBring:Divider()

-- Novo Multi-select Dropdown para Bring Automatico
TabBring:Section({ Title = "Bring Automatico Multi-Categoria" })

local multiCategoryBringDropdown_UI = TabBring:Dropdown({
    Title = "Categorias para Bring Automatico",
    Values = BRINGABLE_CATEGORIES_LIST,
    Multi = true,
    AllowNone = true,
    Callback = function(selectedCategories)
        local previouslyActive = {}
        for categoryName, control in pairs(CATEGORY_CONTROLS) do
            if control.autoBringActive then
                table.insert(previouslyActive, categoryName)
            end
        end

        -- Desativa categorias que não estão mais selecionadas
        for _, categoryName in ipairs(previouslyActive) do
            local isStillSelected = false
            for _, selectedCat in ipairs(selectedCategories) do
                if selectedCat == categoryName then
                    isStillSelected = true
                    break
                end
            end
            if not isStillSelected then
                deactivateAutoBringForCategory(categoryName)
            end
        end

        -- Ativa categorias que foram recém-selecionadas
        for _, selectedCat in ipairs(selectedCategories) do
            local control = CATEGORY_CONTROLS[selectedCat]
            if control and not control.autoBringActive then
                activateAutoBringForCategory(selectedCat)
            end
        end
    end
})

TabCombate:Section({ Title = "Kill Aura" })
TabCombate:Toggle({
    Title = "Ativar Kill Aura",
    Desc = "Ataca jogadores, animais e corta arvores automaticamente (com machado equipado).",
    Callback = toggleKillAura
})

local killAuraRangeInput_UI = TabCombate:Input({
    Title = "Raio da Kill Aura",
    Placeholder = tostring(killAuraRange),
    Default = tostring(killAuraRange),
    Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 10 and numValue <= 200 then
            killAuraRange = numValue
        else
            WindUI:Notify({Title = "Kill Aura", Content = "Raio invalido! Use um numero entre 10 e 200.", Color = "Red", Duration = 3})
            killAuraRangeInput_UI:Set(tostring(killAuraRange))
        end
    end
})

TabTeleporte:Section({ Title = "Movimento do Jogador" })
local walkspeedInput_UI = TabTeleporte:Input({
    Title = "Velocidade (WalkSpeed)",
    Placeholder = tostring(currentWalkSpeed),
    Default = tostring(currentWalkSpeed),
    Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 0 and numValue <= 500 then
            currentWalkSpeed = numValue
            applyPlayerMovement()
            WindUI:Notify({Title = "Movimento", Content = "Velocidade: " .. numValue, Color = "Blue", Duration = 2})
        else
            WindUI:Notify({Title = "Movimento", Content = "Valor de velocidade invalido! Use um numero entre 0 e 500.", Color = "Red", Duration = 3})
            walkspeedInput_UI:Set(tostring(currentWalkSpeed))
        end
    end
})
local jumppowerInput_UI = TabTeleporte:Input({
    Title = "Poder de Pulo (JumpPower)",
    Placeholder = tostring(currentJumpPower),
    Default = tostring(currentJumpPower),
    Number = true,
    Callback = function(value)
        local numValue = tonumber(value)
        if numValue and numValue >= 0 and numValue <= 500 then
            currentJumpPower = numValue
            applyPlayerMovement()
            WindUI:Notify({Title = "Movimento", Content = "Pulo: " .. numValue, Color = "Blue", Duration = 2})
        else
            WindUI:Notify({Title = "Movimento", Content = "Valor de pulo invalido! Use um numero entre 0 e 500.", Color = "Red", Duration = 3})
            jumppowerInput_UI:Set(tostring(currentJumpPower))
        end
    end
})

TabTeleporte:Section({ Title = "Teleporte Rapido" })
TabTeleporte:Button({
    Title = "TP para Fogueira",
    Desc = "Teleporta voce para a fogueira principal (MainFire).",
    Callback = function()
        local foundMainFire = nil
        for instance, _ in pairs(trackedStructures) do
            if instance and instance.Parent and find(CAMPFIRE_STRUCTURE_NAMES, instance.Name) then
                foundMainFire = instance
                break
            end
        end
        if foundMainFire then
            teleportToPosition(getSafePosition(foundMainFire), "Fogueira ("..foundMainFire.Name..")")
        else
            WindUI:Notify({Title = "Teleporte", Content = "Nenhuma fogueira encontrada no mapa.", Color = "Red", Duration = 3})
        end
    end
})
TabTeleporte:Button({
    Title = "TP para Bancada",
    Desc = "Teleporta voce para a bancada de trabalho principal (CraftingBench).",
    Callback = function()
        local foundCraftingBench = nil
        for instance, _ in pairs(trackedStructures) do
            if instance and instance.Parent and find(WORKBENCH_STRUCTURE_NAMES, instance.Name) then
                foundCraftingBench = instance
                break
            end
        end
        if foundCraftingBench then
            teleportToPosition(getSafePosition(foundCraftingBench), "Bancada ("..foundCraftingBench.Name..")")
        else
            WindUI:Notify({Title = "Teleporte", Content = "Nenhuma bancada de trabalho encontrada no mapa.", Color = "Red", Duration = 3})
        end
    end
})

TabTeleporte:Button({
    Title = "TP para Acampamento",
    Desc = "Teleporta voce para o acampamento principal.",
    Callback = function()
        local foundCampground = nil
        for instance, _ in pairs(trackedStructures) do
            if instance and instance.Parent and find(CAMPGROUND_NAMES, instance.Name) then
                foundCampground = instance
                break
            end
        end
        if foundCampground then
            teleportToPosition(getSafePosition(foundCampground), "Acampamento ("..foundCampground.Name..")")
        else
            WindUI:Notify({Title = "Teleporte", Content = "Nenhum acampamento encontrado no mapa.", Color = "Red", Duration = 3})
        end
    end
})

TabTeleporte:Button({
    Title = "TP para Arvore Gigante",
    Desc = "Teleporta voce para a Arvore Gigante mais proxima.",
    Callback = function()
        local foundGiantTree = nil
        for instance, _ in pairs(trackedStructures) do
            if instance and instance.Parent and find(GIANT_TREE_NAMES, instance.Name) then
                foundGiantTree = instance
                break
            end
        end
        if foundGiantTree then
            teleportToPosition(getSafePosition(foundGiantTree), "Arvore Gigante ("..foundGiantTree.Name..")")
        else
            WindUI:Notify({Title = "Teleporte", Content = "Nenhuma Arvore Gigante encontrada no mapa.", Color = "Red", Duration = 3})
        end
    end
})

local selectedKid = "Nenhum"
local kidDropdown_UI = TabTeleporte:Dropdown({
    Title = "TP para Crianca:",
    Values = {"Nenhum"},
    Default = selectedKid,
    Callback = function(name)
        selectedKid = name
        WindUI:Notify({Title = "Teleporte", Content = "Crianca selecionada: " .. tostring(name), Color = "Blue", Duration = 2})
    end
})
TabTeleporte:Button({
    Title = "Teleportar para Crianca",
    Desc = "Teleporta para a crianca selecionada no dropdown.",
    Callback = function()
        if selectedKid == "Nenhum" then
            WindUI:Notify({Title = "Teleporte", Content = "Nenhuma crianca selecionada.", Color = "Red", Duration = 3})
            return
        end
        local pureName, targetX, targetZ = parseDestinationString(selectedKid)
        local targetInstance = nil
        for instance, _ in pairs(trackedKids) do
            if instance and instance.Parent then
                local instancePos = getSafePosition(instance)
                if instancePos and instance.Name == pureName and
                   math.floor(instancePos.X) == targetX and math.floor(instancePos.Z) == targetZ then
                    targetInstance = instance
                    break
                end
            end
        end
        if targetInstance then
            teleportToPosition(getSafePosition(targetInstance), tostring(targetInstance.Name))
        else
            WindUI:Notify({Title = "Teleporte", Content = "Crianca '" .. tostring(pureName) .. "' nao encontrada ou invalida!", Color = "Red", Duration = 3})
        end
    end
})

-- ===================================================================
--                     HUD - PARAR BRING
-- ===================================================================

local stopBringButton = Instance.new("TextButton")
stopBringButton.Name = "StopBringButton"
stopBringButton.Size = UDim2.new(0, 100, 0, 50)
stopBringButton.Position = UDim2.new(0.5, -50, 1, -100) -- Meio da parte inferior, offset
stopBringButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
stopBringButton.TextColor3 = Color3.fromRGB(255, 255, 255)
stopBringButton.Text = "PARAR TUDO" -- Mais genérico
stopBringButton.Font = Enum.Font.SourceSansBold
stopBringButton.TextSize = 18
stopBringButton.ZIndex = 10 -- Garante que fique por cima de outros GUIs
stopBringButton.Visible = false -- Invisivel por padrao
stopBringButton.Active = true -- Pode ser clicado

local stopBringGui = Instance.new("ScreenGui")
stopBringGui.Name = "StopBringHUD"
stopBringGui.Parent = Player:WaitForChild("PlayerGui")
stopBringButton.Parent = stopBringGui

stopBringButton.MouseButton1Click:Connect(function()
    for categoryName, control in pairs(CATEGORY_CONTROLS) do
        if control.autoBringActive then
            deactivateAutoBringForCategory(categoryName)
        end
    end
    -- Resetar os toggles globais de bring
    bringFreecamActive = false
    bringUntouchable = false
    -- Restaurar o estado do jogador
    restorePlayerState()
    stopBringButton.Visible = false
    WindUI:Notify({Title = "Pânico", Content = "Todos os Brings desativados e estado do jogador restaurado!", Color = "Red", Duration = 3})
end)


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
    saveOriginalPlayerState() -- Salva o estado original na criação do personagem
    applyPlayerMovement()
    if walkspeedInput_UI then walkspeedInput_UI:Set(tostring(currentWalkSpeed)) end
    if jumppowerInput_UI then jumppowerInput_UI:Set(tostring(currentJumpPower)) end
end

RunService.RenderStepped:Connect(function()
    pcall(function()
        updatePlayersEsp()
    end)
end)

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

Workspace.DescendantAdded:Connect(function(instance)
    onItemAdded(instance)
    updateAllDropdowns()
end)

Workspace.DescendantRemoving:Connect(function(instance)
    onItemRemoved(instance)
    updateAllDropdowns()
end)

initializeItemTracking()
findRemoteEvents()

task.wait(1)
if Player.Character then
    onCharacterAdded(Player.Character)
end

applyPlayerMovement()
updateStopButtonVisibility() -- Garante que o botao esteja invisivel no inicio

WindUI:Notify({Title = "Script 99 Noites", Content = "Script carregado com sucesso!", Color = "Dark", Duration = 3})
