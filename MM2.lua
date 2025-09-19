-- ===================================================================
--                  CARREGAMENTO DA BIBLIOTECA WINDUI
-- ===================================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- ===================================================================
--                  VARIÁVEIS DE CONTROLE E SERVIÇOS
-- ===================================================================
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

-- Variáveis de estado do ESP
local espInnocentAtivo = false
local espMurdererAtivo = false
local espSheriffAtivo = false
local espDroppedGunAtivo = false

-- Variáveis de estado do Murder
local murderAuraActive = false
local murderAuraConnection = nil
local AURA_RANGE = 15 -- Alcance da aura em studs

-- Variáveis de estado dos Utilitários
local antiFlingAtivo = false
local antiFlingConnection = nil
local secondLifeAtivo = false
local secondLifeUsed = false
local noclipAtivo = false
local noclipConnection = nil
local playerDiedConnection = nil -- Conexão para o evento Humanoid.Died

-- Tabela para armazenar os Highlights de ESP
local espHighlights = {} -- { [Instance (Character/Part)] = HighlightInstance }

-- Configurações de cores para o ESP
local espColors = {
    Innocent = Color3.fromRGB(0, 255, 0), -- Verde
    Murderer = Color3.fromRGB(255, 0, 0), -- Vermelho
    Sheriff = Color3.fromRGB(0, 170, 255), -- Azul
    DroppedGun = Color3.fromRGB(255, 255, 0) -- Amarelo
}

-- MM2 RemoteEvents (Nome específico para MM2 - PODE PRECISAR SER ATUALIZADO)
local KnifeHitEvent = nil
pcall(function()
    KnifeHitEvent = ReplicatedStorage:FindFirstChild("Game") and ReplicatedStorage.Game:FindFirstChild("KnifeHit") 
    if not KnifeHitEvent then
        KnifeHitEvent = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("KnifeEvent")
    end
    if not KnifeHitEvent then
        KnifeHitEvent = ReplicatedStorage:FindFirstChild("CombatEvents") and ReplicatedStorage.CombatEvents:FindFirstChild("KnifeHit")
    end
end)
if not KnifeHitEvent then
    warn("Não foi possível encontrar o KnifeHitEvent! Funções de assassinato podem não funcionar.")
    WindUI:Notify({Title = "Erro Crítico", Content = "RemoteEvent de assassinato não encontrado. Funções de assassinato podem falhar!", Color = "Red"})
end

-- ===================================================================
--                  DEFINIÇÃO DAS FUNÇÕES DO SCRIPT
-- ===================================================================

