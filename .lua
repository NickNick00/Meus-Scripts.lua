local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local MeusScripts = {
    
    ["FREE THE FACILITY"] = {
        {
            Title = "Hub Completo",
            Desc = "Executa o script com Fly, ESP, Click TP, etc.",
            Source = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/NickNick00/ScriptFree-the-facility/refs/heads/main/.lua"))()

            ]]
        },
        {
            Title = "",
            Desc = "Descrição do outro script.",
            Source = [[
                print("Outro script foi executado!")
            ]]
        }
    },
    
    ["MM2"] = {
        {
            Title = "Script de ESP para MM2",
            Desc = "Mostra a localização dos jogadores no MM2.",
            Source = [[
                print("Cole o script do MM2 aqui!")
            ]]
        }
    },
    
    ["GERAIS"] = {
        {
            Title = "Infinite Yield Admin",
            Desc = "Executa o popular script de admin para qualquer jogo.",
            Source = [[
                loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()
            ]]
        },
        {
            Title = "Outro Script Geral",
            Desc = "Descrição de um script que funciona em vários jogos.",
            Source = [[
                print("Script geral executado!")
            ]]
        }
    }
}

local Window = WindUI:CreateWindow({
    Title = "Hub de Scripts",
    Author = "by kyuzzy",
    Size = UDim2.fromOffset(500, 400),
    Theme = "Dark",
    Folder = "KyuzzyHubConfig"
})

for tabTitle, scriptsInTab in pairs(MeusScripts) do
    
    local Tab = Window:Tab({ Title = tabTitle, Icon = "book" })
    
    Tab:Section({ Title = "Scripts Disponíveis" })
    
    for _, scriptInfo in ipairs(scriptsInTab) do
        Tab:Button({
            Title = scriptInfo.Title,
            Desc = scriptInfo.Desc,
            Callback = function()
                local success, err = pcall(function()
                    loadstring(scriptInfo.Source)()
                end)

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
end

print("Hub de Scripts Carregado. UI pronta para uso.")
