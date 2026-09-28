local LrPrefs = import 'LrPrefs'
local Util = require 'Util'

local Store = {}
local prefs = LrPrefs.prefsForPlugin()

local function keyFor(profile)
    return 'approvedVocabulary_' .. string.lower(profile or ''):gsub('[^%w]+', '_')
end

function Store.get(profile)
    profile = Util.trim(profile)
    if profile == '' then return {} end
    return Util.unique(Util.split(prefs[keyFor(profile)] or '', '|'))
end

function Store.remember(profile, records)
    profile = Util.trim(profile)
    if profile == '' then return end
    local vocabulary = Store.get(profile)
    for _, record in ipairs(records) do
        if record.enabled then
            for _, keyword in ipairs(record.keywords or {}) do table.insert(vocabulary, keyword) end
        end
    end
    vocabulary = Util.unique(vocabulary)
    while #vocabulary > 80 do table.remove(vocabulary, 1) end
    prefs[keyFor(profile)] = table.concat(vocabulary, '|')
end

return Store