-- Funções para obter o papel de um jogador no MM2
local function getMM2PlayerRole(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return nil end

    local char = targetPlayer.Character
    local backpack = targetPlayer:FindFirstChildOfClass("Backpack")

    if (backpack and backpack:FindFirstChild("Knife", true)) or (char:FindFirstChild("Knife", true)) then
        return "Murderer"
    end
    
    if (backpack and backpack:FindFirstChild("Gun", true)) or (char:FindFirstChild("Gun", true)) then
        return "Sheriff"
    end

    return "Innocent"
end

-- Funções de ESP
local function updateMM2Esp()
    local activeTrackedObjects = {} 

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local char = p.Character
            local role = getMM2PlayerRole(p)
            local shouldHighlight = false
            local highlightColor = nil

            if role == "Innocent" and espInnocentAtivo then
                shouldHighlight = true
                highlightColor = espColors.Innocent
            elseif role == "Murderer" and espMurdererAtivo then
                shouldHighlight = true
                highlightColor = espColors.Murderer
            elseif role == "Sheriff" and espSheriffAtivo then
                shouldHighlight = true
                highlightColor = espColors.Sheriff
            end

            if shouldHighlight then
                activeTrackedObjects[char] = true
                if not espHighlights[char] then
                    espHighlights[char] = Instance.new("Highlight")
                    espHighlights[char].Parent = char
                    espHighlights[char].Adornee = char
                    espHighlights[char].DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                end
                espHighlights[char].FillColor = highlightColor
                espHighlights[char].OutlineColor = highlightColor
                espHighlights[char].Enabled = true
            elseif espHighlights[char] then
                espHighlights[char].Enabled = false 
            end
        end
    end

    if espDroppedGunAtivo then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj.Name == "Gun" and obj:IsA("BasePart") and not obj:FindFirstAncestorOfClass("Player") then
                activeTrackedObjects[obj] = true
                if not espHighlights[obj] then
                    espHighlights[obj] = Instance.new("Highlight")
                    espHighlights[obj].Parent = obj
                    espHighlights[obj].Adornee = obj
                    espHighlights[obj].FillColor = espColors.DroppedGun
                    espHighlights[obj].OutlineColor = espColors.DroppedGun
                    espHighlights[obj].DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                end
                espHighlights[obj].Enabled = true
            end
        end
    end

    for obj, highlight in pairs(espHighlights) do
        if not activeTrackedObjects[obj] or not obj.Parent then
            highlight:Destroy()
            espHighlights[obj] = nil
        end
    end
end

-- Funções de Assassinato
local function attemptKillPlayer(targetPlayer)
    if getMM2PlayerRole(Player) ~= "Murderer" then
        WindUI:Notify({Title = "Assassinato", Content = "Você precisa ser o Assassino para usar esta função!", Color = "Red"})
        return false
    end

    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        WindUI:Notify({Title = "Assassinato", Content = "Alvo inválido para assassinato.", Color = "Red"})
        return false
    end

    local targetHrp = targetPlayer.Character.HumanoidRootPart

    if KnifeHitEvent then
        pcall(function()
            KnifeHitEvent:FireServer(targetHrp) 
        end)
        WindUI:Notify({Title = "Assassinato", Content = "Tentando assassinar " .. targetPlayer.Name .. "!", Color = "Orange"})
        return true
    else
        WindUI:Notify({Title = "Assassinato", Content = "Evento de faca (RemoteEvent) não encontrado ou configurado incorretamente. O assassinato pode não funcionar.", Color = "Red"})
        return false
    end
end

-- Teleporte
local function teleportToPlayer(targetPlayer)
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then
        WindUI:Notify({Title = "Teleporte", Content = "Seu personagem não está disponível para teleporte.", Color = "Red"})
        return
    end
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        WindUI:Notify({Title = "Teleporte", Content = "Jogador alvo não encontrado ou não está no jogo.", Color = "Red"})
        return
    end

    local targetPos = targetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 5, 0) 
    pcall(function()
        Player.Character.HumanoidRootPart.CFrame = targetPos
    end)
    WindUI:Notify({Title = "Teleporte", Content = "Teleportado para " .. targetPlayer.Name .. "!", Color = "Green"})
end

local function findPlayerByRole(role)
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= Player and getMM2PlayerRole(p) == role then
            return p
        end
    end
    return nil
end 

local function TeleportToMurderer()
    local murderer = findPlayerByRole("Murderer")
    if murderer then
        teleportToPlayer(murderer)
    else
        WindUI:Notify({Title = "Teleporte", Content = "Assassino não encontrado!", Color = "Yellow"})
    end
end

local function TeleportToSheriff()
    local sheriff = findPlayerByRole("Sheriff")
    if sheriff then
        teleportToPlayer(sheriff)
    else
        WindUI:Notify({Title = "Teleporte", Content = "Xerife não encontrado!", Color = "Yellow"})
    end
end

local function TeleportToLobby()
    local spawnLocation = Workspace:FindFirstChild("SpawnLocation")
    if spawnLocation then
        local pos = spawnLocation.Position + Vector3.new(0, 5, 0)
        if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            pcall(function() Player.Character.HumanoidRootPart.CFrame = CFrame.new(pos) end)
            WindUI:Notify({Title = "Teleporte", Content = "Teleportado para o Lobby!", Color = "Green"})
            return
        end
    end

    local lobbyPart = Workspace:FindFirstChild("LobbyArea", true) or Workspace:FindFirstChild("MapSpawn", true)
    if lobbyPart and lobbyPart:IsA("BasePart") then
        local pos = lobbyPart.Position + Vector3.new(0, 5, 0)
        if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            pcall(function() Player.Character.HumanoidRootPart.CFrame = CFrame.new(pos) end)
            WindUI:Notify({Title = "Teleporte", Content = "Teleportado para o Lobby!", Color = "Green"})
            return
        end
    end

    WindUI:Notify({Title = "Teleporte", Content = "Não foi possível encontrar o Lobby.", Color = "Red"})
