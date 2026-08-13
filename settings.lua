-- Configurações persistidas em love.filesystem (arquivo "settings.txt").
-- Formato do arquivo: uma linha por opção, "chave=valor" (ex.: "shake=true").
local Settings = {}

local FILE = "settings.txt"

-- Valores padrão usados quando o arquivo não existe ou falta alguma opção.
local defaults = {
    musicVolume = 0.1, -- volume da música de fundo (0 a 1)
    sfxVolume   = 0.5, -- volume dos efeitos sonoros (0 a 1)
    shake       = true, -- tremor de tela ao capturar/promover
    hints       = true, -- mostrar dicas de jogadas (destacar capturas e destinos)
}

-- Valores atuais em memória (sempre têm as chaves de defaults).
local data = {}

-- Lê o arquivo de configuração, se existir, e sobrescreve os padrões.
function Settings.load()
    -- 1) começa tudo com os padrões
    for k, v in pairs(defaults) do
        data[k] = v
    end

    -- 2) aplica o que foi salvo (se houver)
    if love.filesystem.getInfo(FILE) then
        local content = love.filesystem.read(FILE)
        if content then
            -- cada linha "chave=valor" é convertida de texto para o tipo certo
            for line in content:gmatch("[^\r\n]+") do
                local k, v = line:match("^(%w+)=(.-)$")
                if k and v and defaults[k] ~= nil then
                    if v == "true" then
                        data[k] = true
                    elseif v == "false" then
                        data[k] = false
                    else
                        local n = tonumber(v)
                        if n then data[k] = n end
                    end
                end
            end
        end
    end

    return data
end

-- Grava todas as opções no arquivo (chamado a cada Settings.set).
function Settings.save()
    local lines = {}
    for k in pairs(defaults) do
        lines[#lines + 1] = k .. "=" .. tostring(data[k])
    end
    love.filesystem.write(FILE, table.concat(lines, "\n"))
end

function Settings.get(key)
    return data[key]
end

function Settings.set(key, value)
    data[key] = value
    Settings.save()
end

return Settings
