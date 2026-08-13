-- Configurações persistidas em love.filesystem
local Settings = {}

local FILE = "settings.txt"

local defaults = {
    musicVolume = 0.1,
    sfxVolume   = 0.5,
    shake       = true,
    hints       = true,
}

local data = {}

function Settings.load()
    for k, v in pairs(defaults) do
        data[k] = v
    end

    if love.filesystem.getInfo(FILE) then
        local content = love.filesystem.read(FILE)
        if content then
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