end

local function TeleportToMap()
    local mapSpawn = Workspace:FindFirstChild("MapSpawns", true) or Workspace:FindFirstChild("ArenaSpawn", true)
    if mapSpawn and mapSpawn:IsA("Model") and mapSpawn:FindFirstChildOfClass("BasePart") then
        local pos = mapSpawn.PrimaryPart.Position + Vector3.new(0, 5, 0)
        if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            pcall(function() Player.Character.HumanoidRootPart.CFrame = CFrame.new(pos) end)
            WindUI:Notify({Title = "Teleporte", Content = "Teleportado para o Mapa!", Color = "Green"})
            return
        end
    end
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local pos = p.Character.HumanoidRootPart.Position + Vector3.new(0, 5, 0)
            if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                pcall(function() Player.Character.HumanoidRootPart.CFrame = CFrame.new(pos) end)
                WindUI:Notify({Title = "Teleporte", Content = "Teleportado para o Mapa (próximo a " .. p.Name .. ")!", Color = "Green"})
                return
            end
        end
    end

    WindUI:Notify({Title = "Teleporte", Content = "Não foi possível encontrar um local de spawn no mapa.", Color = "Red"})
end

local function KillSelectedPlayerButton(playerName)
    if not playerName or playerName == "Selecione um jogador..." then
        WindUI:Notify({Title = "Assassinato", Content = "Selecione um jogador para matar.", Color = "Yellow"})
        return
    end
    local targetPlayer = Players:FindFirstChild(playerName)
    if targetPlayer then
        if targetPlayer == Player then
            WindUI:Notify({Title = "Assassinato", Content = "Não pode assassinar a si mesmo.", Color = "Red"})
            return
        end
        if getMM2PlayerRole(targetPlayer) == "Murderer" then
            WindUI:Notify({Title = "Assassinato", Content = "Não pode assassinar outro Assassino.", Color = "Red"})
            return
        end
        attemptKillPlayer(targetPlayer)
    else
        WindUI:Notify({Title = "Assassinato", Content = "Jogador '" .. playerName .. "' não encontrado.", Color = "Red"})
    end
end

local function KillSheriffButton()
    local sheriff = findPlayerByRole("Sheriff")
    if sheriff then
        attemptKillPlayer(sheriff)
    else
        WindUI:Notify({Title = "Assassinato", Content = "Xerife não encontrado!", Color = "Yellow"})
    end
end

local function KillAllExceptButton(excludedPlayerName)
    local excludedPlayer = excludedPlayerName and Players:FindFirstChild(excludedPlayerName) or nil
    if getMM2PlayerRole(Player) ~= "Murderer" then
        WindUI:Notify({Title = "Assassinato", Content = "Você precisa ser o Assassino para usar esta função!", Color = "Red"})
        return
    end

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= Player and p ~= excludedPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            if getMM2PlayerRole(p) ~= "Murderer" then 
                attemptKillPlayer(p)
                task.wait(0.1) 
            end
        end
    end
    WindUI:Notify({Title = "Assassinato", Content = "Tentando assassinar todos (exceto " .. (excludedPlayerName and excludedPlayerName ~= "Nenhum" and excludedPlayerName or "ninguém") .. ")!", Color = "Orange"})
end

local function ToggleMurderAura(state)
    murderAuraActive = state
    if not state then
        if murderAuraConnection then
            murderAuraConnection:Disconnect()
            murderAuraConnection = nil
        end
        WindUI:Notify({Title = "Aura", Content = "Aura de Assassinato desativada.", Color = "Gray"})
        return
    end

    if getMM2PlayerRole(Player) ~= "Murderer" then
        WindUI:Notify({Title = "Aura", Content = "Você precisa ser o Assassino para ativar a Aura!", Color = "Red"})
        murderAuraActive = false
        return
    end

    WindUI:Notify({Title = "Aura", Content = "Aura de Assassinato ativada! (Para maior eficácia, esteja com a faca em mãos)", Color = "Green"})

    murderAuraConnection = RunService.RenderStepped:Connect(function()
        if not murderAuraActive or not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return end
        local playerHrp = Player.Character.HumanoidRootPart

        for _, p in pairs(Players:GetPlayers()) do
            if p ~= Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local targetHrp = p.Character.HumanoidRootPart
                local distance = (playerHrp.Position - targetHrp.Position).Magnitude

                if distance <= AURA_RANGE and getMM2PlayerRole(p) ~= "Murderer" then
                    attemptKillPlayer(p)
                    task.wait(0.5) 
                end
            end
        end
    end)
