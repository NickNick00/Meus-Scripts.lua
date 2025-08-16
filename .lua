-- ===================================================================
--                  CARREGAMENTO DA BIBLIOTECA WINDUI
-- ===================================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- ===================================================================
--                  CONFIGURAÇÃO DOS SEUS SCRIPTS
-- ===================================================================
-- ABAIXO É O ÚNICO LUGAR QUE VOCÊ PRECISA EDITAR!
-- Para adicionar um novo script, copie o modelo abaixo e cole na lista.

local MeusScripts = {
    
    -- [[ EXEMPLO 1: SCRIPT PEQUENO (Infinite Yield Admin) ]]
    {
        Title = "Infinite Yield Admin",
        Desc = "Executa o popular script de admin Infinite Yield.",
        Source = [[
            loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()
        ]]
    },

    -- [[ EXEMPLO 2: SCRIPT GRANDE (Seu script do Flee the Facility) ]]
    {
        Title = "Hub para Flee the Facility",
        Desc = "Executa o script que criamos com Fly, ESP, Click TP, etc.",
        Source = [[
            -- COLE AQUI O CÓDIGO INTEIRO DO SEU SCRIPT ANTES
            local RunService = game:GetService("RunService")
            -- ... e assim por diante, cole todo o resto do script aqui dentro.
            -- Deixei este em branco para você mesmo colar.
        ]]
    },
    
    -- [[ MODELO PARA ADICIONAR SEU PRÓXIMO SCRIPT ]]
    -- Copie e cole este bloco para adicionar mais scripts.
    {
        Title = "FREE THE FACILITY", -- O que vai aparecer no botão
        Desc = "EXECUTE ESTE SCRIPT", -- A dica que aparece ao passar o mouse
        Source = [[
            loadstring(game:HttpGet("https://raw.githubusercontent.com/NickNick00/ScriptFree-the-facility/refs/heads/main/.lua"))()
            print("Meu novo script funciona!")
        ]]
    }
    
}

-- ===================================================================
--                  CRIAÇÃO DA INTERFACE DO HUB
-- (Não precisa editar nada abaixo desta linha)
-- ===================================================================

-- Cria a janela principal
local Window = WindUI:CreateWindow({
    Title = "Hub de Scripts Pessoal",
    Author = "by kyuzzy",
    Size = UDim2.fromOffset(500, 400),
    Theme = "Dark"
})

-- Cria a aba onde os botões dos scripts vão ficar
local TabScripts = Window:Tab({ Title = "Scripts", Icon = "book" })
local TabAjuda = Window:Tab({ Title = "Como Adicionar", Icon = "help-circle" })

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

-- Adiciona instruções na aba de Ajuda
TabAjuda:Paragraph({
    Title = "Como Adicionar um Novo Script",
    Desc = "É muito simples adicionar seus próprios scripts a este Hub. Você não precisa saber programar, apenas copiar e colar."
})

TabAjuda:Paragraph({
    Title = "Passo 1: Edite o Script",
    Desc = "Abra este script no seu editor de texto (como o Bloco de Notas, ou diretamente no seu executor de scripts)."
})

TabAjuda:Paragraph({
    Title = "Passo 2: Encontre a Tabela 'MeusScripts'",
    Desc = "Role para o topo do script até encontrar a seção chamada 'CONFIGURAÇÃO DOS SEUS SCRIPTS'. Você verá uma lista chamada 'MeusScripts'."
})

TabAjuda:Paragraph({
    Title = "Passo 3: Copie e Cole o Modelo",
    Desc = "Copie o bloco de código do 'MODELO' e cole uma nova linha dentro da lista. Certifique-se de colocar uma vírgula (,) depois do bloco anterior."
})

TabAjuda:Paragraph({
    Title = "Passo 4: Cole Seu Script",
    Desc = "Substitua o 'Title', a 'Desc', e o mais importante: cole o código do seu script entre as chaves duplas [[ e ]]."
})

print("Hub de Scripts Carregado. UI pronta para uso.")
