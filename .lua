local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

--                  CONFIGURAÇÃO DOS SEUS SCRIPTS
local MeusScripts = {
    {
        Title = "Infinite Yield Admin",
        Desc = "Executa o popular script de admin Infinite Yield.",
        Source = [[
            loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()
        ]]
    },
    {
        Title = "Flee the Facility",
        Desc = " By Kyuzzy",
        Source = [[
        loadstring(game:HttpGet("https://raw.githubusercontent.com/NickNick00/ScriptFree-the-facility/refs/heads/main/.lua"))()
            local RunService = game:GetService("RunService")
        ]]
    },
    {
        Title = "FREE THE FACILITY", -- O que vai aparecer no botão
        Desc = "By kyuzzy", -- A dica que aparece ao passar o mouse
        Source = [[
            
            print("Executado com sucesso!")
        ]]
    }
    
}

-- ===================================================================
--                  CRIAÇÃO DA INTERFACE DO HUB
-- (Não precisa editar nada abaixo desta linha)
-- ===================================================================

-- Cria a janela principal
local Window = WindUI:CreateWindow({
    Title = "Scripts",
    Author = "by kyuzzy",
    Size = UDim2.fromOffset(500, 400),
    Theme = "Dark"
})

-- Cria a aba onde os botões dos scripts vão ficar
local TabScripts1 = Window:Tab({ Title = "FREE THE FACILITY", Icon = "book" })
local TabScript2 = Window:Tab({ Title = "MM2", Icon = "help-circle" })
local TabScript3 = Window:Tab({ Title = "GERAIS", Icon = "book" }) 
-- Adiciona uma seção na aba de scripts
TabScripts:Section({ Title = "Executar Scripts" })

-- Cria os botões para cada script listado em MeusScripts
for _, scriptInfo in pairs(MeusScripts) do
    TabScripts:Button({
        Title = scriptInfo.Title,
        Desc = scriptInfo.Desc,
        Callback = function()
            -- Tenta executar o script de forma segura
            local success, err = pcall(function()
                loadstring(scriptInfo.Source)()
            end)

            -- Notifica o usuário se funcionou ou se deu erro
            if success then
                WindUI:Notify({ Title = "Sucesso", Content = "'" .. scriptInfo.Title .. "' foi executado!", Color = "Green" })
            else
                WindUI:Notify({ Title = "Erro", Content = "Falha ao executar o script. Veja o console (F9) para detalhes.", Color = "Red" })
                warn("=====================================")
                warn("ERRO AO EXECUTAR O SCRIPT: " .. scriptInfo.Title)
                warn(err)
                warn("=====================================")
            end
        end
    })
end

print("Hub de Scripts Carregado. UI pronta para uso.")