end

-- Funções de Utilitários

local function startAntiFling()
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return end
    antiFlingAtivo = true
    WindUI:Notify({Title = "Anti-Fling", Content = "Anti-Fling ativado!", Color = "Green"})
    antiFlingConnection = RunService.RenderStepped:Connect(function()
        if antiFlingAtivo and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = Player.Character.HumanoidRootPart
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            -- Também pode tentar forçar PlatformStand para evitar quedas, mas pode ser intrusivo.
            -- local humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
            -- if humanoid then humanoid.PlatformStand = true end
        end
    end)
end

local function stopAntiFling()
    antiFlingAtivo = false
    if antiFlingConnection then
        antiFlingConnection:Disconnect()
        antiFlingConnection = nil
    end
    -- Resetar PlatformStand se usado
    -- if Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
    --     Player.Character:FindFirstChildOfClass("Humanoid").PlatformStand = false
    -- end
    WindUI:Notify({Title = "Anti-Fling", Content = "Anti-Fling desativado.", Color = "Gray"})
end

local function startNoclip()
    noclipAtivo = true
    if noclipConnection then return end
    WindUI:Notify({Title = "Noclip", Content = "Noclip ativado!", Color = "Green"})
    noclipConnection = RunService.Stepped:Connect(function()
        if noclipAtivo and Player.Character then
            for _, part in pairs(Player.Character:GetChildren()) do
                if part:IsA("BasePart") then 
                    part.CanCollide = false 
                end
            end
        end
    end)
end

local function stopNoclip()
    noclipAtivo = false
    if noclipConnection then 
        noclipConnection:Disconnect() 
        noclipConnection = nil 
    end
    
    if Player.Character then
        for _, part in pairs(Player.Character:GetChildren()) do
            if part:IsA("BasePart") then 
                part.CanCollide = true 
            end
        end
    end
    WindUI:Notify({Title = "Noclip", Content = "Noclip desativado.", Color = "Gray"})
}

local function handleSecondLife()
    if not secondLifeAtivo or secondLifeUsed then return end

    local humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        playerDiedConnection = humanoid.Died:Connect(function()
            if secondLifeAtivo and not secondLifeUsed then
                secondLifeUsed = true
                WindUI:Notify({Title = "Segunda Vida", Content = "Segunda Vida ativada! Você foi salvo!", Color = "Green"})
                
                -- Revive o jogador (pode variar por jogo)
                humanoid.Health = humanoid.MaxHealth
                
                -- Teleporta levemente para evitar ficar preso no chão/objeto
                local hrp = Player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = hrp.CFrame + Vector3.new(0, 5, 0)
                end
            end
        end)
    end
end

local function toggleSecondLife(state)
    secondLifeAtivo = state
    if state then
        secondLifeUsed = false -- Reseta o uso da segunda vida ao ativar
        WindUI:Notify({Title = "Segunda Vida", Content = "Segunda Vida ativada e pronta!", Color = "Green"})
        -- A conexão Humanoid.Died é feita no CharacterAdded para garantir que sempre esteja conectada ao Humanoid correto
    else
        secondLifeUsed = true -- Marca como usada para não ativar caso desativado no meio da vida
        WindUI:Notify({Title = "Segunda Vida", Content = "Segunda Vida desativada.", Color = "Gray"})
        if playerDiedConnection then
            playerDiedConnection:Disconnect()
            playerDiedConnection = nil
        end
    end
end

-- Função para atualizar dropdowns de jogadores
local function updatePlayerDropdowns(dropdowns)
    local currentPlayers = {}
    for _, p in pairs(Players:GetPlayers()) do
        table.insert(currentPlayers, p.Name)
    end
    for _, dropdown in ipairs(dropdowns) do
        local values = {}
        if dropdown == playerKillAllExceptDropdown then
            table.insert(values, "Nenhum") 
        end
        for _, name in ipairs(currentPlayers) do
            table.insert(values, name)
        end
        dropdown:Refresh(values)
    end
    WindUI:Notify({Title = "Info", Content = "Listas de jogadores atualizadas!"})
end


-- ===================================================================
--                         INTERFACE GRÁFICA
-- ===================================================================

local Window = WindUI:CreateWindow({
    Title = "MM2 Hub", 
    Icon = "door-open", 
    Author = "by kyuzzy", 
    Folder = "MM2 Hub", 
    Size = UDim2.fromOffset(400, 550), 
    Theme = "Dark"
})

-- Abas
local TabMM2ESP = Window:Tab({ Title = "MM2 ESP", Icon = "eye" })
local TabMM2Teleporte = Window:Tab({ Title = "Teleporte MM2", Icon = "compass" })
local TabMurder = Window:Tab({ Title = "Murder", Icon = "skull" }) 
local TabUtilitarios = Window:Tab({ Title = "Utilitários", Icon = "wrench" }) -- Nova Aba

-- Aba MM2 ESP
TabMM2ESP:Section({ Title = "ESP de Papéis" })
TabMM2ESP:Toggle({ Title = "ESP Inocentes (Verde)", Callback = function(state) espInnocentAtivo = state; updateMM2Esp() end})
TabMM2ESP:Toggle({ Title = "ESP Assassino (Vermelho)", Callback = function(state) espMurdererAtivo = state; updateMM2Esp() end})
TabMM2ESP:Toggle({ Title = "ESP Xerife (Azul)", Callback = function(state) espSheriffAtivo = state; updateMM2Esp() end})
TabMM2ESP:Section({ Title = "ESP de Itens" })
TabMM2ESP:Toggle({ Title = "ESP Arma Dropada (Amarelo)", Callback = function(state) espDroppedGunAtivo = state; updateMM2Esp() end})

-- Aba Teleporte MM2
TabMM2Teleporte:Section({ Title = "Teleporte Rápido" })
TabMM2Teleporte:Button({ Title = "TP para Assassino", Callback = TeleportToMurderer })
TabMM2Teleporte:Button({ Title = "TP para Xerife", Callback = TeleportToSheriff })
TabMM2Teleporte:Button({ Title = "TP para Lobby", Callback = TeleportToLobby })
TabMM2Teleporte:Button({ Title = "TP para Mapa", Callback = TeleportToMap })
TabMM2Teleporte:Section({ Title = "Teleporte para Jogador Específico" })

local playerNamesTP = {"Atualize a lista..."} 
local selectedPlayerNameTP = nil
local playerTPDropdown = TabMM2Teleporte:Dropdown({
    Title = "Selecionar Jogador",
    Values = playerNamesTP,
    Callback = function(name) selectedPlayerNameTP = name end
})
TabMM2Teleporte:Button({
    Title = "Atualizar Listas de Jogadores", 
    Callback = function() updatePlayerDropdowns({playerTPDropdown, playerKillDropdown, playerKillAllExceptDropdown}) end
})
TabMM2Teleporte:Button({
    Title = "TP para Selecionado",
    Callback = function()
        if selectedPlayerNameTP and selectedPlayerNameTP ~= "Atualize a lista..." then
            local targetPlayer = Players:FindFirstChild(selectedPlayerNameTP)
            if targetPlayer then teleportToPlayer(targetPlayer)
            else WindUI:Notify({Title = "Teleporte", Content = "Jogador '" .. selectedPlayerNameTP .. "' não encontrado.", Color = "Red"}) end
        else WindUI:Notify({Title = "Teleporte", Content = "Selecione um jogador na lista.", Color = "Yellow"}) end
    end
})

-- Aba Murder
TabMurder:Section({ Title = "Funções de Assassinato" })

local playerNamesKill = {"Selecione um jogador..."}
local selectedPlayerNameKill = nil
local playerKillDropdown = TabMurder:Dropdown({
    Title = "Assassinar Jogador",
    Values = playerNamesKill,
    Callback = function(name) selectedPlayerNameKill = name end
})
TabMurder:Button({
    Title = "Matar Jogador Selecionado",
    Callback = function() KillSelectedPlayerButton(selectedPlayerNameKill) end
})

TabMurder:Button({
    Title = "Matar Xerife",
    Callback = KillSheriffButton
})

TabMurder:Toggle({
    Title = "Aura de Assassinato",
    Desc = "Mata automaticamente jogadores próximos (precisa ser o Murderer).",
    Callback = ToggleMurderAura
})

TabMurder:Section({ Title = "Matar Todos (Exceto)" })

local playerNamesExclude = {"Nenhum"} 
local selectedPlayerNameExclude = "Nenhum"
local playerKillAllExceptDropdown = TabMurder:Dropdown({
    Title = "Excluir Jogador",
    Values = playerNamesExclude,
    Callback = function(name) selectedPlayerNameExclude = name end
})

TabMurder:Button({
    Title = "Matar Todos (Exceto Selecionado)",
    Callback = function() KillAllExceptButton(selectedPlayerNameExclude) end
})

-- Aba Utilitários
TabUtilitarios:Section({ Title = "Proteção e Movimento" })
TabUtilitarios:Toggle({
    Title = "Anti-Fling",
    Desc = "Impede que você seja arremessado no mapa.",
    Callback = function(state)
        if state then startAntiFling() else stopAntiFling() end
    end
})
TabUtilitarios:Toggle({
    Title = "Segunda Vida",
    Desc = "Revive você uma vez ao morrer.",
    Callback = toggleSecondLife
})
TabUtilitarios:Toggle({
    Title = "Noclip (Atravessar Paredes)",
    Desc = "Permite atravessar objetos sólidos.",
    Callback = function(state)
        if state then startNoclip() else stopNoclip() end
    end
})


-- ===================================================================
--                     INICIALIZAÇÃO E EVENTOS
-- ===================================================================

-- Loop principal para atualização do ESP
RunService.RenderStepped:Connect(function()
    pcall(function() 
        if espInnocentAtivo or espMurdererAtivo or espSheriffAtivo or espDroppedGunAtivo then
            updateMM2Esp()
        else
            for obj, highlight in pairs(espHighlights) do
                if highlight and highlight.Parent then 
                    highlight:Destroy()
                end
                espHighlights[obj] = nil
            end
        end
    end)
end)

-- Conecta eventos para lidar com jogadores entrando e saindo (para os dropdowns de TP e Kill, e ESP)
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        updateMM2Esp() 
        updatePlayerDropdowns({playerTPDropdown, playerKillDropdown, playerKillAllExceptDropdown})
        
        -- Reconecta o Died event para o novo Humanoid, se a Segunda Vida estiver ativa
        if secondLifeAtivo then
            if playerDiedConnection then
                playerDiedConnection:Disconnect()
                playerDiedConnection = nil
            end
            handleSecondLife()
        end
    end)
    player.CharacterRemoving:Connect(function(char)
        if espHighlights[char] then
            espHighlights[char]:Destroy()
            espHighlights[char] = nil
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    if player.Character and espHighlights[player.Character] then
        espHighlights[player.Character]:Destroy()
        espHighlights[player.Character] = nil
    end
    updatePlayerDropdowns({playerTPDropdown, playerKillDropdown, playerKillAllExceptDropdown})
end)

-- Resetar estados dos utilitários ao renascer
Player.CharacterAdded:Connect(function(char)
    -- Noclip e Anti-Fling devem ser reativados se estavam ativos antes da morte
    if noclipAtivo then stopNoclip(); startNoclip() end -- Desliga e liga para aplicar em novas partes
    if antiFlingAtivo then stopAntiFling(); startAntiFling() end
    
    secondLifeUsed = false -- Resetar o uso da segunda vida a cada respawn
    handleSecondLife() -- Garante que o evento Died esteja conectado para o novo Humanoid
end)

-- Atualiza as listas de jogadores dos dropdowns ao carregar
task.wait(1)
updatePlayerDropdowns({playerTPDropdown, playerKillDropdown, playerKillAllExceptDropdown})
